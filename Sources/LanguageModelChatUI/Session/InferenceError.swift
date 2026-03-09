//
//  InferenceError.swift
//  LanguageModelChatUI
//
//  Typed errors for inference and tool execution failures.
//

import Foundation

/// Errors that can occur during inference execution.
public enum InferenceError: LocalizedError, Sendable {
    /// The model returned no content (no text, reasoning, or tool calls).
    case noResponseFromModel

    /// A tool call referenced a tool that could not be found.
    case toolNotFound(name: String)

    /// A tool execution threw an error.
    case toolExecutionFailed(name: String, underlyingDescription: String)

    /// The inference was cancelled by the user or system.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .noResponseFromModel:
            String.localized("No response from model.")
        case let .toolNotFound(name):
            String.localized("Unable to find tool: \(name)")
        case let .toolExecutionFailed(name, description):
            String.localized("Tool \(name) failed: \(description)")
        case .cancelled:
            String.localized("Inference was cancelled.")
        }
    }
}
