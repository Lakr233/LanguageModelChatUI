import Foundation

public enum ChatResponseChunk: Sendable, Equatable {
    case reasoning(String)
    case text(String)
    case image(ImageContent)
    case tool(ToolRequest)

    /// A complete thinking block with its verification signature.
    /// Emitted at the end of each Anthropic thinking block.
    /// Must be preserved and sent back for multi-turn tool-use conversations.
    /// See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking#preserve-thinking-blocks
    case thinkingBlock(ThinkingBlock)

    /// A redacted (encrypted) thinking block from Anthropic's safety system.
    /// Must be preserved verbatim for round-tripping.
    /// See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking#redacted-thinking-blocks
    case redactedThinking(data: String)
}

/// A structured thinking block for Anthropic extended thinking.
/// Contains the plaintext reasoning and its cryptographic signature.
/// See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking
public struct ThinkingBlock: Sendable, Equatable {
    public let thinking: String
    public let signature: String

    public init(thinking: String, signature: String) {
        self.thinking = thinking
        self.signature = signature
    }
}

public extension ChatResponseChunk {
    var textValue: String? {
        if case let .text(value) = self { value } else { nil }
    }

    var reasoningValue: String? {
        if case let .reasoning(value) = self { value } else { nil }
    }

    var imageValue: ImageContent? {
        if case let .image(value) = self { value } else { nil }
    }

    var toolValue: ToolRequest? {
        if case let .tool(value) = self { value } else { nil }
    }

    var thinkingBlockValue: ThinkingBlock? {
        if case let .thinkingBlock(value) = self { value } else { nil }
    }
}
