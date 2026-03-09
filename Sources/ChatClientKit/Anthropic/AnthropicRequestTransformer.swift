//
//  AnthropicRequestTransformer.swift
//  ChatClientKit
//

import Foundation

struct AnthropicRequestTransformer {
    let thinkingBudgetTokens: Int

    init(thinkingBudgetTokens: Int = 0) {
        self.thinkingBudgetTokens = thinkingBudgetTokens
    }

    func makeRequestBody(
        from chatBody: ChatRequestBody,
        model: String,
        stream: Bool
    ) -> AnthropicRequestBody {
        var systemBlocks: [AnthropicRequestBody.SystemBlock] = []
        var messages: [AnthropicRequestBody.Message] = []

        for message in chatBody.messages {
            switch message {
            case let .system(content, _),
                 let .developer(content, _):
                if let text = flattenTextContent(content), !text.isEmpty {
                    systemBlocks.append(.init(type: "text", text: text))
                }

            case let .user(content, _):
                let blocks = mapUserContent(content)
                if !blocks.isEmpty {
                    messages.append(.init(role: "user", content: blocks))
                }

            case let .assistant(content, toolCalls, _, thinkingBlocks):
                var blocks: [AnthropicRequestBody.ContentBlock] = []
                // Include thinking blocks for round-tripping in multi-turn tool-use conversations.
                // Thinking blocks must come before text/tool_use blocks in the assistant message.
                // See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking#preserve-thinking-blocks
                if let thinkingBlocks {
                    for block in thinkingBlocks {
                        switch block {
                        case let .thinking(thinkingBlock):
                            blocks.append(.thinking(
                                thinking: thinkingBlock.thinking,
                                signature: thinkingBlock.signature
                            ))
                        case let .redactedThinking(data):
                            blocks.append(.redactedThinking(data: data))
                        }
                    }
                }
                if let text = flattenAssistantContent(content), !text.isEmpty {
                    blocks.append(.text(text))
                }
                if let toolCalls {
                    for call in toolCalls {
                        let input = parseToolInput(call.function.arguments)
                        blocks.append(.toolUse(
                            id: call.id,
                            name: call.function.name,
                            input: input
                        ))
                    }
                }
                if !blocks.isEmpty {
                    messages.append(.init(role: "assistant", content: blocks))
                }

            case let .tool(content, toolCallID):
                if let text = flattenTextContent(content) {
                    messages.append(.init(role: "user", content: [
                        .toolResult(toolUseId: toolCallID, content: text),
                    ]))
                }
            }
        }

        let maxTokens = chatBody.maxCompletionTokens ?? 4096
        let thinkingConfig: AnthropicRequestBody.ThinkingConfig? = thinkingBudgetTokens > 0
            ? .init(type: "enabled", budgetTokens: thinkingBudgetTokens)
            : nil

        return AnthropicRequestBody(
            model: model,
            messages: messages,
            maxTokens: maxTokens,
            stream: stream,
            system: systemBlocks.isEmpty ? nil : systemBlocks,
            temperature: thinkingConfig != nil ? nil : chatBody.temperature,
            thinking: thinkingConfig,
            tools: chatBody.tools?.map(mapTool)
        )
    }

    private func flattenTextContent(
        _ content: ChatRequestBody.Message.MessageContent<String, [String]>
    ) -> String? {
        switch content {
        case let .text(text): text
        case let .parts(parts): parts.joined(separator: "\n")
        }
    }

    private func flattenAssistantContent(
        _ content: ChatRequestBody.Message.MessageContent<String, [String]>?
    ) -> String? {
        guard let content else { return nil }
        switch content {
        case let .text(text):
            return text.isEmpty ? nil : text
        case let .parts(parts):
            let joined = parts.filter { !$0.isEmpty }.joined(separator: "\n")
            return joined.isEmpty ? nil : joined
        }
    }

    private func mapUserContent(
        _ content: ChatRequestBody.Message.MessageContent<String, [ChatRequestBody.Message.ContentPart]>
    ) -> [AnthropicRequestBody.ContentBlock] {
        switch content {
        case let .text(text):
            text.isEmpty ? [] : [AnthropicRequestBody.ContentBlock.text(text)]
        case let .parts(parts):
            parts.compactMap { (part: ChatRequestBody.Message.ContentPart) -> AnthropicRequestBody.ContentBlock? in
                switch part {
                case let .text(text):
                    return text.isEmpty ? nil : AnthropicRequestBody.ContentBlock.text(text)
                case let .imageURL(url, _):
                    let urlString = url.absoluteString
                    guard urlString.hasPrefix("data:") else { return nil }
                    let components = urlString.split(separator: ",", maxSplits: 1)
                    guard components.count == 2 else { return nil }
                    let header = String(components[0])
                    let base64Data = String(components[1])
                    let mediaType = header
                        .replacingOccurrences(of: "data:", with: "")
                        .replacingOccurrences(of: ";base64", with: "")
                    return .image(mediaType: mediaType, data: base64Data)
                case .audioBase64:
                    return nil
                }
            }
        }
    }

    private func mapTool(_ tool: ChatRequestBody.Tool) -> AnthropicRequestBody.Tool {
        switch tool {
        case let .function(name, description, parameters, _):
            AnthropicRequestBody.Tool(
                name: name,
                description: description,
                inputSchema: parameters
            )
        }
    }

    private func parseToolInput(_ arguments: String?) -> [String: AnyCodingValue] {
        guard let arguments,
              let data = arguments.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: AnyCodingValue].self, from: data)
        else {
            return [:]
        }
        return decoded
    }
}
