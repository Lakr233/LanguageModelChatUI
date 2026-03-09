//
//  AnthropicStreamEvent.swift
//  ChatClientKit
//

import Foundation

/// Decoded stream event from the Anthropic Messages API.
struct AnthropicStreamEvent: Decodable {
    let type: String

    /// message_start
    let message: AnthropicMessage?

    // content_block_start
    let index: Int?
    let contentBlock: AnthropicContentBlock?

    /// content_block_delta
    let delta: AnthropicDelta?

    /// message_delta
    let usage: AnthropicUsage?

    /// error
    let error: AnthropicError?

    enum CodingKeys: String, CodingKey {
        case type
        case message
        case index
        case contentBlock = "content_block"
        case delta
        case usage
        case error
    }
}

struct AnthropicMessage: Decodable {
    let id: String?
    let type: String?
    let role: String?
    let model: String?
    let stopReason: String?
    let usage: AnthropicUsage?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case model
        case stopReason = "stop_reason"
        case usage
    }
}

struct AnthropicContentBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let thinking: String?
    let signature: String?
    let data: String?
}

struct AnthropicDelta: Decodable {
    let type: String?
    let text: String?
    let thinking: String?
    let partialJson: String?
    let stopReason: String?
    let signature: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case thinking
        case partialJson = "partial_json"
        case stopReason = "stop_reason"
        case signature
    }
}

struct AnthropicUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

struct AnthropicError: Decodable {
    let type: String?
    let message: String?
}
