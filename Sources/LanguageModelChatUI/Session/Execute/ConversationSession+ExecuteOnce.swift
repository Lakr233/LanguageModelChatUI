//
//  ConversationSession+ExecuteOnce.swift
//  LanguageModelChatUI
//
//  Single inference call with streaming response handling.
//

import ChatClientKit
import Foundation

extension ConversationSession {
    func checkCancellation() throws {
        if Task.isCancelled {
            throw CancellationError()
        }
    }

    func executeInferenceStep(
        messageListView: MessageListView,
        model: ConversationSession.Model,
        requestMessages: inout [ChatRequestBody.Message],
        tools: [ChatRequestBody.Tool]?
    ) async throws -> Bool {
        try checkCancellation()
        requestUpdate(view: messageListView)
        messageListView.loading()

        let message = appendNewMessage(role: .assistant)
        let collapseAfterReasoningComplete = collapseReasoningWhenComplete

        let client = model.client
        let stream = try await client.streamingChat(
            body: .init(
                model: model.model,
                messages: requestMessages,
                stream: true,
                tools: tools
            )
        )
        defer { stopThinking(for: message.id) }

        func collapseReasoning() {
            guard collapseAfterReasoningComplete else { return }
            for (index, part) in message.parts.enumerated() {
                if case var .reasoning(rp) = part {
                    rp.isCollapsed = true
                    message.parts[index] = .reasoning(rp)
                    break
                }
            }
        }

        func updateVisibleState() {
            if !message.textContent.isEmpty {
                stopThinking(for: message.id)
                collapseReasoning()
            } else if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                startThinking(for: message.id)
            }
        }

        let reasoningEmitter = await MainActor.run {
            BalancedEmitter(duration: 1.0, frequency: 30) { chunk in
                let current = message.reasoningContent ?? ""
                message.reasoningContent = current + chunk
                updateVisibleState()
                self.requestUpdate(view: messageListView)
            }
        }
        let textEmitter = await MainActor.run {
            BalancedEmitter(duration: 0.5, frequency: 20) { chunk in
                message.textContent += chunk
                updateVisibleState()
                self.requestUpdate(view: messageListView)
            }
        }
        defer {
            reasoningEmitter.cancel()
            textEmitter.cancel()
        }

        var pendingToolCalls: [ToolRequest] = []
        var streamedCharacterCount = 0

        for try await resp in stream {
            try checkCancellation()
            switch resp {
            case let .reasoning(value):
                await textEmitter.wait()
                reasoningEmitter.add(value)

            case let .text(value):
                await reasoningEmitter.wait()
                if streamedCharacterCount >= 5000 {
                    textEmitter.update(duration: 1.0, frequency: 3)
                } else if streamedCharacterCount >= 2000 {
                    textEmitter.update(duration: 1.0, frequency: 9)
                } else if streamedCharacterCount >= 1000 {
                    textEmitter.update(duration: 0.5, frequency: 15)
                }
                textEmitter.add(value)
                streamedCharacterCount += value.count

            case let .tool(call):
                await reasoningEmitter.wait()
                await textEmitter.wait()
                pendingToolCalls.append(call)

            case .image:
                await reasoningEmitter.wait()
                await textEmitter.wait()

            case .thinkingBlock, .redactedThinking:
                // Thinking blocks are preserved for API round-tripping but don't need UI display.
                break
            }
        }

        await reasoningEmitter.wait()
        await textEmitter.wait()

        stopThinking(for: message.id)
        requestUpdate(view: messageListView)

        collapseReasoning()
        if collapseAfterReasoningComplete {
            requestUpdate(view: messageListView)
        }

        let isFollowUpAfterToolResult: Bool = {
            guard let lastMessage = requestMessages.last else { return false }
            if case .tool = lastMessage {
                return true
            }
            return false
        }()

        if isFollowUpAfterToolResult,
           pendingToolCalls.isEmpty,
           message.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           (message.reasoningContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            removeMessage(with: message.id)
            requestUpdate(view: messageListView)
            return false
        }

        if message.reasoningContent != nil, !(message.reasoningContent ?? "").isEmpty,
           message.textContent.isEmpty
        {
            message.textContent = String.localized("Thinking finished without output any content.")
        }

        requestUpdate(view: messageListView)

        requestMessages.append(
            .assistant(
                content: message.textContent.isEmpty ? nil : .text(message.textContent),
                toolCalls: pendingToolCalls.map {
                    .init(id: $0.id, function: .init(name: $0.name, arguments: $0.arguments))
                },
                reasoning: {
                    let trimmed = (message.reasoningContent ?? "").trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    return trimmed.isEmpty ? nil : trimmed
                }()
            )
        )

        if message.textContent.isEmpty, (message.reasoningContent ?? "").isEmpty, pendingToolCalls.isEmpty {
            message.finishReason = .error
            throw InferenceError.noResponseFromModel
        } else if !pendingToolCalls.isEmpty {
            message.finishReason = .toolCalls
        } else {
            message.finishReason = .stop
        }

        guard let toolProvider, !pendingToolCalls.isEmpty else { return false }

        messageListView.loading(with: String.localized("Utilizing tool call"))

        struct ToolCallEntry {
            let request: ToolRequest
            let tool: ToolExecutor
            let hintMessage: ConversationMessage
        }

        var toolCallEntries: [ToolCallEntry] = []
        for request in pendingToolCalls {
            try checkCancellation()
            guard let tool = await toolProvider.findTool(for: request) else {
                throw InferenceError.toolNotFound(name: request.name)
            }
            let hintMessage = appendNewMessage(role: .assistant) { msg in
                msg.parts.append(
                    .toolCall(
                        ToolCallContentPart(
                            id: request.id,
                            toolName: tool.displayName,
                            apiName: request.name,
                            toolIcon: tool.iconName,
                            parameters: request.arguments,
                            state: .running
                        )
                    )
                )
            }
            toolCallEntries.append(ToolCallEntry(request: request, tool: tool, hintMessage: hintMessage))
        }
        requestUpdate(view: messageListView)

        let toolResponseLimit = 64 * 1024
        var orderedToolResponses = [(text: String, isError: Bool)?](
            repeating: nil,
            count: toolCallEntries.count
        )

        await withTaskGroup(of: (Int, String, Bool).self) { group in
            for (index, entry) in toolCallEntries.enumerated() {
                group.addTask { [toolProvider] in
                    do {
                        let result = try await toolProvider.executeTool(
                            entry.tool,
                            parameters: entry.request.arguments,
                            anchor: messageListView
                        )
                        var text = result.output
                        if text.count > toolResponseLimit {
                            text = "\(String(text.prefix(toolResponseLimit)))...\n\(String.localized("Output truncated."))"
                        }
                        return (
                            index,
                            text.isEmpty ? String.localized("Tool executed successfully with no output") : text,
                            result.isError
                        )
                    } catch {
                        return (index, String.localized("Tool execution failed: \(error.localizedDescription)"), true)
                    }
                }
            }

            for await (index, responseText, isError) in group {
                orderedToolResponses[index] = (responseText, isError)
            }
        }

        for (index, entry) in toolCallEntries.enumerated() {
            guard let response = orderedToolResponses[index] else { continue }

            for (partIndex, part) in entry.hintMessage.parts.enumerated() {
                if case var .toolCall(tc) = part {
                    tc.state = response.isError ? .failed : .succeeded
                    entry.hintMessage.parts[partIndex] = .toolCall(tc)
                    break
                }
            }
            entry.hintMessage.parts.append(
                .toolResult(.init(toolCallID: entry.request.id, result: response.text))
            )
            requestUpdate(view: messageListView)

            requestMessages.append(
                .tool(
                    content: .text(response.text),
                    toolCallID: entry.request.id
                )
            )
        }

        requestUpdate(view: messageListView)
        return true
    }
}
