//
//  SessionDelegate.swift
//  LanguageModelChatUI
//
//  Callbacks for app-specific behaviors during conversation execution.
//

import Foundation

/// Delegate for application-level behaviors during conversation execution.
///
/// Provides hooks for background task management, UI presentation, and
/// optional context injection. All methods have default implementations
/// that do nothing, so you only need to implement what you need.
public protocol SessionDelegate: AnyObject, Sendable {
    // MARK: - Background Task Management

    /// Begin a background task. Return a token to end it later.
    func beginBackgroundTask(expiration: @escaping @Sendable () -> Void) -> Any?

    /// End a previously started background task.
    func endBackgroundTask(_ token: Any)

    /// Prevent the screen from locking during inference.
    func preventIdleTimer()

    /// Allow the screen to lock normally after inference completes.
    func allowIdleTimer()

    // MARK: - Usage Tracking

    /// Called when token usage is reported after an inference step.
    func sessionDidReportUsage(_ usage: TokenUsage, for conversationID: String)

    // MARK: - Optional Context

    /// Provide proactive memory context to inject into system prompt.
    func proactiveMemoryContext() async -> String?

    /// Provide search sensitivity prompt text.
    func searchSensitivityPrompt() -> String?
}

// MARK: - Default Implementations

public extension SessionDelegate {
    func beginBackgroundTask(expiration _: @escaping @Sendable () -> Void) -> Any? {
        nil
    }

    func endBackgroundTask(_: Any) {}
    func preventIdleTimer() {}
    func allowIdleTimer() {}
    func sessionDidReportUsage(_: TokenUsage, for _: String) {}
    func proactiveMemoryContext() async -> String? {
        nil
    }

    func searchSensitivityPrompt() -> String? {
        nil
    }
}
