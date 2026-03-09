//
//  FinishReason.swift
//  LanguageModelChatUI
//
//  Tracks why model generation stopped, inspired by Vercel AI SDK.
//

import Foundation

/// The reason a model stopped generating output.
public enum FinishReason: String, Sendable, Hashable {
    /// Natural stop (end of response).
    case stop
    /// Hit the maximum token/context length.
    case length
    /// The model requested tool calls.
    case toolCalls
    /// Content was filtered by safety systems.
    case contentFilter
    /// An error occurred during generation.
    case error
    /// Reason is unknown or not reported.
    case unknown
}
