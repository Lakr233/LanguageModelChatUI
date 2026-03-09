//
//  TokenUsage.swift
//  LanguageModelChatUI
//
//  Token usage tracking for inference calls, inspired by Vercel AI SDK.
//

import Foundation

/// Token usage statistics for a single inference call.
public struct TokenUsage: Sendable, Equatable {
    /// Number of tokens in the input/prompt.
    public var inputTokens: Int

    /// Number of tokens in the output/completion.
    public var outputTokens: Int

    /// Total tokens used (input + output).
    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    public init(inputTokens: Int = 0, outputTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    /// Combine two usage records (for multi-step inference).
    public func adding(_ other: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: inputTokens + other.inputTokens,
            outputTokens: outputTokens + other.outputTokens
        )
    }
}
