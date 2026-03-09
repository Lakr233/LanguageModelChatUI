//
//  DeepSeekClient.swift
//  ChatClientKit
//
//  Preconfigured OpenAI-compatible client for DeepSeek API.
//  Handles `reasoning_content` field natively via ChatCompletionChunk.
//
//  Note: DeepSeek V3.2 introduced thinking-integrated tool-use.
//  Rules for reasoning_content in follow-up requests:
//  - Assistant messages WITH tool_calls: reasoning_content MUST be sent back
//    (omitting it causes HTTP 400). Ref: https://api-docs.deepseek.com/guides/reasoning_model
//  - Assistant messages WITHOUT tool_calls: reasoning_content must NOT be sent
//    (causes HTTP 400 in regular multi-turn).
//

import Foundation

open class DeepSeekClient: OpenAICompatibleClient, @unchecked Sendable {
    public convenience init(
        model: String = "deepseek-reasoner",
        apiKey: String? = nil
    ) {
        self.init(
            model: model,
            baseURL: "https://api.deepseek.com",
            path: "/chat/completions",
            apiKey: apiKey
        )
    }

    /// Conditionally strip `reasoning` based on whether the assistant message
    /// has tool calls:
    /// - With tool_calls → preserve reasoning (required by DeepSeek API)
    /// - Without tool_calls → strip reasoning (causes 400 if included)
    ///
    /// Also ensures `content` is "" (not absent) when tool_calls are present.
    ///
    /// See: https://api-docs.deepseek.com/guides/reasoning_model
    ///      https://api-docs.deepseek.com/guides/tool_calls
    override func applyModelSettings(to body: ChatRequestBody, streaming: Bool) -> ChatRequestBody {
        var requestBody = body
        requestBody.model = model
        requestBody.stream = streaming
        requestBody.messages = requestBody.messages.map { message in
            switch message {
            case let .assistant(content, toolCalls, reasoning, thinkingBlocks):
                let hasToolCalls = toolCalls != nil && !toolCalls!.isEmpty
                // Preserve reasoning only when tool_calls are present.
                let resolvedReasoning = hasToolCalls ? reasoning : nil
                // Ensure content field is present when tool_calls exist.
                let resolvedContent: ChatRequestBody.Message.MessageContent<String, [String]>? = if hasToolCalls, content == nil {
                    .text("")
                } else {
                    content
                }
                return .assistant(
                    content: resolvedContent,
                    toolCalls: toolCalls,
                    reasoning: resolvedReasoning,
                    thinkingBlocks: thinkingBlocks
                )
            default:
                return message
            }
        }
        return requestBody
    }
}
