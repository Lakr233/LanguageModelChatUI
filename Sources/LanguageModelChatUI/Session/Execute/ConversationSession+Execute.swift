//
//  ConversationSession+Execute.swift
//  LanguageModelChatUI
//
//  Core inference orchestration. Adapted from FlowDown with model-scoped clients.
//

import ChatClientKit
import Foundation
import UIKit

public extension ConversationSession {
    /// Input object representing what the user typed/attached.
    struct UserInput: Sendable {
        public var text: String
        public var attachments: [ContentPart]

        public init(text: String = "", attachments: [ContentPart] = []) {
            self.text = text
            self.attachments = attachments
        }
    }

    /// Execute inference for the given user input.
    func runInference(
        model: ConversationSession.Model,
        messageListView: MessageListView,
        input: UserInput,
        completion: @escaping @Sendable () -> Void
    ) {
        cancelCurrentTask { [self] in
            let bgToken = sessionDelegate?.beginBackgroundTask { [weak self] in
                Task { @MainActor in
                    self?.currentTask?.cancel()
                }
            }

            currentTask = Task { @MainActor in
                ConversationSessionManager.shared.markSessionExecuting(id)

                defer {
                    if let bgToken {
                        sessionDelegate?.endBackgroundTask(bgToken)
                    }
                }

                messageListView.loading()

                await executeInference(
                    model: model,
                    messageListView: messageListView,
                    input: input
                )

                self.currentTask = nil
                ConversationSessionManager.shared.markSessionCompleted(id)
                completion()
            }
        }
    }

    internal func requestUpdate(view: MessageListView) {
        view.stopLoading()
        notifyMessagesDidChange()
    }

    private func executeInference(
        model: ConversationSession.Model,
        messageListView: MessageListView,
        input: UserInput
    ) async {
        let modelCapabilities = model.capabilities
        let modelContextLength = model.contextLength

        // Prevent screen lock
        sessionDelegate?.preventIdleTimer()
        persistMessages()

        // Build request messages from conversation history
        var requestMessages = buildRequestMessages(capabilities: modelCapabilities)

        // Add user message
        _ = appendNewMessage(role: .user) { msg in
            msg.textContent = input.text
            for attachment in input.attachments {
                msg.parts.append(attachment)
            }
        }
        requestUpdate(view: messageListView)
        persistMessages()

        // Add user content to request using the same builder as history reconstruction.
        requestMessages.append(
            buildUserRequestMessage(
                text: input.text,
                attachments: input.attachments,
                capabilities: modelCapabilities
            )
        )

        // Inject system command
        await injectSystemPrompt(&requestMessages, capabilities: modelCapabilities)

        // Build tools list
        var tools: [ChatRequestBody.Tool]? = nil
        if modelCapabilities.contains(.tool), let toolProvider {
            await toolProvider.prepareForConversation()
            let toolDefs = await toolProvider.enabledTools()
            if !toolDefs.isEmpty {
                tools = toolDefs
            }
        }

        // Trim context
        messageListView.loading(with: String.localized("Calculating context window..."))
        await trimToContextLength(
            &requestMessages,
            tools: tools,
            maxTokens: modelContextLength
        )

        messageListView.stopLoading()

        // Execute inference loop
        do {
            var shouldContinue = false
            repeat {
                try checkCancellation()
                shouldContinue = try await executeInferenceStep(
                    messageListView: messageListView,
                    model: model,
                    requestMessages: &requestMessages,
                    tools: tools
                )
                persistMessages()
            } while shouldContinue

            requestUpdate(view: messageListView)

            await updateTitle()
        } catch {
            _ = appendNewMessage(role: .assistant) { msg in
                msg.textContent = "```\n\(error.localizedDescription)\n```"
            }
            requestUpdate(view: messageListView)
        }

        stopThinkingForAll()
        requestUpdate(view: messageListView)
        persistMessages()

        sessionDelegate?.allowIdleTimer()
    }
}
