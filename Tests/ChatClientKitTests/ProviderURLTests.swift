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
        let client = DeepSeekClient(apiKey: "sk-test")
        #expect(client.baseURL == "https://api.deepseek.com")
        #expect(client.path == "/chat/completions")
        #expect(client.apiKey == "sk-test")
    }

    @Test("MoonshotClient constructs correct URL")
    func moonshotURL() {
        let client = MoonshotClient(apiKey: "sk-test")
        #expect(client.baseURL == "https://api.moonshot.cn/v1")
        #expect(client.path == "/chat/completions")
    }

    @Test("GrokClient constructs correct URL")
    func grokURL() {
        let client = GrokClient(apiKey: "sk-test")
        #expect(client.baseURL == "https://api.x.ai")
        #expect(client.path == "/v1/chat/completions")
    }

    @Test("OpenRouterClient constructs correct URL and headers")
    func openrouterURL() {
        let client = OpenRouterClient(apiKey: "sk-or-test")
        #expect(client.baseURL == "https://openrouter.ai/api")
        #expect(client.path == "/v1/chat/completions")
        #expect(client.defaultHeaders["HTTP-Referer"] != nil)
    }

    @Test("AnthropicClient constructs correct URL and headers")
    func anthropicURL() throws {
        let client = AnthropicClient(apiKey: "sk-ant-test")
        #expect(client.baseURL == "https://api.anthropic.com")
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
}
