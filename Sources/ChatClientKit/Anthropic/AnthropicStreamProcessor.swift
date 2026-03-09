//
//  AnthropicStreamProcessor.swift
//  ChatClientKit
//

import Foundation
import ServerEvent

struct AnthropicStreamProcessor {
    let eventSourceFactory: EventSourceProducing
    let chunkDecoder: JSONDecoding

    init(
        eventSourceFactory: EventSourceProducing = DefaultEventSourceFactory(),
        chunkDecoder: JSONDecoding = JSONDecoderWrapper()
    ) {
        self.eventSourceFactory = eventSourceFactory
        self.chunkDecoder = chunkDecoder
    }

    /// Streams an Anthropic Messages API response, yielding `ChatResponseChunk` values.
    ///
    /// Captures complete thinking blocks (text + signature) for round-tripping in
    /// multi-turn tool-use conversations. Thinking blocks must be preserved and sent
    /// back to the API when continuing a conversation after a tool call.
    ///
    /// See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking#streaming-extended-thinking
    func stream(
        request: URLRequest,
        collectError: @Sendable @escaping (Swift.Error) async -> Void
    ) -> AnyAsyncSequence<ChatResponseChunk> {
        let stream = AsyncStream<ChatResponseChunk> { continuation in
            Task.detached(priority: .userInitiated) { [collectError, eventSourceFactory, chunkDecoder, request] in
                var currentBlockType: String?
                var currentToolId: String?
                var currentToolName: String?
                var toolArguments = ""
                var pendingToolCalls: [ToolRequest] = []
                var chunkCount = 0

                // Accumulate thinking block text and signature for round-tripping.
                // See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking#preserve-thinking-blocks
                var currentThinkingText = ""
                var currentSignature = ""

                let streamTask = eventSourceFactory.makeDataTask(for: request)

                for await event in streamTask.events() {
                    switch event {
                    case .open:
                        logger.info("Anthropic stream connection opened.")
                    case let .error(error):
                        logger.error("Anthropic stream error: \(error.localizedDescription)")
                        await collectError(error)
                    case let .event(event):
                        guard let data = event.data?.data(using: .utf8) else {
                            continue
                        }

                        do {
                            let payload = try chunkDecoder.decode(AnthropicStreamEvent.self, from: data)
                            chunkCount += 1

                            switch payload.type {
                            case "message_start":
                                break

                            case "content_block_start":
                                if let block = payload.contentBlock {
                                    currentBlockType = block.type
                                    if block.type == "tool_use" {
                                        currentToolId = block.id
                                        currentToolName = block.name
                                        toolArguments = ""
                                    } else if block.type == "thinking" {
                                        currentThinkingText = ""
                                        currentSignature = ""
                                        if let thinking = block.thinking, !thinking.isEmpty {
                                            continuation.yield(.reasoning(thinking))
                                            currentThinkingText = thinking
                                        }
                                    } else if block.type == "redacted_thinking" {
                                        // Redacted thinking block - preserve encrypted data verbatim.
                                        // See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking#redacted-thinking-blocks
                                        if let data = block.data {
                                            continuation.yield(.redactedThinking(data: data))
                                        }
                                    }
                                }

                            case "content_block_delta":
                                if let delta = payload.delta {
                                    switch delta.type {
                                    case "text_delta":
                                        if let text = delta.text {
                                            continuation.yield(.text(text))
                                        }
                                    case "thinking_delta":
                                        if let thinking = delta.thinking {
                                            continuation.yield(.reasoning(thinking))
                                            currentThinkingText += thinking
                                        }
                                    case "input_json_delta":
                                        if let partial = delta.partialJson {
                                            toolArguments.append(partial)
                                        }
                                    case "signature_delta":
                                        // Accumulate signature for the current thinking block.
                                        // Required for verification when round-tripping.
                                        if let sig = delta.signature {
                                            currentSignature += sig
                                        }
                                    default:
                                        break
                                    }
                                }

                            case "content_block_stop":
                                if currentBlockType == "tool_use",
                                   let name = currentToolName
                                {
                                    let call = ToolRequest(
                                        id: currentToolId,
                                        name: name,
                                        arguments: toolArguments
                                    )
                                    pendingToolCalls.append(call)
                                    currentToolId = nil
                                    currentToolName = nil
                                    toolArguments = ""
                                } else if currentBlockType == "thinking", !currentSignature.isEmpty {
                                    // Emit the complete thinking block with signature for preservation.
                                    let block = ThinkingBlock(
                                        thinking: currentThinkingText,
                                        signature: currentSignature
                                    )
                                    continuation.yield(.thinkingBlock(block))
                                    currentThinkingText = ""
                                    currentSignature = ""
                                }
                                currentBlockType = nil

                            case "message_delta":
                                // Contains stop_reason and final usage
                                break

                            case "message_stop":
                                break

                            case "ping":
                                break

                            case "error":
                                if let error = payload.error {
                                    let nsError = NSError(
                                        domain: "Anthropic API",
                                        code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: error.message ?? "Unknown error"]
                                    )
                                    await collectError(nsError)
                                }

                            default:
                                break
                            }
                        } catch {
                            if let text = String(data: data, encoding: .utf8),
                               text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            {
                                continue
                            }
                            await collectError(error)
                        }
                    case .closed:
                        logger.info("Anthropic stream connection closed.")
                    }
                }

                for call in pendingToolCalls {
                    continuation.yield(.tool(call))
                }

                logger.info("Anthropic streaming completed: \(chunkCount) events, \(pendingToolCalls.count) tool calls")
                continuation.finish()
            }
        }
        return stream.eraseToAnyAsyncSequence()
    }
}
