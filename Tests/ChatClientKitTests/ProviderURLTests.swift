//
//  ProviderURLTests.swift
//  ChatClientKitTests
//

@testable import ChatClientKit
import Foundation
import Testing

struct ProviderURLTests {
    @Test("DeepSeekClient constructs correct URL")
    func deepseekURL() {
        let client = DeepSeekClient(model: "deepseek-reasoner", apiKey: "sk-test")
        #expect(client.baseURL == "https://api.deepseek.com")
        #expect(client.path == "/chat/completions")
        #expect(client.model == "deepseek-reasoner")
        #expect(client.apiKey == "sk-test")
    }

    @Test("MoonshotClient constructs correct URL")
    func moonshotURL() {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "sk-test")
        #expect(client.baseURL == "https://api.moonshot.cn/v1")
        #expect(client.path == "/chat/completions")
        #expect(client.model == "kimi-k2.5")
    }

    @Test("GrokClient constructs correct URL")
    func grokURL() {
        let client = GrokClient(model: "grok-3-mini", apiKey: "sk-test")
        #expect(client.baseURL == "https://api.x.ai")
        #expect(client.path == "/v1/chat/completions")
        #expect(client.model == "grok-3-mini")
    }

    @Test("OpenRouterClient constructs correct URL and headers")
    func openrouterURL() {
        let client = OpenRouterClient(model: "anthropic/claude-sonnet-4.6", apiKey: "sk-or-test")
        #expect(client.baseURL == "https://openrouter.ai/api")
        #expect(client.path == "/v1/chat/completions")
        #expect(client.model == "anthropic/claude-sonnet-4.6")
        #expect(client.defaultHeaders["HTTP-Referer"] != nil)
    }

    @Test("AnthropicClient constructs correct URL and headers")
    func anthropicURL() throws {
        let client = AnthropicClient(model: "claude-sonnet-4-20250514", apiKey: "sk-ant-test")
        #expect(client.baseURL == "https://api.anthropic.com")
        #expect(client.model == "claude-sonnet-4-20250514")
        #expect(client.apiVersion == "2023-06-01")

        let body = AnthropicRequestBody(
            model: "claude-sonnet-4-20250514",
            messages: [.init(role: "user", content: [.text("hi")])],
            maxTokens: 100,
            stream: true,
            system: nil,
            temperature: nil,
            thinking: nil,
            tools: nil
        )
        let request = try client.makeURLRequest(body: body)
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
        #expect(request.httpMethod == "POST")
    }

    @Test("DeepSeekClient default model is deepseek-reasoner")
    func deepseekDefaultModel() {
        let client = DeepSeekClient()
        #expect(client.model == "deepseek-reasoner")
    }

    @Test("MoonshotClient default model is kimi-k2.5")
    func moonshotDefaultModel() {
        let client = MoonshotClient()
        #expect(client.model == "kimi-k2.5")
    }

    @Test("GrokClient default model is grok-3-mini")
    func grokDefaultModel() {
        let client = GrokClient()
        #expect(client.model == "grok-3-mini")
    }
}
