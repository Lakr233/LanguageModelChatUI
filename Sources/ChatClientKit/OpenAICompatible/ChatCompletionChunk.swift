import Foundation

/// Streamed chunk of a chat completion response.
public struct ChatCompletionChunk: Sendable, Decodable {
    public var choices: [Choice]
}

public extension ChatCompletionChunk {
    struct Choice: Sendable, Decodable {
        public let delta: Delta

        public let index: Int?

        enum CodingKeys: String, CodingKey {
            case delta
            case index
        }

        public init(delta: Delta, index: Int? = nil) {
            self.delta = delta
            self.index = index
        }
    }
}

public extension ChatCompletionChunk.Choice {
    struct Delta: Sendable, Decodable {
        public let content: String?
        /// Reasoning content from providers that use `reasoning_content` (DeepSeek, Kimi, Grok).
        public let reasoningContent: String?
        /// Reasoning content from providers that use `reasoning` (Gemini via OpenRouter).
        public let reasoning: String?
        /// Structured reasoning details (Gemini). Contains text and encrypted blocks for round-tripping.
        public let reasoningDetails: [ReasoningDetail]?
        public let role: String?
        public let toolCalls: [ToolCall]?
        public let images: [CompletionImage]?

        enum CodingKeys: String, CodingKey {
            case content
            case reasoningContent = "reasoning_content"
            case reasoning
            case reasoningDetails = "reasoning_details"
            case role
            case toolCalls = "tool_calls"
            case images
        }

        public init(
            content: String? = nil,
            reasoningContent: String? = nil,
            reasoning: String? = nil,
            reasoningDetails: [ReasoningDetail]? = nil,
            role: String? = nil,
            toolCalls: [ToolCall]? = nil,
            images: [CompletionImage]? = nil
        ) {
            self.content = content
            self.reasoningContent = reasoningContent
            self.reasoning = reasoning
            self.reasoningDetails = reasoningDetails
            self.role = role
            self.toolCalls = toolCalls
            self.images = images
        }

        /// Resolved reasoning text from whichever field the provider uses.
        public var resolvedReasoning: String? {
            reasoningContent ?? reasoning
        }
    }
}

public extension ChatCompletionChunk.Choice.Delta {
    /// A reasoning detail block (e.g. from Gemini via OpenRouter).
    struct ReasoningDetail: Sendable, Decodable {
        public let type: String
        /// Plaintext reasoning (for `reasoning.text` type).
        public let text: String?
        /// Encrypted/opaque data (for `reasoning.encrypted` type). Must be preserved for round-tripping.
        public let data: String?
        public let format: String?
        public let index: Int?
    }
}

public extension ChatCompletionChunk.Choice.Delta {
    struct ToolCall: Sendable, Decodable {
        public let index: Int?
        public let id: String?
        public let type: String?
        public let function: Function?
    }
}

public extension ChatCompletionChunk.Choice.Delta.ToolCall {
    struct Function: Sendable, Decodable {
        public let name: String?
        public let arguments: String?
    }
}
