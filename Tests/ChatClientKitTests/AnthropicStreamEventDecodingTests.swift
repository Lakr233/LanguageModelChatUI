//
//  AnthropicStreamEventDecodingTests.swift
//  ChatClientKitTests
//

@testable import ChatClientKit
import Foundation
import Testing

struct AnthropicStreamEventDecodingTests {
    let decoder = JSONDecoder()

    @Test("Decodes message_start event")
    func decodeMessageStart() throws {
        let json = """
        {
            "type": "message_start",
            "message": {
                "id": "msg_01XF",
                "type": "message",
                "role": "assistant",
                "model": "claude-sonnet-4.6",
                "stop_reason": null,
                "usage": {
                    "input_tokens": 25,
                    "output_tokens": 1
                }
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.type == "message_start")
        #expect(event.message?.role == "assistant")
        #expect(event.message?.model == "claude-sonnet-4.6")
        #expect(event.message?.usage?.inputTokens == 25)
    }

    @Test("Decodes content_block_start with thinking type")
    func decodeThinkingBlockStart() throws {
        let json = """
        {
            "type": "content_block_start",
            "index": 0,
            "content_block": {
                "type": "thinking",
                "thinking": ""
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.type == "content_block_start")
        #expect(event.index == 0)
        #expect(event.contentBlock?.type == "thinking")
    }

    @Test("Decodes content_block_start with text type")
    func decodeTextBlockStart() throws {
        let json = """
        {
            "type": "content_block_start",
            "index": 1,
            "content_block": {
                "type": "text",
                "text": ""
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.type == "content_block_start")
        #expect(event.index == 1)
        #expect(event.contentBlock?.type == "text")
    }

    @Test("Decodes content_block_start with tool_use type")
    func decodeToolUseBlockStart() throws {
        let json = """
        {
            "type": "content_block_start",
            "index": 2,
            "content_block": {
                "type": "tool_use",
                "id": "toolu_01abc",
                "name": "get_weather"
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.contentBlock?.type == "tool_use")
        #expect(event.contentBlock?.id == "toolu_01abc")
        #expect(event.contentBlock?.name == "get_weather")
    }

    @Test("Decodes thinking_delta")
    func decodeThinkingDelta() throws {
        let json = """
        {
            "type": "content_block_delta",
            "index": 0,
            "delta": {
                "type": "thinking_delta",
                "thinking": "Let me analyze this problem..."
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.type == "content_block_delta")
        #expect(event.delta?.type == "thinking_delta")
        #expect(event.delta?.thinking == "Let me analyze this problem...")
    }

    @Test("Decodes text_delta")
    func decodeTextDelta() throws {
        let json = """
        {
            "type": "content_block_delta",
            "index": 1,
            "delta": {
                "type": "text_delta",
                "text": "Here is my response."
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.delta?.type == "text_delta")
        #expect(event.delta?.text == "Here is my response.")
    }

    @Test("Decodes signature_delta for encrypted thinking")
    func decodeSignatureDelta() throws {
        let json = """
        {
            "type": "content_block_delta",
            "index": 0,
            "delta": {
                "type": "signature_delta",
                "signature": "EqoBCkgIAR..."
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.delta?.type == "signature_delta")
        #expect(event.delta?.signature == "EqoBCkgIAR...")
    }

    @Test("Decodes input_json_delta for tool calls")
    func decodeInputJsonDelta() throws {
        let json = """
        {
            "type": "content_block_delta",
            "index": 2,
            "delta": {
                "type": "input_json_delta",
                "partial_json": "{\\"city\\":\\"Tok"
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.delta?.type == "input_json_delta")
        #expect(event.delta?.partialJson == "{\"city\":\"Tok")
    }

    @Test("Decodes content_block_stop")
    func decodeContentBlockStop() throws {
        let json = """
        {
            "type": "content_block_stop",
            "index": 0
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.type == "content_block_stop")
        #expect(event.index == 0)
    }

    @Test("Decodes message_delta with stop_reason")
    func decodeMessageDelta() throws {
        let json = """
        {
            "type": "message_delta",
            "delta": {
                "stop_reason": "end_turn"
            },
            "usage": {
                "output_tokens": 150
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.type == "message_delta")
        #expect(event.delta?.stopReason == "end_turn")
        #expect(event.usage?.outputTokens == 150)
    }

    @Test("Decodes error event")
    func decodeErrorEvent() throws {
        let json = """
        {
            "type": "error",
            "error": {
                "type": "overloaded_error",
                "message": "Overloaded"
            }
        }
        """
        let event = try decoder.decode(AnthropicStreamEvent.self, from: Data(json.utf8))
        #expect(event.type == "error")
        #expect(event.error?.type == "overloaded_error")
        #expect(event.error?.message == "Overloaded")
    }
}

struct AnthropicRequestTransformerTests {
    @Test("Transforms system message to system blocks")
    func transformSystemMessage() {
        let transformer = AnthropicRequestTransformer()
        let body = ChatRequestBody(
            messages: [
                .system(content: .text("You are helpful.")),
                .user(content: .text("Hi")),
            ]
        )

        let result = transformer.makeRequestBody(from: body, model: "claude-sonnet-4.6", stream: true)

        #expect(result.system?.count == 1)
        #expect(result.system?[0].text == "You are helpful.")
        #expect(result.messages.count == 1)
        #expect(result.messages[0].role == "user")
    }

    @Test("Transforms user text content")
    func transformUserContent() {
        let transformer = AnthropicRequestTransformer()
        let body = ChatRequestBody(
            messages: [.user(content: .text("Hello"))]
        )

        let result = transformer.makeRequestBody(from: body, model: "test", stream: true)

        #expect(result.messages.count == 1)
        #expect(result.messages[0].role == "user")
    }

    @Test("Enables thinking config when budget > 0")
    func enableThinkingConfig() {
        let transformer = AnthropicRequestTransformer(thinkingBudgetTokens: 10000)
        let body = ChatRequestBody(
            messages: [.user(content: .text("Think about this"))],
            temperature: 0.5
        )

        let result = transformer.makeRequestBody(from: body, model: "test", stream: true)

        #expect(result.thinking != nil)
        #expect(result.thinking?.budgetTokens == 10000)
        // Temperature must be nil when thinking is enabled
        #expect(result.temperature == nil)
    }

    @Test("Disables thinking config when budget is 0")
    func disableThinkingConfig() {
        let transformer = AnthropicRequestTransformer(thinkingBudgetTokens: 0)
        let body = ChatRequestBody(
            messages: [.user(content: .text("Hello"))],
            temperature: 0.7
        )

        let result = transformer.makeRequestBody(from: body, model: "test", stream: true)

        #expect(result.thinking == nil)
        #expect(result.temperature == 0.7)
    }

    @Test("Maps tool definitions correctly")
    func mapToolDefinitions() {
        let transformer = AnthropicRequestTransformer()
        let body = ChatRequestBody(
            messages: [.user(content: .text("Use tools"))],
            tools: [
                .function(
                    name: "calculator",
                    description: "Calculate math expressions",
                    parameters: [
                        "type": .string("object"),
                        "properties": .object([
                            "expression": .object(["type": .string("string")]),
                        ]),
                    ],
                    strict: nil
                ),
            ]
        )

        let result = transformer.makeRequestBody(from: body, model: "test", stream: true)

        #expect(result.tools?.count == 1)
        #expect(result.tools?[0].name == "calculator")
        #expect(result.tools?[0].description == "Calculate math expressions")
    }
}
