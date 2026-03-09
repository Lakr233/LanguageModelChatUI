//
//  GrokClient.swift
//  ChatClientKit
//
//  Preconfigured OpenAI-compatible client for xAI Grok API.
//  Handles `reasoning_content` field natively via ChatCompletionChunk.
//
//  Note: Grok models (grok-3-mini, grok-4-fast-reasoning) return
//  reasoning content in `reasoning_content` field during streaming.
//  Set streaming to true for access to thinking traces.
//

import Foundation

open class GrokClient: OpenAICompatibleClient, @unchecked Sendable {
    public convenience init(
        model: String = "grok-3-mini",
        apiKey: String? = nil
    ) {
        self.init(
            model: model,
            baseURL: "https://api.x.ai",
            path: "/v1/chat/completions",
            apiKey: apiKey
        )
    }
}
