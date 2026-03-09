//
//  MoonshotClient.swift
//  ChatClientKit
//
//  Preconfigured OpenAI-compatible client for Moonshot/Kimi API.
//  Handles `reasoning_content` field natively via ChatCompletionChunk.
//
//  Kimi thinking models (kimi-k2-thinking, kimi-k2.5) return
//  reasoning content in `reasoning_content` field during streaming.
//
//  Rules for `reasoning_content` in follow-up requests (same as DeepSeek V3.2):
//  - Assistant messages WITH tool_calls: reasoning_content MUST be preserved
//    when thinking mode is active (omitting causes "thinking is enabled but
//    reasoning_content is missing" error).
//    Ref: https://platform.moonshot.ai/docs/guide/use-kimi-api-to-complete-tool-calls
//  - Assistant messages WITHOUT tool_calls: reasoning_content must be stripped
//    (not accepted in regular multi-turn).
//  - content must be "" (not absent/null) when tool_calls are present.
//

import Foundation

open class MoonshotClient: OpenAICompatibleClient, @unchecked Sendable {
    public convenience init(
        model: String = "kimi-k2.5",
        apiKey: String? = nil
    ) {
        self.init(
            model: model,
            baseURL: "https://api.moonshot.cn/v1",
            path: "/chat/completions",
            apiKey: apiKey
        )
    }

    /// Conditionally strip `reasoning` based on whether the assistant message
    /// has tool calls (mirrors DeepSeek V3.2 thinking-integrated tool-use rules):
    /// - With tool_calls → preserve reasoning (required when thinking mode active)
    /// - Without tool_calls → strip reasoning (causes errors if included)
    ///
    /// Also ensures `content` is "" (not absent) when tool_calls are present,
    /// as required by the Kimi API.
    ///
    /// See: https://platform.moonshot.ai/docs/guide/use-kimi-api-to-complete-tool-calls
    override func applyModelSettings(to body: ChatRequestBody, streaming: Bool) -> ChatRequestBody {
        var requestBody = body.mergingAdjacentAssistantMessages()
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
