//
//  ConversationTitleMetadata.swift
//  LanguageModelChatUI
//

import ChatClientKit
import Foundation

struct ConversationTitleMetadata: Equatable {
    static let defaultAvatar = "💬"
    static let generationToolName = "set_conversation_title"

    let title: String
    let avatar: String

    init(title: String, avatar: String = Self.defaultAvatar) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAvatar = avatar.trimmingCharacters(in: .whitespacesAndNewlines)
        self.avatar = trimmedAvatar.isEmpty ? Self.defaultAvatar : trimmedAvatar
    }

    init?(storageValue: String?) {
        guard let storageValue else { return nil }
        let trimmed = storageValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let xmlValue = Self.decodeXML(from: trimmed) else { return nil }
        self = xmlValue
    }

    init?(toolArguments: String) {
        struct Payload: Decodable {
            let title: String
            let titleAvatar: String?
            let titleEvator: String?
            let emoji: String?
        }

        guard let data = toolArguments.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            return nil
        }

        let resolvedAvatar = payload.titleAvatar ?? payload.titleEvator ?? payload.emoji ?? Self.defaultAvatar
        self.init(title: payload.title, avatar: resolvedAvatar)
    }

    var storageValue: String {
        """
        <conversationTitle>
          <title>\(Self.escapeXML(title))</title>
          <titleAvatar>\(Self.escapeXML(avatar))</titleAvatar>
        </conversationTitle>
        """
    }

    static var generationTool: ChatRequestBody.Tool {
        .function(
            name: generationToolName,
            description: "Set the conversation title metadata with a short title and a single emoji avatar.",
            parameters: [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "description": "Short conversation title, maximum 6 words.",
                    ],
                    "titleAvatar": [
                        "type": "string",
                        "description": "Exactly one emoji representing the conversation.",
                    ],
                ],
                "required": ["title", "titleAvatar"],
                "additionalProperties": false,
            ],
            strict: true
        )
    }

    private static func decodeXML(from string: String) -> ConversationTitleMetadata? {
        let title = value(for: ["title"], in: string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }

        let avatar = value(for: ["titleAvatar", "titleEvator", "emoji"], in: string) ?? Self.defaultAvatar
        return .init(title: unescapeXML(title), avatar: unescapeXML(avatar))
    }

    private static func value(for tags: [String], in string: String) -> String? {
        for tag in tags {
            guard let regex = try? NSRegularExpression(
                pattern: "<\\s*\(tag)\\s*>(.*?)<\\s*/\\s*\(tag)\\s*>",
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else {
                continue
            }

            let range = NSRange(string.startIndex ..< string.endIndex, in: string)
            guard let match = regex.firstMatch(in: string, options: [], range: range),
                  let valueRange = Range(match.range(at: 1), in: string)
            else {
                continue
            }
            return String(string[valueRange])
        }
        return nil
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func unescapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
