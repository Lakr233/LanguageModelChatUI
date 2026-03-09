//
//  DisposableStorageProvider.swift
//  LanguageModelChatUI
//
//  Created by qaq on 9/3/2026.
//

import Foundation

public final class DisposableStorageProvider: StorageProvider, @unchecked Sendable {
    public static let shared = DisposableStorageProvider()

    public init() {}

    private var messages: [String: [ConversationMessage]] = [:]
    private var titles: [String: String] = [:]
    private let lock = NSLock()

    public func createMessage(in conversationIdentifier: String, role: MessageRole) -> ConversationMessage {
        let message = ConversationMessage(conversationID: conversationIdentifier, role: role)
        lock.lock()
        messages[conversationIdentifier, default: []].append(message)
        lock.unlock()
        return message
    }

    public func save(_ messages: [ConversationMessage]) {
        lock.lock()
        for msg in messages {
            var list = self.messages[msg.conversationID] ?? []
            if let index = list.firstIndex(where: { $0.id == msg.id }) {
                list[index] = msg
            } else {
                list.append(msg)
            }
            self.messages[msg.conversationID] = list
        }
        lock.unlock()
    }

    public func messages(in conversationID: String) -> [ConversationMessage] {
        lock.lock()
        let result = messages[conversationID] ?? []
        lock.unlock()
        return result.sorted { $0.createdAt < $1.createdAt }
    }

    public func delete(_ messageIDs: [String]) {
        lock.lock()
        for (convID, list) in messages {
            messages[convID] = list.filter { !messageIDs.contains($0.id) }
        }
        lock.unlock()
    }

    public func title(for id: String) -> String? {
        lock.lock()
        let result = titles[id]
        lock.unlock()
        return result
    }

    public func setTitle(_ title: String, for id: String) {
        lock.lock()
        titles[id] = title
        lock.unlock()
    }
}
