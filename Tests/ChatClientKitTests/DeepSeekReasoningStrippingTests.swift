//
//  DeepSeekReasoningStrippingTests.swift
//  ChatClientKitTests
//
//  Verifies DeepSeek V3.2 tool-call + reasoning rules:
//
//  - Assistant messages WITHOUT tool_calls  → reasoning stripped  (400 if included)
//  - Assistant messages WITH tool_calls     → reasoning PRESERVED (400 if omitted)
//
//  See: https://api-docs.deepseek.com/guides/reasoning_model
//       https://api-docs.deepseek.com/guides/tool_calls
//

@testable import ChatClientKit
import Foundation
import Testing

struct DeepSeekReasoningStrippingTests {
    // MARK: - No tool calls → strip reasoning

    @Test("DeepSeek resolve strips reasoning from plain assistant messages (no tool calls)")
    func stripReasoningFromAssistantMessages() {
        let client = DeepSeekClient(model: "deepseek-reasoner", apiKey: "test-key")

        let body = ChatRequestBody(
            messages: [
                .system(content: .text("You are helpful.")),
                .user(content: .text("Hello")),
                .assistant(content: .text("Hi there"), reasoning: "Let me think..."),
                .user(content: .text("How are you?")),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: true)

        #expect(resolved.model == "deepseek-reasoner")
        #expect(resolved.stream == true)

        for message in resolved.messages {
            if case let .assistant(_, toolCalls, reasoning, _) = message {
                let hasToolCalls = toolCalls != nil && !toolCalls!.isEmpty
                if !hasToolCalls {
                    #expect(reasoning == nil, "Reasoning must be stripped when there are no tool calls")
                }
            }
        }
        #expect(resolved.messages.count == 4)
    }

    // MARK: - With tool calls → preserve reasoning

    /// DeepSeek V3.2 thinking-integrated tool-use:
    /// every assistant message that triggers tool_calls must include reasoning_content
    /// in the follow-up request, or the API returns HTTP 400.
    ///
    /// Ref: https://api-docs.deepseek.com/guides/reasoning_model (Tool Calls section)
    @Test("DeepSeek resolve preserves reasoning in assistant messages that have tool calls")
    func preserveReasoningWithToolCalls() {
        let client = DeepSeekClient(model: "deepseek-reasoner", apiKey: "test-key")

        let toolCalls: [ChatRequestBody.Message.ToolCall] = [
            .init(id: "call_1", function: .init(name: "get_weather", arguments: "{\"city\":\"Tokyo\"}")),
        ]

        let body = ChatRequestBody(
            messages: [
                .assistant(
                    content: nil,
                    toolCalls: toolCalls,
                    reasoning: "I should use the weather tool to look this up."
                ),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: false)

        if case let .assistant(content, resolvedToolCalls, reasoning, _) = resolved.messages[0] {
            #expect(resolvedToolCalls?.count == 1, "Tool calls should be preserved")
            #expect(
                reasoning == "I should use the weather tool to look this up.",
                "Reasoning must be PRESERVED when tool_calls are present"
            )
            // Content should be injected as "" when originally nil + has tool calls
            if case let .text(text) = content {
                #expect(text == "", "Content must be empty string, not absent")
            } else {
                #expect(Bool(false), "Content should be .text when tool calls are present")
            }
        } else {
            #expect(Bool(false), "Expected assistant message")
        }
    }

    @Test("DeepSeek resolve preserves content and reasoning when tool calls present")
    func preserveContentAndReasoningWithToolCalls() {
        let client = DeepSeekClient(model: "deepseek-reasoner", apiKey: "test-key")

        let toolCalls: [ChatRequestBody.Message.ToolCall] = [
            .init(id: "call_1", function: .init(name: "get_weather", arguments: "{\"city\":\"Tokyo\"}")),
        ]

        let body = ChatRequestBody(
            messages: [
                .assistant(
                    content: .text("Let me check the weather."),
                    toolCalls: toolCalls,
                    reasoning: "I should look up weather data."
                ),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: false)

        if case let .assistant(content, resolvedToolCalls, reasoning, _) = resolved.messages[0] {
            if case let .text(text) = content {
                #expect(text == "Let me check the weather.", "Existing content must be preserved")
            }
            #expect(resolvedToolCalls?.count == 1, "Tool calls must be preserved")
            #expect(reasoning != nil, "Reasoning must be preserved when tool_calls present")
            #expect(reasoning == "I should look up weather data.")
        } else {
            #expect(Bool(false), "Expected assistant message")
        }
    }

    @Test("DeepSeek resolve strips reasoning from plain assistant message (no tool calls)")
    func stripReasoningNoToolCalls() {
        let client = DeepSeekClient(model: "deepseek-reasoner", apiKey: "test-key")

        let body = ChatRequestBody(
            messages: [
                .assistant(content: .text("The answer is 42."), reasoning: "Let me think..."),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: false)

        if case let .assistant(_, toolCalls, reasoning, _) = resolved.messages[0] {
            let hasToolCalls = toolCalls != nil && !toolCalls!.isEmpty
            #expect(!hasToolCalls, "No tool calls in this message")
            #expect(reasoning == nil, "Reasoning must be nil when no tool calls")
        } else {
            #expect(Bool(false), "Expected assistant message")
        }
    }

    @Test("DeepSeek resolve handles mixed: tool-call message keeps reasoning, plain message strips it")
    func mixedMessagesSelectiveReasoning() {
        let client = DeepSeekClient(model: "deepseek-reasoner", apiKey: "test-key")

        let toolCalls: [ChatRequestBody.Message.ToolCall] = [
            .init(id: "call_1", function: .init(name: "search", arguments: "{}")),
        ]

        let body = ChatRequestBody(
            messages: [
                .user(content: .text("Search for cats")),
                // This assistant message HAS tool calls → reasoning preserved
                .assistant(content: nil, toolCalls: toolCalls, reasoning: "I'll search"),
                .tool(content: .text("Results: [...]"), toolCallID: "call_1"),
                // This assistant message has NO tool calls → reasoning stripped
                .assistant(content: .text("Here are the results."), reasoning: "Let me summarize"),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: false)

        // Index 1: assistant with tool calls → reasoning preserved
        if case let .assistant(_, toolCalls1, reasoning1, _) = resolved.messages[1] {
            #expect(toolCalls1?.isEmpty == false)
            #expect(reasoning1 != nil, "Reasoning must be preserved for tool-call assistant message")
        }
        // Index 3: assistant without tool calls → reasoning stripped
        if case let .assistant(_, toolCalls3, reasoning3, _) = resolved.messages[3] {
            #expect(toolCalls3 == nil || toolCalls3!.isEmpty)
            #expect(reasoning3 == nil, "Reasoning must be stripped for plain assistant message")
        }
    }

    @Test("DeepSeek encoded JSON preserves reasoning_content in tool-call assistant message")
    func encodedJSONPreservesReasoningWithToolCalls() throws {
        let client = DeepSeekClient(model: "deepseek-reasoner", apiKey: "test-key")

        let toolCalls: [ChatRequestBody.Message.ToolCall] = [
            .init(id: "call_abc", function: .init(name: "calc", arguments: "{}")),
        ]

        let body = ChatRequestBody(
            messages: [
                .assistant(content: nil, toolCalls: toolCalls, reasoning: "calculating"),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: true)
        let data = try JSONEncoder().encode(resolved)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"reasoning\":\"calculating\""), "reasoning field must be present for tool-call messages")
        #expect(json.contains("\"content\":\"\""), "content must be empty string not absent")
        #expect(json.contains("\"tool_calls\""), "tool_calls must be present")
    }
}
