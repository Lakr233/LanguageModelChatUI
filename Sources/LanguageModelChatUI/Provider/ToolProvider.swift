//
//  ToolProvider.swift
//  LanguageModelChatUI
//
//  Optional protocol for tool/function calling support.
//  Pass nil when configuring to disable tools entirely.
//

import ChatClientKit
import Foundation
import UIKit

/// Information about an executable tool.
public protocol ToolExecutor: Sendable {
    /// Display name for the tool.
    var displayName: String { get }
    /// SF Symbol name for the tool icon.
    var iconName: String { get }
}

/// Result of a tool execution.
public struct ToolResult: Sendable {
    /// The type of content returned by a tool.
    public enum ResultType: Sendable {
        /// Plain text output.
        case text(String)
        /// Structured JSON data.
        case json(Data)
        /// An error message.
        case error(String)
    }

    /// The typed content of the tool result.
    public let content: ResultType

    /// Whether this result represents an error.
    public var isError: Bool {
        if case .error = content { return true }
        return false
    }

    /// The text representation of the result (for backward compatibility and request building).
    public var output: String {
        switch content {
        case let .text(text): text
        case let .json(data): String(data: data, encoding: .utf8) ?? "{}"
        case let .error(message): message
        }
    }

    /// Create a text result.
    public init(text: String) {
        content = .text(text)
    }

    /// Create a JSON result.
    public init(json: Data) {
        content = .json(json)
    }

    /// Create an error result.
    public init(error: String) {
        content = .error(error)
    }

    /// Backward-compatible initializer.
    public init(output: String, isError: Bool = false) {
        content = isError ? .error(output) : .text(output)
    }
}

/// Abstraction for tool/function calling support.
///
/// Implement this protocol to enable the model to call tools.
/// Pass `nil` in `ConversationSession.Configuration.tools` to disable tools.
public protocol ToolProvider: AnyObject, Sendable {
    /// Returns the list of enabled tool definitions.
    func enabledTools() async -> [ChatRequestBody.Tool]

    /// Find the tool executor for a given tool request.
    func findTool(for request: ToolRequest) async -> ToolExecutor?

    /// Execute a tool with the given parameters.
    func executeTool(
        _ tool: ToolExecutor,
        parameters: String,
        anchor: UIView?
    ) async throws -> ToolResult

    /// Called before a conversation starts, to set up tool state.
    func prepareForConversation() async
}
