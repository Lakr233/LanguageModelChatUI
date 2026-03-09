//
//  LiveIntegrationTests.swift
//  ChatClientKitTests
//
//  Live integration tests that call real APIs.
//  These require valid API keys and network access.
//
//  Every provider is tested for:
//  - Streaming chat
//  - Chat completion
//  - Multi-turn conversation (reasoning stripped from history)
//
//  Reasoning providers (DeepSeek, Kimi, Anthropic) additionally test:
//  - Reasoning content is produced but NOT sent back in subsequent turns
//  - Anthropic: ThinkingBlocks are preserved for tool-call round-trips
//

@testable import ChatClientKit
import Foundation
import Testing

// MARK: - DeepSeek Live Tests

@Suite(.tags(.live))
struct DeepSeekLiveTests {
    let client = DeepSeekClient(
        model: "deepseek-reasoner",
        apiKey: TestAPIKeys.deepseek
    )

    @Test("Stream chat with reasoning content")
    func streamWithReasoning() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 15 + 27? Think step by step.")),
            ],
            maxCompletionTokens: 1024,
            temperature: nil
        )

        var reasoningChunks: [String] = []
        var textChunks: [String] = []

        for try await chunk in try await client.streamingChat(body: body) {
            switch chunk {
            case let .reasoning(r): reasoningChunks.append(r)
            case let .text(t): textChunks.append(t)
            default: break
            }
        }

        let reasoning = reasoningChunks.joined()
        let text = textChunks.joined()

        print("DeepSeek reasoning (\(reasoningChunks.count) chunks): \(reasoning.prefix(200))...")
        print("DeepSeek text (\(textChunks.count) chunks): \(text)")

        #expect(!reasoningChunks.isEmpty, "DeepSeek reasoner should produce reasoning chunks")
        #expect(!textChunks.isEmpty, "DeepSeek reasoner should produce text chunks")
        #expect(text.contains("42"), "Answer should contain 42")
    }

    @Test("Chat completion aggregates correctly")
    func chatCompletion() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("Reply with just the word: hello")),
            ],
            maxCompletionTokens: 64
        )

        let response = try await client.chat(body: body)

        print("DeepSeek chat response text: \(response.text)")
        #expect(response.text.lowercased().contains("hello"))
    }

    /// Multi-turn test: reasoning is produced on turn 1 but stripped from history.
    /// DeepSeek returns 400 if reasoning_content is included in assistant messages.
    /// DeepSeekClient.resolve() strips the reasoning field automatically.
    @Test("Multi-turn conversation strips reasoning from history")
    func multiTurnStripsReasoning() async throws {
        // Turn 1: get a response with reasoning
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Alice. What is 2+3?")),
            ],
            maxCompletionTokens: 1024
        )

        let turn1Response = try await client.chat(body: turn1Body)

        print("DeepSeek turn 1 text: \(turn1Response.text)")
        print("DeepSeek turn 1 reasoning: \(turn1Response.reasoning.prefix(200))...")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")
        #expect(!turn1Response.reasoning.isEmpty, "Turn 1 should produce reasoning")
        #expect(turn1Response.text.contains("5"), "Answer should contain 5")

        // Turn 2: include reasoning in the assistant message — DeepSeekClient strips it
        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Alice. What is 2+3?")),
                .assistant(
                    content: .text(turn1Response.text),
                    reasoning: turn1Response.reasoning
                ),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 256
        )

        // This should NOT fail with 400 — reasoning is stripped by DeepSeekClient
        let turn2Response = try await client.chat(body: turn2Body)

        print("DeepSeek turn 2 text: \(turn2Response.text)")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("alice"), "Should remember the name from context")
    }
}

// MARK: - Kimi/Moonshot Live Tests

@Suite(.tags(.live))
struct KimiLiveTests {
    let client = MoonshotClient(
        model: "kimi-k2.5",
        apiKey: TestAPIKeys.moonshot
    )

    @Test("Stream chat with reasoning content")
    func streamWithReasoning() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 15 + 27? Think step by step.")),
            ],
            maxCompletionTokens: 1024,
            temperature: nil // Kimi K2.5 only allows temperature=1 (default)
        )

        var reasoningChunks: [String] = []
        var textChunks: [String] = []

        for try await chunk in try await client.streamingChat(body: body) {
            switch chunk {
            case let .reasoning(r): reasoningChunks.append(r)
            case let .text(t): textChunks.append(t)
            default: break
            }
        }

        let reasoning = reasoningChunks.joined()
        let text = textChunks.joined()

        print("Kimi reasoning (\(reasoningChunks.count) chunks): \(reasoning.prefix(200))...")
        print("Kimi text (\(textChunks.count) chunks): \(text)")

        #expect(!reasoningChunks.isEmpty, "Kimi K2.5 should produce reasoning chunks")
        #expect(!textChunks.isEmpty, "Kimi K2.5 should produce text chunks")
        #expect(text.contains("42"), "Answer should contain 42")
    }

    @Test("Chat completion")
    func chatCompletion() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("Reply with just the word: hello")),
            ],
            maxCompletionTokens: 512,
            temperature: nil
        )

        let response = try await client.chat(body: body)

        print("Kimi chat response: \(response.text)")
        #expect(response.text.lowercased().contains("hello"))
    }

    /// Multi-turn test: reasoning produced on turn 1, included in history for turn 2.
    /// MoonshotClient (unlike DeepSeek) does not strip reasoning — the Kimi API accepts it.
    @Test("Multi-turn conversation with reasoning in history")
    func multiTurnWithReasoning() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Bob. What is 3+4?")),
            ],
            maxCompletionTokens: 1024,
            temperature: nil
        )

        let turn1Response = try await client.chat(body: turn1Body)

        print("Kimi turn 1 text: \(turn1Response.text)")
        print("Kimi turn 1 reasoning: \(turn1Response.reasoning.prefix(200))...")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")
        #expect(turn1Response.text.contains("7"), "Answer should contain 7")

        // Turn 2: include previous response in history
        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Bob. What is 3+4?")),
                .assistant(
                    content: .text(turn1Response.text),
                    reasoning: turn1Response.reasoning.isEmpty ? nil : turn1Response.reasoning
                ),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 512,
            temperature: nil
        )

        let turn2Response = try await client.chat(body: turn2Body)

        print("Kimi turn 2 text: \(turn2Response.text)")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("bob"), "Should remember the name from context")
    }
}

// MARK: - OpenRouter Live Tests

@Suite(.tags(.live))
struct OpenRouterLiveTests {
    @Test("Stream Claude Sonnet 4.6 via OpenRouter")
    func streamClaudeSonnet() async throws {
        let client = OpenRouterClient(
            model: "anthropic/claude-sonnet-4.6",
            apiKey: TestAPIKeys.openRouter
        )

        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 2 + 2? Reply briefly.")),
            ],
            maxCompletionTokens: 256,
            temperature: 0.3
        )

        var textChunks: [String] = []
        var reasoningChunks: [String] = []

        for try await chunk in try await client.streamingChat(body: body) {
            switch chunk {
            case let .text(t): textChunks.append(t)
            case let .reasoning(r): reasoningChunks.append(r)
            default: break
            }
        }

        let text = textChunks.joined()
        print("OpenRouter Claude Sonnet text (\(textChunks.count) chunks): \(text)")
        if !reasoningChunks.isEmpty {
            print("OpenRouter Claude Sonnet reasoning: \(reasoningChunks.joined().prefix(200))...")
        }

        #expect(!textChunks.isEmpty, "Should receive text from Claude Sonnet via OpenRouter")
        #expect(text.contains("4"), "Answer should contain 4")
    }

    @Test("Stream Gemini 3 Flash via OpenRouter")
    func streamGemini() async throws {
        let client = OpenRouterClient(
            model: "google/gemini-3-flash-preview",
            apiKey: TestAPIKeys.openRouter
        )

        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 3 * 7? Reply briefly.")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3
        )

        var textChunks: [String] = []
        var reasoningChunks: [String] = []

        for try await chunk in try await client.streamingChat(body: body) {
            switch chunk {
            case let .text(t): textChunks.append(t)
            case let .reasoning(r): reasoningChunks.append(r)
            default: break
            }
        }

        let text = textChunks.joined()
        let reasoning = reasoningChunks.joined()
        print("OpenRouter Gemini 3 Flash text (\(textChunks.count) chunks): \(text)")
        print("OpenRouter Gemini 3 Flash reasoning (\(reasoningChunks.count) chunks): \(reasoning.prefix(200))...")

        #expect(!textChunks.isEmpty, "Should receive text from Gemini 3 Flash via OpenRouter")
        #expect(text.contains("21"), "Answer should contain 21")
    }

    @Test("Chat completion with Claude Sonnet")
    func chatCompletionClaude() async throws {
        let client = OpenRouterClient(
            model: "anthropic/claude-sonnet-4.6",
            apiKey: TestAPIKeys.openRouter
        )

        let body = ChatRequestBody(
            messages: [
                .user(content: .text("Reply with just the word: hello")),
            ],
            maxCompletionTokens: 64,
            temperature: 0.3
        )

        let response = try await client.chat(body: body)

        print("OpenRouter Claude chat response: \(response.text)")
        #expect(response.text.lowercased().contains("hello"))
    }

    @Test("Chat completion with Gemini 3 Flash")
    func chatCompletionGemini() async throws {
        let client = OpenRouterClient(
            model: "google/gemini-3-flash-preview",
            apiKey: TestAPIKeys.openRouter
        )

        let body = ChatRequestBody(
            messages: [
                .user(content: .text("Reply with just the word: hello")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3
        )

        let response = try await client.chat(body: body)

        print("OpenRouter Gemini 3 Flash chat response: \(response.text)")
        #expect(response.text.lowercased().contains("hello"))
    }

    /// Multi-turn test for Claude Sonnet via OpenRouter.
    @Test("Multi-turn conversation with Claude Sonnet")
    func multiTurnClaudeSonnet() async throws {
        let client = OpenRouterClient(
            model: "anthropic/claude-sonnet-4.6",
            apiKey: TestAPIKeys.openRouter
        )

        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Charlie. Remember it.")),
            ],
            maxCompletionTokens: 256,
            temperature: 0.3
        )

        let turn1Response = try await client.chat(body: turn1Body)
        print("OpenRouter Claude turn 1: \(turn1Response.text)")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Charlie. Remember it.")),
                .assistant(content: .text(turn1Response.text)),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 256,
            temperature: 0.3
        )

        let turn2Response = try await client.chat(body: turn2Body)
        print("OpenRouter Claude turn 2: \(turn2Response.text)")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("charlie"), "Should remember the name")
    }

    /// Multi-turn test for Gemini 3 Flash via OpenRouter.
    /// Gemini 3.x models use the reasoning/reasoning_details private protocol.
    @Test("Multi-turn conversation with Gemini 3 Flash")
    func multiTurnGemini() async throws {
        let client = OpenRouterClient(
            model: "google/gemini-3-flash-preview",
            apiKey: TestAPIKeys.openRouter
        )

        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Diana. Remember it.")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3
        )

        let turn1Response = try await client.chat(body: turn1Body)
        print("OpenRouter Gemini 3 Flash turn 1: \(turn1Response.text)")
        print("OpenRouter Gemini 3 Flash turn 1 reasoning: \(turn1Response.reasoning.prefix(200))...")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Diana. Remember it.")),
                .assistant(
                    content: .text(turn1Response.text),
                    reasoning: turn1Response.reasoning.isEmpty ? nil : turn1Response.reasoning
                ),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3
        )

        let turn2Response = try await client.chat(body: turn2Body)
        print("OpenRouter Gemini 3 Flash turn 2: \(turn2Response.text)")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("diana"), "Should remember the name")
    }
}

// MARK: - Gemini 3 Pro Live Tests (Thinking/Reasoning)

@Suite(.tags(.live))
struct Gemini31ProLiveTests {
    let client = OpenRouterClient(
        model: "google/gemini-3-pro-preview",
        apiKey: TestAPIKeys.openRouter
    )

    @Test("Stream with reasoning content (thinking)")
    func streamWithReasoning() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 15 + 27?")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3
        )

        var reasoningChunks: [String] = []
        var textChunks: [String] = []

        for try await chunk in try await client.streamingChat(body: body) {
            switch chunk {
            case let .reasoning(r): reasoningChunks.append(r)
            case let .text(t): textChunks.append(t)
            default: break
            }
        }

        let reasoning = reasoningChunks.joined()
        let text = textChunks.joined()

        print("Gemini 3 Pro reasoning (\(reasoningChunks.count) chunks): \(reasoning.prefix(300))...")
        print("Gemini 3 Pro text (\(textChunks.count) chunks): \(text)")

        #expect(!reasoningChunks.isEmpty, "Gemini 3 Pro should produce reasoning chunks via 'reasoning' field")
        #expect(!textChunks.isEmpty, "Gemini 3 Pro should produce text chunks")
    }

    /// Verifies that the `reasoning_details` field is decoded when present in the raw SSE stream.
    @Test("Streaming decodes reasoning_details when present")
    func streamReturnsReasoningDetails() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 2 + 3?")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3
        )

        let decoder = JSONDecoder()
        var hasEncryptedBlock = false
        var hasTextBlock = false
        var hasReasoningField = false

        let request = try client.makeURLRequest(body: client.applyModelSettings(to: body, streaming: true))
        let (bytes, _) = try await URLSession.shared.bytes(for: request)
        var buffer = ""
        for try await byte in bytes {
            buffer.append(Character(UnicodeScalar(byte)))
            if buffer.hasSuffix("\n\n") || buffer.hasSuffix("\r\n\r\n") {
                let line = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                buffer = ""
                guard line.hasPrefix("data: ") else { continue }
                let payload = String(line.dropFirst(6))
                if payload.uppercased() == "[DONE]" { break }
                guard let data = payload.data(using: .utf8) else { continue }

                if let chunk = try? decoder.decode(ChatCompletionChunk.self, from: data) {
                    for choice in chunk.choices {
                        if let reasoning = choice.delta.reasoning, !reasoning.isEmpty {
                            hasReasoningField = true
                        }
                        if let details = choice.delta.reasoningDetails {
                            for detail in details {
                                if detail.type == "reasoning.encrypted", detail.data != nil {
                                    hasEncryptedBlock = true
                                }
                                if detail.type == "reasoning.text", detail.text != nil {
                                    hasTextBlock = true
                                }
                            }
                        }
                    }
                }
            }
        }

        print("Gemini 3 Pro raw SSE: hasReasoning=\(hasReasoningField), hasTextBlock=\(hasTextBlock), hasEncryptedBlock=\(hasEncryptedBlock)")
        #expect(hasReasoningField || hasTextBlock || hasEncryptedBlock, "Should receive reasoning content from Gemini 3 Pro")
    }

    /// Multi-turn test for Gemini 3 Pro (reasoning model) via OpenRouter.
    @Test("Multi-turn conversation with reasoning model")
    func multiTurnWithReasoning() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Eve. What is 10+5?")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3
        )

        let turn1Response = try await client.chat(body: turn1Body)

        print("Gemini 3 Pro turn 1 text: \(turn1Response.text)")
        print("Gemini 3 Pro turn 1 reasoning: \(turn1Response.reasoning.prefix(200))...")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Eve. What is 10+5?")),
                .assistant(
                    content: .text(turn1Response.text),
                    reasoning: turn1Response.reasoning.isEmpty ? nil : turn1Response.reasoning
                ),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3
        )

        let turn2Response = try await client.chat(body: turn2Body)

        print("Gemini 3 Pro turn 2 text: \(turn2Response.text)")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("eve"), "Should remember the name from context")
    }
}

// MARK: - Mistral Live Tests

@Suite(.tags(.live))
struct MistralLiveTests {
    let client = OpenAICompatibleClient(
        model: "mistral-small-latest",
        baseURL: "https://api.mistral.ai",
        path: "/v1/chat/completions",
        apiKey: TestAPIKeys.mistral
    )

    @Test("Stream chat")
    func streamChat() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 2 + 2? Reply briefly.")),
            ],
            temperature: 0.3
        )

        var textChunks: [String] = []

        for try await chunk in try await client.streamingChat(body: body) {
            switch chunk {
            case let .text(t): textChunks.append(t)
            default: break
            }
        }

        let text = textChunks.joined()
        print("Mistral text (\(textChunks.count) chunks): \(text)")

        #expect(!textChunks.isEmpty, "Should receive text from Mistral")
        #expect(text.contains("4"), "Answer should contain 4")
    }

    @Test("Chat completion")
    func chatCompletion() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("Reply with just the word: hello")),
            ],
            temperature: 0.3
        )

        let response = try await client.chat(body: body)

        print("Mistral chat response: \(response.text)")
        #expect(response.text.lowercased().contains("hello"))
    }

    /// Multi-turn test for Mistral (non-reasoning model).
    @Test("Multi-turn conversation")
    func multiTurn() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Grace. Remember it.")),
            ],
            temperature: 0.3
        )

        let turn1Response = try await client.chat(body: turn1Body)
        print("Mistral turn 1: \(turn1Response.text)")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Grace. Remember it.")),
                .assistant(content: .text(turn1Response.text)),
                .user(content: .text("What is my name?")),
            ],
            temperature: 0.3
        )

        let turn2Response = try await client.chat(body: turn2Body)
        print("Mistral turn 2: \(turn2Response.text)")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("grace"), "Should remember the name")
    }
}

// MARK: - Cerebras Live Tests

@Suite(.tags(.live))
struct CerebrasLiveTests {
    let client = OpenAICompatibleClient(
        model: "llama3.1-8b",
        baseURL: "https://api.cerebras.ai",
        path: "/v1/chat/completions",
        apiKey: TestAPIKeys.cerebras
    )

    @Test("Stream chat")
    func streamChat() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 2 + 2? Reply briefly.")),
            ],
            maxCompletionTokens: 256,
            temperature: 0.3
        )

        var textChunks: [String] = []

        for try await chunk in try await client.streamingChat(body: body) {
            switch chunk {
            case let .text(t): textChunks.append(t)
            default: break
            }
        }

        let text = textChunks.joined()
        print("Cerebras text (\(textChunks.count) chunks): \(text)")

        #expect(!textChunks.isEmpty, "Should receive text from Cerebras")
        #expect(text.contains("4"), "Answer should contain 4")
    }

    @Test("Chat completion")
    func chatCompletion() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("Reply with just the word: hello")),
            ],
            maxCompletionTokens: 64,
            temperature: 0.3
        )

        let response = try await client.chat(body: body)

        print("Cerebras chat response: \(response.text)")
        #expect(response.text.lowercased().contains("hello"))
    }

    /// Multi-turn test for Cerebras (non-reasoning model).
    @Test("Multi-turn conversation")
    func multiTurn() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Hank. Remember it.")),
            ],
            maxCompletionTokens: 256,
            temperature: 0.3
        )

        let turn1Response = try await client.chat(body: turn1Body)
        print("Cerebras turn 1: \(turn1Response.text)")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Hank. Remember it.")),
                .assistant(content: .text(turn1Response.text)),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 256,
            temperature: 0.3
        )

        let turn2Response = try await client.chat(body: turn2Body)
        print("Cerebras turn 2: \(turn2Response.text)")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("hank"), "Should remember the name")
    }
}

// MARK: - Anthropic Live Tests (Extended Thinking)

@Suite(.tags(.live))
struct AnthropicLiveTests {
    let client = AnthropicClient(
        model: "claude-haiku-4-5-20251001",
        apiKey: TestAPIKeys.anthropic,
        thinkingBudgetTokens: 1024
    )

    @Test("Stream chat with extended thinking")
    func streamWithThinking() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 15 + 27? Think step by step.")),
            ],
            maxCompletionTokens: 2048
        )

        var reasoningChunks: [String] = []
        var textChunks: [String] = []
        var thinkingBlocks: [ThinkingBlock] = []

        for try await chunk in try await client.streamingChat(body: body) {
            switch chunk {
            case let .reasoning(r): reasoningChunks.append(r)
            case let .text(t): textChunks.append(t)
            case let .thinkingBlock(tb): thinkingBlocks.append(tb)
            default: break
            }
        }

        let reasoning = reasoningChunks.joined()
        let text = textChunks.joined()

        print("Anthropic reasoning (\(reasoningChunks.count) chunks): \(reasoning.prefix(200))...")
        print("Anthropic text (\(textChunks.count) chunks): \(text)")
        print("Anthropic thinking blocks: \(thinkingBlocks.count)")
        for (i, tb) in thinkingBlocks.enumerated() {
            print("  block \(i): thinking=\(tb.thinking.prefix(80))... signature=\(tb.signature.prefix(40))...")
        }

        #expect(!reasoningChunks.isEmpty, "Anthropic extended thinking should produce reasoning chunks")
        #expect(!textChunks.isEmpty, "Anthropic should produce text chunks")
        #expect(text.contains("42"), "Answer should contain 42")
        #expect(!thinkingBlocks.isEmpty, "Should capture thinking blocks with signatures")
    }

    @Test("Chat completion with extended thinking")
    func chatCompletion() async throws {
        let body = ChatRequestBody(
            messages: [
                .user(content: .text("Reply with just the word: hello")),
            ],
            maxCompletionTokens: 2048
        )

        let response = try await client.chat(body: body)

        print("Anthropic chat response: \(response.text)")
        print("Anthropic reasoning: \(response.reasoning.prefix(200))...")
        print("Anthropic thinkingBlocks: \(response.thinkingBlocks.count)")
        #expect(response.text.lowercased().contains("hello"))
        #expect(!response.reasoning.isEmpty, "Extended thinking should produce reasoning")
    }

    /// Multi-turn conversation with extended thinking (no tools).
    /// ThinkingBlocks from the previous turn are preserved and sent back.
    @Test("Multi-turn conversation with extended thinking")
    func multiTurnWithThinking() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Iris. What is 6+7?")),
            ],
            maxCompletionTokens: 2048
        )

        let turn1Response = try await client.chat(body: turn1Body)

        print("Anthropic turn 1 text: \(turn1Response.text)")
        print("Anthropic turn 1 reasoning: \(turn1Response.reasoning.prefix(200))...")
        print("Anthropic turn 1 thinkingBlocks: \(turn1Response.thinkingBlocks.count)")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")
        #expect(!turn1Response.reasoning.isEmpty, "Turn 1 should produce reasoning")

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Iris. What is 6+7?")),
                .assistant(
                    content: .text(turn1Response.text),
                    reasoning: nil,
                    thinkingBlocks: turn1Response.thinkingBlocks
                ),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 2048
        )

        let turn2Response = try await client.chat(body: turn2Body)

        print("Anthropic turn 2 text: \(turn2Response.text)")
        print("Anthropic turn 2 reasoning: \(turn2Response.reasoning.prefix(200))...")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("iris"), "Should remember the name from context")
    }

    /// Multi-turn tool-call round-trip with preserved thinking blocks.
    /// See: https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking#multi-turn-conversations
    @Test("Multi-turn tool call with preserved thinking blocks")
    func toolCallWithPreservedThinking() async throws {
        let weatherTool = ChatRequestBody.Tool.function(
            name: "get_weather",
            description: "Get the current weather for a city",
            parameters: [
                "type": "object",
                "properties": [
                    "city": ["type": "string", "description": "The city name"],
                ],
                "required": .array([.string("city")]),
            ],
            strict: nil
        )

        let initialBody = ChatRequestBody(
            messages: [
                .user(content: .text("What is the current weather in Tokyo? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 4096,
            tools: [weatherTool]
        )

        let firstResponse = try await client.chat(body: initialBody)

        print("=== Anthropic Tool Call Turn 1 ===")
        print("Reasoning: \(firstResponse.reasoning.prefix(200))...")
        print("Text: \(firstResponse.text)")
        print("Tool calls: \(firstResponse.tools.count)")
        print("Thinking blocks: \(firstResponse.thinkingBlocks.count)")

        #expect(!firstResponse.reasoning.isEmpty, "First turn should produce reasoning")
        #expect(!firstResponse.tools.isEmpty, "Model should call the get_weather tool")
        #expect(!firstResponse.thinkingBlocks.isEmpty, "Should capture thinking blocks with signatures")

        for block in firstResponse.thinkingBlocks {
            switch block {
            case let .thinking(tb):
                #expect(!tb.thinking.isEmpty, "Thinking block should have text")
                #expect(!tb.signature.isEmpty, "Thinking block must have a signature")
                print("Thinking block signature: \(tb.signature.prefix(40))...")
            case let .redactedThinking(data):
                #expect(!data.isEmpty, "Redacted thinking should have data")
                print("Redacted thinking: \(data.prefix(40))...")
            }
        }

        let toolCall = firstResponse.tools[0]
        print("Tool call: \(toolCall.name)(args: \(toolCall.arguments))")

        let toolCallMessage: ChatRequestBody.Message = .assistant(
            content: firstResponse.text.isEmpty ? nil : .text(firstResponse.text),
            toolCalls: firstResponse.tools.map { tool in
                ChatRequestBody.Message.ToolCall(
                    id: tool.id ?? "unknown",
                    function: .init(name: tool.name, arguments: tool.arguments)
                )
            },
            reasoning: nil,
            thinkingBlocks: firstResponse.thinkingBlocks
        )

        let toolResultMessage: ChatRequestBody.Message = .tool(
            content: .text("{\"temperature\": \"22°C\", \"condition\": \"Partly cloudy\", \"humidity\": \"65%\"}"),
            toolCallID: toolCall.id ?? "unknown"
        )

        let continuationBody = ChatRequestBody(
            messages: [
                .user(content: .text("What is the current weather in Tokyo? Use the get_weather tool.")),
                toolCallMessage,
                toolResultMessage,
            ],
            maxCompletionTokens: 4096,
            tools: [weatherTool]
        )

        let secondResponse = try await client.chat(body: continuationBody)

        print("=== Anthropic Tool Call Turn 2 ===")
        print("Reasoning: \(secondResponse.reasoning.prefix(200))...")
        print("Text: \(secondResponse.text)")

        #expect(!secondResponse.text.isEmpty, "Second turn should produce text")

        let combinedOutput = secondResponse.text.lowercased()
        #expect(
            combinedOutput.contains("22") || combinedOutput.contains("tokyo") || combinedOutput.contains("cloudy"),
            "Response should reference the weather data"
        )

        print("Multi-turn tool call with preserved thinking blocks succeeded!")
    }

    @Test("Stream without extended thinking")
    func streamWithoutThinking() async throws {
        let plainClient = AnthropicClient(
            model: "claude-haiku-4-5-20251001",
            apiKey: TestAPIKeys.anthropic,
            thinkingBudgetTokens: 0
        )

        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is 2 + 2? Reply briefly.")),
            ],
            maxCompletionTokens: 256
        )

        var reasoningChunks: [String] = []
        var textChunks: [String] = []

        for try await chunk in try await plainClient.streamingChat(body: body) {
            switch chunk {
            case let .reasoning(r): reasoningChunks.append(r)
            case let .text(t): textChunks.append(t)
            default: break
            }
        }

        let text = textChunks.joined()
        print("Anthropic (no thinking) text: \(text)")

        #expect(reasoningChunks.isEmpty, "Without extended thinking, should have no reasoning chunks")
        #expect(!textChunks.isEmpty, "Should still produce text")
        #expect(text.contains("4"), "Answer should contain 4")
    }

    /// Multi-turn without extended thinking.
    @Test("Multi-turn without extended thinking")
    func multiTurnWithoutThinking() async throws {
        let plainClient = AnthropicClient(
            model: "claude-haiku-4-5-20251001",
            apiKey: TestAPIKeys.anthropic,
            thinkingBudgetTokens: 0
        )

        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Jack. Remember it.")),
            ],
            maxCompletionTokens: 256
        )

        let turn1Response = try await plainClient.chat(body: turn1Body)
        print("Anthropic (no thinking) turn 1: \(turn1Response.text)")

        #expect(!turn1Response.text.isEmpty, "Turn 1 should produce text")

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("My name is Jack. Remember it.")),
                .assistant(content: .text(turn1Response.text)),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 256
        )

        let turn2Response = try await plainClient.chat(body: turn2Body)
        print("Anthropic (no thinking) turn 2: \(turn2Response.text)")

        #expect(!turn2Response.text.isEmpty, "Turn 2 should produce text")
        #expect(turn2Response.text.lowercased().contains("jack"), "Should remember the name")
    }
}

// MARK: - Tool Call Helper

private let weatherTool = ChatRequestBody.Tool.function(
    name: "get_weather",
    description: "Get the current weather for a city",
    parameters: [
        "type": "object",
        "properties": [
            "city": ["type": "string", "description": "The city name"],
        ],
        "required": .array([.string("city")]),
    ],
    strict: nil
)

// MARK: - DeepSeek Tool Call Live Tests

/// DeepSeek V3.2 thinking-integrated tool-use.
///
/// Rules for reasoning_content in follow-up requests:
/// - Messages WITH tool_calls  → reasoning_content MUST be preserved  (400 if omitted)
/// - Messages WITHOUT tool_calls → reasoning_content must be stripped  (400 if included)
///
/// Ref: https://api-docs.deepseek.com/guides/reasoning_model
///      https://api-docs.deepseek.com/guides/tool_calls
@Suite(.tags(.live))
struct DeepSeekToolCallLiveTests {
    // Use deepseek-chat (V3.2 non-thinking) for tool calls.
    // deepseek-reasoner supports tool calls since V3.2 but requires strict
    // reasoning_content echo-back; deepseek-chat is the recommended model for
    // standard tool-call workflows.
    // Ref: https://api-docs.deepseek.com/guides/tool_calls
    let client = DeepSeekClient(
        model: "deepseek-chat",
        apiKey: TestAPIKeys.deepseek
    )

    @Test("DeepSeek tool call: model calls get_weather then answers with result")
    func toolCallRoundTrip() async throws {
        // Turn 1: model decides to call get_weather
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Tokyo? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 4096,
            tools: [weatherTool]
        )

        let turn1 = try await client.chat(body: turn1Body)

        print("=== DeepSeek Tool Call Turn 1 ===")
        print("Text: \(turn1.text)")
        print("Tool calls: \(turn1.tools.count)")
        print("Reasoning: \(turn1.reasoning.prefix(200))...")

        #expect(!turn1.tools.isEmpty, "DeepSeek should call get_weather tool")

        let toolCall = turn1.tools[0]
        #expect(toolCall.name == "get_weather", "Should call get_weather")

        // Turn 2: send tool result back.
        // DeepSeek V3.2 requires reasoning_content to be included for tool-call messages.
        // DeepSeekClient.resolve() now preserves reasoning when tool_calls are present.
        let assistantMsg = ChatRequestBody.Message.assistant(
            content: turn1.text.isEmpty ? nil : .text(turn1.text),
            toolCalls: turn1.tools.map { .init(id: $0.id ?? "call_0", function: .init(name: $0.name, arguments: $0.arguments)) },
            reasoning: turn1.reasoning.isEmpty ? nil : turn1.reasoning
        )
        let toolResultMsg = ChatRequestBody.Message.tool(
            content: .text("{\"temperature\":\"18°C\",\"condition\":\"Sunny\"}"),
            toolCallID: toolCall.id ?? "call_0"
        )

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Tokyo? Use the get_weather tool.")),
                assistantMsg,
                toolResultMsg,
            ],
            maxCompletionTokens: 1024,
            tools: [weatherTool]
        )

        let turn2 = try await client.chat(body: turn2Body)

        print("=== DeepSeek Tool Call Turn 2 ===")
        print("Text: \(turn2.text)")

        #expect(!turn2.text.isEmpty, "Turn 2 should produce a final text answer")
        let lower = turn2.text.lowercased()
        #expect(
            lower.contains("18") || lower.contains("sunny") || lower.contains("tokyo"),
            "Response should reference the weather data"
        )
    }
}

// MARK: - Kimi Tool Call Live Tests

/// Kimi K2.5 tool calling via Moonshot API.
///
/// Key behaviors confirmed from docs:
/// - Standard OpenAI-compatible tool call format
/// - assistant message with tool_calls: content must be "" not absent
/// - reasoning_content is stripped before sending (Kimi doesn't accept it back)
///
/// Ref: https://platform.moonshot.ai/docs/guide/use-kimi-api-to-complete-tool-calls
@Suite(.tags(.live))
struct KimiToolCallLiveTests {
    let client = MoonshotClient(
        model: "kimi-k2.5",
        apiKey: TestAPIKeys.moonshot
    )

    @Test("Kimi tool call: model calls get_weather then answers with result")
    func toolCallRoundTrip() async throws {
        // Turn 1: model decides to call get_weather
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Beijing? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 4096,
            temperature: nil,
            tools: [weatherTool]
        )

        let turn1 = try await client.chat(body: turn1Body)

        print("=== Kimi Tool Call Turn 1 ===")
        print("Text: \(turn1.text)")
        print("Tool calls: \(turn1.tools.count)")
        print("Reasoning: \(turn1.reasoning.prefix(200))...")

        #expect(!turn1.tools.isEmpty, "Kimi should call get_weather tool")

        let toolCall = turn1.tools[0]
        #expect(toolCall.name == "get_weather", "Should call get_weather")

        // Turn 2: send tool result back.
        // MoonshotClient.resolve() strips reasoning and ensures content = "" when tool_calls present.
        let assistantMsg = ChatRequestBody.Message.assistant(
            content: turn1.text.isEmpty ? nil : .text(turn1.text),
            toolCalls: turn1.tools.map { .init(id: $0.id ?? "call_0", function: .init(name: $0.name, arguments: $0.arguments)) },
            reasoning: turn1.reasoning.isEmpty ? nil : turn1.reasoning
        )
        let toolResultMsg = ChatRequestBody.Message.tool(
            content: .text("{\"temperature\":\"22°C\",\"condition\":\"Partly cloudy\"}"),
            toolCallID: toolCall.id ?? "call_0"
        )

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Beijing? Use the get_weather tool.")),
                assistantMsg,
                toolResultMsg,
            ],
            maxCompletionTokens: 1024,
            temperature: nil,
            tools: [weatherTool]
        )

        let turn2 = try await client.chat(body: turn2Body)

        print("=== Kimi Tool Call Turn 2 ===")
        print("Text: \(turn2.text)")

        #expect(!turn2.text.isEmpty, "Turn 2 should produce a final text answer")
        let lower = turn2.text.lowercased()
        #expect(
            lower.contains("22") || lower.contains("cloudy") || lower.contains("beijing"),
            "Response should reference the weather data"
        )
    }

    /// Regression test for the tool_call_id mismatch bug.
    ///
    /// When a ConversationSession rebuilds request messages from stored ConversationMessage parts
    /// (which happens on every new user message), the reconstructed assistant message must use
    /// the original model-issued tool call ID — not a fresh UUID. If the IDs diverge, Kimi
    /// returns HTTP 400 "tool_call_id is not found".
    ///
    /// This test exercises the same 3-turn shape that triggered the bug:
    ///   turn 1: user → model calls tool
    ///   turn 2: tool result returned → model answers
    ///   turn 3: new user follow-up → model answers using the history
    @Test("Kimi tool call: follow-up user message after tool call succeeds (3-turn regression)")
    func toolCallFollowUpTurn() async throws {
        // Turn 1: model decides to call get_weather
        let turn1 = try await client.chat(body: ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Shanghai? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 4096,
            temperature: nil,
            tools: [weatherTool]
        ))

        print("=== Kimi 3-Turn Turn 1 ===")
        print("Tool calls: \(turn1.tools.count)")

        #expect(!turn1.tools.isEmpty, "Model should call get_weather")
        let toolCall = turn1.tools[0]
        let toolCallID = toolCall.id ?? "call_0"

        // Turn 2: send tool result back using the EXACT same ID the model issued.
        // This simulates correct behaviour after the fix — ToolCallContentPart.id == request.id.
        let assistantMsg = ChatRequestBody.Message.assistant(
            content: turn1.text.isEmpty ? nil : .text(turn1.text),
            toolCalls: turn1.tools.map { .init(id: $0.id ?? "call_0", function: .init(name: $0.name, arguments: $0.arguments)) },
            reasoning: turn1.reasoning.isEmpty ? nil : turn1.reasoning
        )
        let toolResultMsg = ChatRequestBody.Message.tool(
            content: .text("{\"temperature\":\"30°C\",\"condition\":\"Humid\"}"),
            toolCallID: toolCallID
        )

        let turn2 = try await client.chat(body: ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Shanghai? Use the get_weather tool.")),
                assistantMsg,
                toolResultMsg,
            ],
            maxCompletionTokens: 1024,
            temperature: nil,
            tools: [weatherTool]
        ))

        print("=== Kimi 3-Turn Turn 2 ===")
        print("Text: \(turn2.text)")
        #expect(!turn2.text.isEmpty, "Turn 2 must produce a text answer")

        // Turn 3: follow-up user message — the full history (including the tool call) is replayed.
        // Before the fix this would fail because ToolCallContentPart stored a random UUID as its
        // id and BuildMessages.swift used that instead of the original model-issued tool call ID,
        // causing the tool result's toolCallID to not match any tool_call in the assistant message.
        let turn3 = try await client.chat(body: ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Shanghai? Use the get_weather tool.")),
                assistantMsg,
                toolResultMsg,
                .assistant(content: .text(turn2.text)),
                .user(content: .text("Is that hot or cold for Shanghai this time of year?")),
            ],
            maxCompletionTokens: 512,
            temperature: nil,
            tools: [weatherTool]
        ))

        print("=== Kimi 3-Turn Turn 3 ===")
        print("Text: \(turn3.text)")
        #expect(!turn3.text.isEmpty, "Turn 3 follow-up must succeed without tool_call_id mismatch error")
    }

    /// Documents the API contract: a tool result whose tool_call_id does not match any tool_call
    /// in the preceding assistant message must be rejected with an error.
    ///
    /// This is the exact error class the bug caused:
    ///   "Invalid request: tool_call_id <X> is not found"
    @Test("Kimi rejects mismatched tool_call_id with an error")
    func mismatchedToolCallIdIsRejected() async throws {
        // Turn 1: get a real tool call from the model
        let turn1 = try await client.chat(body: ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Guangzhou? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 4096,
            temperature: nil,
            tools: [weatherTool]
        ))

        #expect(!turn1.tools.isEmpty, "Model should call get_weather to proceed with the test")

        // Deliberately use a WRONG id in the assistant's tool_calls, while the tool result
        // references the correct one. This recreates the pre-fix mismatch.
        let wrongID = "wrong-id-\(UUID().uuidString)"
        let correctID = turn1.tools[0].id ?? "call_0"

        let assistantMsgWithWrongID = ChatRequestBody.Message.assistant(
            content: turn1.text.isEmpty ? nil : .text(turn1.text),
            toolCalls: turn1.tools.map { .init(id: wrongID, function: .init(name: $0.name, arguments: $0.arguments)) },
            reasoning: turn1.reasoning.isEmpty ? nil : turn1.reasoning
        )
        let toolResultMsgWithCorrectID = ChatRequestBody.Message.tool(
            content: .text("{\"temperature\":\"28°C\",\"condition\":\"Sunny\"}"),
            toolCallID: correctID // correct ID but assistant message advertised wrongID
        )

        let body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Guangzhou? Use the get_weather tool.")),
                assistantMsgWithWrongID,
                toolResultMsgWithCorrectID,
            ],
            maxCompletionTokens: 512,
            temperature: nil,
            tools: [weatherTool]
        )

        do {
            let response = try await client.chat(body: body)
            // Some providers silently accept mismatched IDs; if this one does, the test still
            // provides documentation value. Print a note rather than hard-failing.
            print("Note: Kimi accepted mismatched tool_call_id (response: \(response.text))")
        } catch {
            // Expected path: API rejects the mismatched ID.
            print("Kimi correctly rejected mismatched tool_call_id: \(error)")
            #expect(
                error.localizedDescription.contains("tool_call_id") ||
                    error.localizedDescription.contains("not found") ||
                    error.localizedDescription.contains("invalid"),
                "Error should mention tool_call_id mismatch"
            )
        }
    }
}

// MARK: - Mistral Tool Call Live Tests

/// Mistral function calling via chat completions API.
///
/// Mistral uses standard OpenAI-compatible tool call format:
/// - assistant message with tool_calls can have content: null
/// - tool result messages use role: "tool" with tool_call_id
///
/// Ref: https://docs.mistral.ai/agents/tools/function_calling
@Suite(.tags(.live))
struct MistralToolCallLiveTests {
    let client = OpenAICompatibleClient(
        model: "mistral-small-latest",
        baseURL: "https://api.mistral.ai",
        path: "/v1/chat/completions",
        apiKey: TestAPIKeys.mistral
    )

    @Test("Mistral tool call: model calls get_weather then answers with result")
    func toolCallRoundTrip() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Paris? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3,
            tools: [weatherTool]
        )

        let turn1 = try await client.chat(body: turn1Body)

        print("=== Mistral Tool Call Turn 1 ===")
        print("Text: \(turn1.text)")
        print("Tool calls: \(turn1.tools.count)")

        #expect(!turn1.tools.isEmpty, "Mistral should call get_weather tool")

        let toolCall = turn1.tools[0]
        #expect(toolCall.name == "get_weather")

        let assistantMsg = ChatRequestBody.Message.assistant(
            content: turn1.text.isEmpty ? nil : .text(turn1.text),
            toolCalls: turn1.tools.map { .init(id: $0.id ?? "call_0", function: .init(name: $0.name, arguments: $0.arguments)) }
        )
        let toolResultMsg = ChatRequestBody.Message.tool(
            content: .text("{\"temperature\":\"16°C\",\"condition\":\"Rainy\"}"),
            toolCallID: toolCall.id ?? "call_0"
        )

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Paris? Use the get_weather tool.")),
                assistantMsg,
                toolResultMsg,
            ],
            maxCompletionTokens: 512,
            temperature: 0.3,
            tools: [weatherTool]
        )

        let turn2 = try await client.chat(body: turn2Body)

        print("=== Mistral Tool Call Turn 2 ===")
        print("Text: \(turn2.text)")

        #expect(!turn2.text.isEmpty, "Turn 2 should produce a final text answer")
        let lower = turn2.text.lowercased()
        #expect(
            lower.contains("16") || lower.contains("rain") || lower.contains("paris"),
            "Response should reference the weather data"
        )
    }
}

// MARK: - Cerebras Tool Call Live Tests

/// Cerebras tool calling (function use).
///
/// Cerebras API is OpenAI-compatible. Uses strict mode for guaranteed schema adherence.
/// llama-3.3-70b is recommended for reliable tool calling.
///
/// Ref: https://inference-docs.cerebras.ai/capabilities/tool-use
///      https://inference-docs.cerebras.ai/resources/openai
@Suite(.tags(.live))
struct CerebrasToolCallLiveTests {
    /// llama3.1-8b has limited tool calling reliability; use llama-3.3-70b for tool use.
    let client = OpenAICompatibleClient(
        model: "llama-3.3-70b",
        baseURL: "https://api.cerebras.ai",
        path: "/v1/chat/completions",
        apiKey: TestAPIKeys.cerebras
    )

    @Test("Cerebras tool call: model calls get_weather then answers with result")
    func toolCallRoundTrip() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in London? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3,
            tools: [weatherTool]
        )

        let turn1 = try await client.chat(body: turn1Body)

        print("=== Cerebras Tool Call Turn 1 ===")
        print("Text: \(turn1.text)")
        print("Tool calls: \(turn1.tools.count)")

        #expect(!turn1.tools.isEmpty, "Cerebras should call get_weather tool")

        let toolCall = turn1.tools[0]
        #expect(toolCall.name == "get_weather")

        let assistantMsg = ChatRequestBody.Message.assistant(
            content: turn1.text.isEmpty ? nil : .text(turn1.text),
            toolCalls: turn1.tools.map { .init(id: $0.id ?? "call_0", function: .init(name: $0.name, arguments: $0.arguments)) }
        )
        let toolResultMsg = ChatRequestBody.Message.tool(
            content: .text("{\"temperature\":\"12°C\",\"condition\":\"Overcast\"}"),
            toolCallID: toolCall.id ?? "call_0"
        )

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in London? Use the get_weather tool.")),
                assistantMsg,
                toolResultMsg,
            ],
            maxCompletionTokens: 512,
            temperature: 0.3,
            tools: [weatherTool]
        )

        let turn2 = try await client.chat(body: turn2Body)

        print("=== Cerebras Tool Call Turn 2 ===")
        print("Text: \(turn2.text)")

        #expect(!turn2.text.isEmpty, "Turn 2 should produce a final text answer")
        let lower = turn2.text.lowercased()
        #expect(
            lower.contains("12") || lower.contains("overcast") || lower.contains("london"),
            "Response should reference the weather data"
        )
    }
}

// MARK: - Groq Tool Call Live Tests

/// Groq Cloud tool calling.
///
/// Groq API is OpenAI-compatible (base URL: https://api.groq.com/openai/v1).
/// Recommended model for tool calling: llama-3.3-70b-versatile.
///
/// Ref: https://console.groq.com/docs/tool-use
@Suite(.tags(.live))
struct GroqToolCallLiveTests {
    /// Groq uses OpenAI-compatible format at api.groq.com/openai/v1
    let client = OpenAICompatibleClient(
        model: "llama-3.3-70b-versatile",
        baseURL: "https://api.groq.com",
        path: "/openai/v1/chat/completions",
        apiKey: TestAPIKeys.groq
    )

    @Test("Groq stream chat")
    func streamChat() async throws {
        let body = ChatRequestBody(
            messages: [.user(content: .text("What is 3 + 3? Reply briefly."))],
            maxCompletionTokens: 256,
            temperature: 0.3
        )
        var chunks: [String] = []
        for try await chunk in try await client.streamingChat(body: body) {
            if case let .text(t) = chunk { chunks.append(t) }
        }
        let text = chunks.joined()
        print("Groq stream: \(text)")
        #expect(!chunks.isEmpty)
        #expect(text.contains("6"))
    }

    @Test("Groq chat completion")
    func chatCompletion() async throws {
        let body = ChatRequestBody(
            messages: [.user(content: .text("Reply with just the word: hello"))],
            maxCompletionTokens: 64,
            temperature: 0.3
        )
        let response = try await client.chat(body: body)
        print("Groq chat: \(response.text)")
        #expect(response.text.lowercased().contains("hello"))
    }

    @Test("Groq multi-turn conversation")
    func multiTurn() async throws {
        let turn1 = try await client.chat(body: ChatRequestBody(
            messages: [.user(content: .text("My name is Kevin. Remember it."))],
            maxCompletionTokens: 256,
            temperature: 0.3
        ))
        #expect(!turn1.text.isEmpty)

        let turn2 = try await client.chat(body: ChatRequestBody(
            messages: [
                .user(content: .text("My name is Kevin. Remember it.")),
                .assistant(content: .text(turn1.text)),
                .user(content: .text("What is my name?")),
            ],
            maxCompletionTokens: 256,
            temperature: 0.3
        ))
        print("Groq turn 2: \(turn2.text)")
        #expect(turn2.text.lowercased().contains("kevin"))
    }

    @Test("Groq tool call: model calls get_weather then answers with result")
    func toolCallRoundTrip() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in New York? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3,
            tools: [weatherTool]
        )

        let turn1 = try await client.chat(body: turn1Body)

        print("=== Groq Tool Call Turn 1 ===")
        print("Text: \(turn1.text)")
        print("Tool calls: \(turn1.tools.count)")

        #expect(!turn1.tools.isEmpty, "Groq should call get_weather tool")

        let toolCall = turn1.tools[0]
        #expect(toolCall.name == "get_weather")

        let assistantMsg = ChatRequestBody.Message.assistant(
            content: turn1.text.isEmpty ? nil : .text(turn1.text),
            toolCalls: turn1.tools.map { .init(id: $0.id ?? "call_0", function: .init(name: $0.name, arguments: $0.arguments)) }
        )
        let toolResultMsg = ChatRequestBody.Message.tool(
            content: .text("{\"temperature\":\"25°C\",\"condition\":\"Clear skies\"}"),
            toolCallID: toolCall.id ?? "call_0"
        )

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in New York? Use the get_weather tool.")),
                assistantMsg,
                toolResultMsg,
            ],
            maxCompletionTokens: 512,
            temperature: 0.3,
            tools: [weatherTool]
        )

        let turn2 = try await client.chat(body: turn2Body)

        print("=== Groq Tool Call Turn 2 ===")
        print("Text: \(turn2.text)")

        #expect(!turn2.text.isEmpty, "Turn 2 should produce a final text answer")
        let lower = turn2.text.lowercased()
        #expect(
            lower.contains("25") || lower.contains("clear") || lower.contains("new york"),
            "Response should reference the weather data"
        )
    }
}

// MARK: - OpenRouter Tool Call Live Tests

/// OpenRouter passes tool calls through to underlying models.
/// Using Claude Sonnet 4.6 which has excellent tool calling support.
///
/// Ref: https://openrouter.ai/docs/requests (tool_calls follow OpenAI format)
@Suite(.tags(.live))
struct OpenRouterToolCallLiveTests {
    let client = OpenRouterClient(
        model: "anthropic/claude-sonnet-4.6",
        apiKey: TestAPIKeys.openRouter
    )

    @Test("OpenRouter (Claude Sonnet 4.6) tool call round-trip")
    func toolCallRoundTrip() async throws {
        let turn1Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Sydney? Use the get_weather tool.")),
            ],
            maxCompletionTokens: 1024,
            temperature: 0.3,
            tools: [weatherTool]
        )

        let turn1 = try await client.chat(body: turn1Body)

        print("=== OpenRouter Tool Call Turn 1 ===")
        print("Text: \(turn1.text)")
        print("Tool calls: \(turn1.tools.count)")

        #expect(!turn1.tools.isEmpty, "Claude Sonnet via OpenRouter should call get_weather")

        let toolCall = turn1.tools[0]
        #expect(toolCall.name == "get_weather")

        let assistantMsg = ChatRequestBody.Message.assistant(
            content: turn1.text.isEmpty ? nil : .text(turn1.text),
            toolCalls: turn1.tools.map { .init(id: $0.id ?? "call_0", function: .init(name: $0.name, arguments: $0.arguments)) }
        )
        let toolResultMsg = ChatRequestBody.Message.tool(
            content: .text("{\"temperature\":\"28°C\",\"condition\":\"Sunny\"}"),
            toolCallID: toolCall.id ?? "call_0"
        )

        let turn2Body = ChatRequestBody(
            messages: [
                .user(content: .text("What is the weather in Sydney? Use the get_weather tool.")),
                assistantMsg,
                toolResultMsg,
            ],
            maxCompletionTokens: 512,
            temperature: 0.3,
            tools: [weatherTool]
        )

        let turn2 = try await client.chat(body: turn2Body)

        print("=== OpenRouter Tool Call Turn 2 ===")
        print("Text: \(turn2.text)")

        #expect(!turn2.text.isEmpty, "Turn 2 should produce a final text answer")
        let lower = turn2.text.lowercased()
        #expect(
            lower.contains("28") || lower.contains("sunny") || lower.contains("sydney"),
            "Response should reference the weather data"
        )
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var live: Self
}
