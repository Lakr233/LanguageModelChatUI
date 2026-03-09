//
//  AnthropicRequestBody.swift
//  ChatClientKit
//
//  Request body for the Anthropic Messages API.
//  See: https://docs.anthropic.com/en/api/messages
//

import Foundation

/// Request body for the Anthropic Messages API.
///
/// Content blocks support thinking/redacted_thinking types for extended thinking round-tripping.
/// See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking#preserve-thinking-blocks
struct AnthropicRequestBody: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let stream: Bool
    let system: [SystemBlock]?
    let temperature: Double?
    let thinking: ThinkingConfig?
    let tools: [Tool]?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case stream
        case system
        case temperature
        case thinking
        case tools
    }
}

extension AnthropicRequestBody {
    struct ThinkingConfig: Encodable {
        let type: String
        let budgetTokens: Int

        enum CodingKeys: String, CodingKey {
            case type
            case budgetTokens = "budget_tokens"
        }
    }
}

extension AnthropicRequestBody {
    struct Message: Encodable {
        let role: String
        let content: [ContentBlock]
    }
}

extension AnthropicRequestBody {
    enum ContentBlock: Encodable {
        case text(String)
        case image(mediaType: String, data: String)
        case toolUse(id: String, name: String, input: [String: AnyCodingValue])
        case toolResult(toolUseId: String, content: String)
        case thinking(thinking: String, signature: String)
        case redactedThinking(data: String)

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case source
            case mediaType = "media_type"
            case data
            case id
            case name
            case input
            case toolUseId = "tool_use_id"
            case content
            case thinking
            case signature
        }

        enum SourceKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .text(text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case let .image(mediaType, data):
                try container.encode("image", forKey: .type)
                var sourceContainer = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
                try sourceContainer.encode("base64", forKey: .type)
                try sourceContainer.encode(mediaType, forKey: .mediaType)
                try sourceContainer.encode(data, forKey: .data)
            case let .toolUse(id, name, input):
                try container.encode("tool_use", forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
                try container.encode(input, forKey: .input)
            case let .toolResult(toolUseId, content):
                try container.encode("tool_result", forKey: .type)
                try container.encode(toolUseId, forKey: .toolUseId)
                try container.encode(content, forKey: .content)
            case let .thinking(thinking, signature):
                try container.encode("thinking", forKey: .type)
                try container.encode(thinking, forKey: .thinking)
                try container.encode(signature, forKey: .signature)
            case let .redactedThinking(data):
                try container.encode("redacted_thinking", forKey: .type)
                try container.encode(data, forKey: .data)
            }
        }
    }
}

extension AnthropicRequestBody {
    struct Tool: Encodable {
        let name: String
        let description: String?
        let inputSchema: [String: AnyCodingValue]?

        enum CodingKeys: String, CodingKey {
            case name
            case description
            case inputSchema = "input_schema"
        }
    }
}

extension AnthropicRequestBody {
    struct SystemBlock: Encodable {
        let type: String
        let text: String
    }
}
