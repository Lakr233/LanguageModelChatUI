//
//  OpenRouterClient.swift
//  ChatClientKit
//
//  Preconfigured OpenAI-compatible client for OpenRouter.
//  OpenRouter is a unified gateway to multiple LLM providers.
//
//  OpenRouter returns reasoning information in `reasoning_content`
//  (alias for `reasoning`) and `reasoning_details` array for
//  structured/encrypted reasoning from providers like Anthropic and OpenAI.
//
//  The `reasoning_details` array may contain:
//  - Plain text reasoning
//  - Encrypted reasoning blocks (must be round-tripped unmodified)
//  - Summarized reasoning
//
//  For multi-turn conversations with reasoning models, the
//  `reasoning_details` field must be passed back unmodified.
//

import Foundation

open class OpenRouterClient: OpenAICompatibleClient, @unchecked Sendable {
    public convenience init(
        model: String,
        apiKey: String? = nil
    ) {
        self.init(
            model: model,
            baseURL: "https://openrouter.ai/api",
            path: "/v1/chat/completions",
            apiKey: apiKey,
            defaultHeaders: [
                "HTTP-Referer": Bundle.main.bundleIdentifier ?? "com.app.chatclientkit",
            ]
        )
    }
}
