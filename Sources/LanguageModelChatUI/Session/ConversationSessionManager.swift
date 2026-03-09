//
//  ConversationSessionManager.swift
//  LanguageModelChatUI
//
//  Manages active conversation sessions and their execution state.
//

import Combine
import Foundation

/// Manages all active conversation sessions.
@MainActor
public final class ConversationSessionManager: @unchecked Sendable {
    public static let shared = ConversationSessionManager()

    private var sessions: [String: ConversationSession] = [:]
    private var executingSessions = Set<String>()

    private let executingSessionsSubject = CurrentValueSubject<Set<String>, Never>([])
    public var executingSessionsPublisher: AnyPublisher<Set<String>, Never> {
        executingSessionsSubject.eraseToAnyPublisher()
    }

    private init() {}

    /// Get or create a session for the given conversation ID using explicit providers.
    public func session(for conversationID: String, configuration: ConversationSession.Configuration) -> ConversationSession {
        if let existing = sessions[conversationID] {
            return existing
        }
        let session = ConversationSession(id: conversationID, configuration: configuration)
        sessions[conversationID] = session
        return session
    }

    func markSessionExecuting(_ conversationID: String) {
        executingSessions.insert(conversationID)
        executingSessionsSubject.send(executingSessions)
    }

    func markSessionCompleted(_ conversationID: String) {
        executingSessions.remove(conversationID)
        executingSessionsSubject.send(executingSessions)
    }
}
