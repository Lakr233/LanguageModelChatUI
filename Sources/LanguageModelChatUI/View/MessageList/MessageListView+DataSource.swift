//
//  MessageListView+DataSource.swift
//  LanguageModelChatUI
//
//  Data source types and message-to-entry conversion.
//

import Foundation
import MarkdownView

extension MessageListView {
    /// A lightweight representation of a message for display purposes.
    struct MessageRepresentation: Hashable {
        let id: String
        let createdAt: Date
        let role: MessageRole
        let content: String
        var isRevealed: Bool
        var isThinking: Bool
        var thinkingDuration: TimeInterval
    }

    struct Attachments: Hashable {
        let items: [ChatInputAttachment]
    }

    /// Displayable entries for the list view.
    enum Entry: Hashable, Identifiable {
        case userContent(String, MessageRepresentation)
        case userAttachment(String, Attachments)
        case reasoningContent(String, MessageRepresentation)
        case responseContent(String, MessageRepresentation)
        case hint(String, String)
        case toolCallHint(String, ToolCallContentPart)
        case activityReporting(String)

        var id: String {
            switch self {
            case let .userContent(id, _): "user-\(id)"
            case let .userAttachment(id, _): "user-attachment-\(id)"
            case let .reasoningContent(id, _): "reasoning-\(id)"
            case let .responseContent(id, _): "response-\(id)"
            case let .hint(id, _): "hint-\(id)"
            case let .toolCallHint(id, _): "tool-\(id)"
            case let .activityReporting(msg): "activity-\(msg)"
            }
        }
    }

    /// Convert conversation messages to displayable entries.
    func entries(from messages: [ConversationMessage]) -> [Entry] {
        var entries: [Entry] = []
        var latestDisplayedDay: Date?

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let dayKeyFormatter = DateFormatter()
        dayKeyFormatter.dateFormat = "yyyy-MM-dd"

        func checkAddDateHint(_ date: Date) {
            if let latestDisplayedDay, Calendar.current.isDate(date, inSameDayAs: latestDisplayedDay) { return }
            latestDisplayedDay = date
            let hintText = dateFormatter.string(from: date)
            let dayKey = dayKeyFormatter.string(from: date)
            entries.append(.hint("date.\(dayKey)", hintText))
        }

        for message in messages {
            checkAddDateHint(message.createdAt)

            let textContent = message.textContent
            let reasoningContent = message.reasoningContent ?? ""
            let isThinking = textContent.isEmpty && !reasoningContent.isEmpty
            var reasoningDuration: TimeInterval = 0
            var reasoningCollapsed = false

            for part in message.parts {
                if case let .reasoning(rp) = part {
                    reasoningDuration = rp.duration
                    reasoningCollapsed = rp.isCollapsed
                }
            }

            let representation = MessageRepresentation(
                id: message.id,
                createdAt: message.createdAt,
                role: message.role,
                content: textContent,
                isRevealed: !reasoningCollapsed,
                isThinking: isThinking,
                thinkingDuration: reasoningDuration
            )

            switch message.role {
            case .user:
                let attachmentItems = message.parts.compactMap { part -> ChatInputAttachment? in
                    switch part {
                    case let .image(imagePart):
                        return ChatInputAttachment(
                            type: .image,
                            name: imagePart.name ?? String.localized("Image"),
                            previewImageData: imagePart.previewData ?? imagePart.data,
                            fileData: imagePart.data,
                            storageFilename: imagePart.name ?? "image.jpeg"
                        )
                    case let .audio(audioPart):
                        return ChatInputAttachment(
                            type: .audio,
                            name: audioPart.name ?? String.localized("Audio"),
                            fileData: audioPart.data,
                            textContent: audioPart.transcription ?? audioPart.name ?? "",
                            storageFilename: audioPart.name ?? "audio.m4a"
                        )
                    case let .file(filePart):
                        return ChatInputAttachment(
                            type: .document,
                            name: filePart.name ?? String.localized("Document"),
                            textContent: filePart.textContent ?? String(data: filePart.data, encoding: .utf8) ?? "",
                            storageFilename: filePart.name ?? "document.txt"
                        )
                    case .text, .reasoning, .toolCall, .toolResult:
                        return nil
                    }
                }
                if !attachmentItems.isEmpty {
                    entries.append(.userAttachment(message.id, .init(items: attachmentItems)))
                }
                if !textContent.isEmpty {
                    entries.append(.userContent(message.id, representation))
                }

            case .assistant:
                // Reasoning
                if !reasoningContent.isEmpty {
                    let reasoningRep = MessageRepresentation(
                        id: message.id,
                        createdAt: message.createdAt,
                        role: message.role,
                        content: reasoningContent,
                        isRevealed: !reasoningCollapsed,
                        isThinking: isThinking,
                        thinkingDuration: reasoningDuration
                    )
                    entries.append(.reasoningContent(message.id, reasoningRep))
                }

                // Tool calls
                for part in message.parts {
                    if case let .toolCall(tc) = part {
                        entries.append(.toolCallHint(tc.id, tc))
                    }
                }

                // Text content
                if !textContent.isEmpty {
                    entries.append(.responseContent(message.id, representation))
                }

            case .system:
                // System messages are not displayed in the list
                break

            default:
                // Custom roles: display as hint
                if !textContent.isEmpty {
                    entries.append(.hint(message.id, textContent))
                }
            }
        }

        return entries
    }
}

// MARK: - ToolCallContentPart Hashable

extension ToolCallContentPart: Hashable {
    public static func == (lhs: ToolCallContentPart, rhs: ToolCallContentPart) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(state)
    }
}

extension ToolCallState: Hashable {}
