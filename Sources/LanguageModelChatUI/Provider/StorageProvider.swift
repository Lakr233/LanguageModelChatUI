//
//  StorageProvider.swift
//  LanguageModelChatUI
//
//  Third-party apps implement this protocol to provide data persistence.
//  The framework never touches the database directly.
//

import Foundation

/// Abstraction for message and conversation persistence.
///
/// Third-party apps implement this protocol using their own database
/// (CoreData, SwiftData, WCDB, SQLite, or even in-memory storage).
public protocol StorageProvider: AnyObject, Sendable {
    // MARK: - Messages

    /// Create a new message in the specified conversation.
    func createMessage(in conversationID: String, role: MessageRole) -> ConversationMessage

    /// Persist message changes to storage.
    func save(_ messages: [ConversationMessage])

    /// List all messages in a conversation, ordered by creation date.
    func messages(in conversationID: String) -> [ConversationMessage]

    /// Delete messages by ID.
    func delete(_ messageIDs: [String])

    // MARK: - Conversation Metadata

    /// Get the title of a conversation.
    func title(for id: String) -> String?

    /// Set the title of a conversation.
    func setTitle(_ title: String, for id: String)
}
