//
//  ConversationSession+BuildMessages.swift
//  LanguageModelChatUI
//
//  Converts conversation messages to ChatRequestBody format.
//

import ChatClientKit
import Foundation
import OSLog

private let requestBuildLogger = Logger(subsystem: "LanguageModelChatUI", category: "RequestBuild")

extension ConversationSession {
    /// Build request messages from conversation history.
    func buildRequestMessages(capabilities: Set<ModelCapability>) -> [ChatRequestBody.Message] {
        messages.flatMap { buildRequestMessages(from: $0, capabilities: capabilities) }
    }

    func buildRequestMessages(
        from message: ConversationMessage,
        capabilities: Set<ModelCapability>
    ) -> [ChatRequestBody.Message] {
        switch message.role {
        case .system:
            let content = message.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return [] }
            if capabilities.contains(.developerRole) {
                return [.developer(content: .text(content))]
            }
            return [.system(content: .text(content))]

        case .user:
            return [
                buildUserRequestMessage(
                    text: message.textContent,
                    attachments: message.parts,
                    capabilities: capabilities
                ),
            ]

        case .assistant:
            let text = message.textContent
            let reasoning = message.reasoningContent
            let toolCalls: [ChatRequestBody.Message.ToolCall] = message.parts.compactMap { part in
                guard case let .toolCall(value) = part else { return nil }
                return .init(
                    id: value.id, function: .init(name: value.toolName, arguments: value.parameters)
                )
            }
            let toolResults: [ChatRequestBody.Message] = message.parts.compactMap { part in
                guard case let .toolResult(value) = part else { return nil }
                return .tool(content: .text(value.result), toolCallID: value.toolCallID)
            }

            var result: [ChatRequestBody.Message] = [
                .assistant(
                    content: text.isEmpty ? nil : .text(text),
                    toolCalls: toolCalls.isEmpty ? nil : toolCalls,
                    reasoning: reasoning
                ),
            ]
            result.append(contentsOf: toolResults)
            return result

        default:
            if message.role.rawValue == "tool",
               let toolResult = message.parts.compactMap({ part -> ToolResultContentPart? in
                   guard case let .toolResult(value) = part else { return nil }
                   return value
               }).first
            {
                return [.tool(content: .text(toolResult.result), toolCallID: toolResult.toolCallID)]
            }

            let text = message.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? [] : [.user(content: .text(text))]
        }
    }

    func buildUserRequestMessage(
        text: String,
        attachments: [ContentPart],
        capabilities: Set<ModelCapability>
    ) -> ChatRequestBody.Message {
        let parts = buildUserRequestContentParts(
            text: text,
            attachments: attachments,
            capabilities: capabilities
        )

        if parts.count == 1, case let .text(singleText) = parts.first {
            return .user(content: .text(singleText))
        }
        return .user(content: .parts(parts))
    }

    func buildUserRequestContentParts(
        text: String,
        attachments: [ContentPart],
        capabilities: Set<ModelCapability>
    ) -> [ChatRequestBody.Message.ContentPart] {
        var parts: [ChatRequestBody.Message.ContentPart] = []
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            parts.append(.text(trimmedText))
        }

        for attachment in attachments {
            switch attachment {
            case .text:
                break

            case let .image(imagePart):
                guard capabilities.contains(.visual) else {
                    requestBuildLogger.warning("dropping image attachment because visual capability is disabled")
                    continue
                }
                guard !imagePart.data.isEmpty else {
                    requestBuildLogger.warning("dropping image attachment because image data is empty")
                    continue
                }
                let base64 = imagePart.data.base64EncodedString()
                let dataURL = "data:\(imagePart.mediaType);base64,\(base64)"
                if let url = URL(string: dataURL) {
                    parts.append(.imageURL(url))
                    requestBuildLogger.info(
                        "appended image part mediaType=\(imagePart.mediaType) bytes=\(imagePart.data.count) previewBytes=\(imagePart.previewData?.count ?? 0)"
                    )
                } else {
                    requestBuildLogger.error("failed to create image data URL for mediaType=\(imagePart.mediaType)")
                }

            case let .audio(audioPart):
                if capabilities.contains(.auditory), !audioPart.data.isEmpty {
                    let base64 = audioPart.data.base64EncodedString()
                    let format = audioPart.mediaType.components(separatedBy: "/").last ?? "m4a"
                    parts.append(.audioBase64(base64, format: format))
                } else if let transcription = audioPart.transcription?
                    .trimmingCharacters(in: .whitespacesAndNewlines), !transcription.isEmpty
                {
                    parts.append(.text("[Audio transcription]: \(transcription)"))
                }

            case let .file(filePart):
                if let textRep = filePart.textContent?
                    .trimmingCharacters(in: .whitespacesAndNewlines), !textRep.isEmpty
                {
                    parts.append(.text("[File: \(filePart.name ?? "unnamed")]\n\(textRep)"))
                }

            case .reasoning, .toolCall, .toolResult:
                break
            }
        }

        if parts.isEmpty {
            parts.append(.text(trimmedText.isEmpty ? "(empty)" : trimmedText))
        }

        let imagePartsCount = parts.reduce(into: 0) { count, part in
            if case .imageURL = part { count += 1 }
        }
        let audioPartsCount = parts.reduce(into: 0) { count, part in
            if case .audioBase64 = part { count += 1 }
        }
        let textPartsCount = parts.reduce(into: 0) { count, part in
            if case .text = part { count += 1 }
        }
        requestBuildLogger.info(
            "built user request content parts textChars=\(trimmedText.count) attachments=\(attachments.count) outputParts=\(parts.count) textParts=\(textPartsCount) imageParts=\(imagePartsCount) audioParts=\(audioPartsCount)"
        )

        return parts
    }
}
