//
//  ChatCompletionChunkDecodingTests.swift
//  ChatClientKitTests
//

@testable import ChatClientKit
import Foundation
import Testing

struct ChatCompletionChunkDecodingTests {
    let jsonDecoder = JSONDecoder()

    @Test("Decodes standard content delta")
    func decodeContentDelta() throws {
        let json = """
        {
            "choices": [{
                "index": 0,
                "delta": {
                    "role": "assistant",
                    "content": "Hello!"
                }
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.choices.count == 1)
        #expect(chunk.choices[0].delta.content == "Hello!")
        #expect(chunk.choices[0].delta.role == "assistant")
        #expect(chunk.choices[0].index == 0)
    }

    @Test("Decodes reasoning_content field (DeepSeek/Kimi format)")
    func decodeReasoningContent() throws {
        let json = """
        {
            "choices": [{
                "index": 0,
                "delta": {
                    "reasoning_content": "Let me think step by step..."
                }
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.choices[0].delta.reasoningContent == "Let me think step by step...")
        #expect(chunk.choices[0].delta.content == nil)
    }

    @Test("Decodes reasoning field (Gemini via OpenRouter)")
    func decodeReasoning() throws {
        let json = """
        {
            "choices": [{
                "index": 0,
                "delta": {
                    "reasoning": "Let me think about this...",
                    "content": ""
                }
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.choices[0].delta.reasoning == "Let me think about this...")
        #expect(chunk.choices[0].delta.resolvedReasoning == "Let me think about this...")
    }

    @Test("resolvedReasoning prefers reasoningContent over reasoning")
    func resolvedReasoningPriority() throws {
        let json = """
        {
            "choices": [{
                "index": 0,
                "delta": {
                    "reasoning_content": "from reasoning_content",
                    "reasoning": "from reasoning"
                }
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.choices[0].delta.resolvedReasoning == "from reasoning_content")
    }

    @Test("Decodes reasoning_details with text and encrypted blocks")
    func decodeReasoningDetails() throws {
        let json = """
        {
            "choices": [{
                "index": 0,
                "delta": {
                    "reasoning": "Thinking...",
                    "reasoning_details": [
                        {"type": "reasoning.text", "text": "Thinking...", "format": "google-gemini-v1", "index": 0},
                        {"type": "reasoning.encrypted", "data": "EqoBCkgIAR...", "format": "google-gemini-v1", "index": 0}
                    ]
                }
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        let details = chunk.choices[0].delta.reasoningDetails
        #expect(details?.count == 2)
        #expect(details?[0].type == "reasoning.text")
        #expect(details?[0].text == "Thinking...")
        #expect(details?[1].type == "reasoning.encrypted")
        #expect(details?[1].data == "EqoBCkgIAR...")
    }

    @Test("Decodes tool_calls delta")
    func decodeToolCallsDelta() throws {
        let json = """
        {
            "choices": [{
                "index": 0,
                "delta": {
                    "tool_calls": [{
                        "index": 0,
                        "id": "call_abc123",
                        "type": "function",
                        "function": {
                            "name": "get_weather",
                            "arguments": "{\\"city\\":\\"Tokyo\\"}"
                        }
                    }]
                }
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.choices[0].delta.toolCalls?.count == 1)
        #expect(chunk.choices[0].delta.toolCalls?[0].function?.name == "get_weather")
        #expect(chunk.choices[0].delta.toolCalls?[0].id == "call_abc123")
    }

    @Test("Decodes empty delta gracefully")
    func decodeEmptyDelta() throws {
        let json = """
        {
            "choices": [{
                "index": 0,
                "delta": {}
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.choices[0].delta.content == nil)
        #expect(chunk.choices[0].delta.reasoningContent == nil)
    }

    @Test("Decodes real DeepSeek reasoning stream chunk")
    func decodeRealDeepSeekChunk() throws {
        // Actual format from DeepSeek deepseek-reasoner API
        let json = """
        {
            "id": "chatcmpl-abc123",
            "object": "chat.completion.chunk",
            "created": 1710000000,
            "model": "deepseek-reasoner",
            "choices": [{
                "index": 0,
                "delta": {
                    "reasoning_content": "好的"
                },
                "finish_reason": null
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.choices[0].delta.reasoningContent == "好的")
    }

    @Test("Decodes real Kimi K2.5 stream chunk")
    func decodeRealKimiChunk() throws {
        // Actual format from Kimi K2.5 API
        let json = """
        {
            "id": "cmpl-abc",
            "object": "chat.completion.chunk",
            "created": 1710000000,
            "model": "kimi-k2.5",
            "choices": [{
                "index": 0,
                "delta": {
                    "role": "assistant",
                    "content": "",
                    "reasoning_content": "让我来想想"
                }
            }]
        }
        """
        let chunk = try jsonDecoder.decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.choices[0].delta.reasoningContent == "让我来想想")
        #expect(chunk.choices[0].delta.content == "")
    }
}
