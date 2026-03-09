//
//  MessageRole.swift
//  LanguageModelChatUI
//

import Foundation

/// An extensible message role type (similar to Notification.Name pattern).
///
/// The framework provides three built-in roles: `.user`, `.assistant`, `.system`.
/// Third-party apps can extend with custom roles:
///
///     extension MessageRole {
///         static let toolHint = MessageRole(rawValue: "toolHint")
///     }
///
public struct MessageRole: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let user = MessageRole(rawValue: "user")
    public static let assistant = MessageRole(rawValue: "assistant")
    public static let system = MessageRole(rawValue: "system")
}
