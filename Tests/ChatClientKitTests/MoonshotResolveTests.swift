//
//  MoonshotResolveTests.swift
//  ChatClientKitTests
//
//  Verifies Kimi K2.5 tool-call + reasoning rules (same contract as DeepSeek V3.2):
//
//  - Assistant messages WITHOUT tool_calls  → reasoning stripped  (not accepted by API)
//  - Assistant messages WITH tool_calls     → reasoning PRESERVED (required when thinking active)
//  - content must be "" (not absent) when tool_calls are present
//
//  See: https://platform.moonshot.ai/docs/guide/use-kimi-api-to-complete-tool-calls
//

@testable import ChatClientKit
import Foundation
import Testing

struct MoonshotResolveTests {
    // MARK: - No tool calls → strip reasoning

    @Test("Moonshot resolve strips reasoning from plain assistant messages (no tool calls)")
    func stripReasoningFromAssistantMessages() {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "test-key")

        let body = ChatRequestBody(
            messages: [
                .system(content: .text("You are helpful.")),
                .user(content: .text("Hello")),
                .assistant(content: .text("Hi there"), reasoning: "Let me think about this..."),
                .user(content: .text("How are you?")),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: true)

        #expect(resolved.model == "kimi-k2.5")
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

    // MARK: - With tool calls → preserve reasoning + inject content = ""

    @Test("Moonshot resolve preserves reasoning in assistant messages that have tool calls")
    func preserveReasoningWithToolCalls() {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "test-key")

        let toolCalls: [ChatRequestBody.Message.ToolCall] = [
            .init(id: "call_1", function: .init(name: "get_weather", arguments: "{\"city\":\"Beijing\"}")),
        ]

        let body = ChatRequestBody(
            messages: [
                .assistant(
                    content: nil,
                    toolCalls: toolCalls,
                    reasoning: "I should look up weather data."
                ),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: true)

        if case let .assistant(content, resolvedToolCalls, reasoning, _) = resolved.messages[0] {
            #expect(resolvedToolCalls?.count == 1, "Tool calls should be preserved")
            #expect(
                reasoning == "I should look up weather data.",
                "Reasoning must be PRESERVED when tool_calls are present"
            )
            // content nil + has tool calls → inject ""
            if case let .text(text) = content {
                #expect(text == "", "Content must be empty string, not absent")
            } else {
                #expect(Bool(false), "Content should be .text when tool calls are present")
            }
        } else {
            #expect(Bool(false), "Expected assistant message")
        }
    }

    @Test("Moonshot resolve preserves content and reasoning when tool calls present")
    func preserveContentAndReasoningWithToolCalls() {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "test-key")

        let toolCalls: [ChatRequestBody.Message.ToolCall] = [
            .init(id: "call_1", function: .init(name: "search", arguments: "{\"q\":\"test\"}")),
        ]

        let body = ChatRequestBody(
            messages: [
                .assistant(
                    content: .text("Let me search for that."),
                    toolCalls: toolCalls,
                    reasoning: "User wants a search."
                ),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: false)

        if case let .assistant(content, resolvedToolCalls, reasoning, _) = resolved.messages[0] {
            if case let .text(text) = content {
                #expect(text == "Let me search for that.", "Existing content should be preserved")
            } else {
                #expect(Bool(false), "Content should be .text")
            }
            #expect(resolvedToolCalls?.count == 1)
            #expect(reasoning == "User wants a search.", "Reasoning must be preserved when tool_calls present")
        } else {
            #expect(Bool(false), "Expected assistant message")
        }
    }

    @Test("Moonshot resolve strips reasoning from plain assistant message (no tool calls)")
    func stripReasoningNoToolCalls() {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "test-key")

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

    @Test("Moonshot resolve does not inject content when assistant has no tool calls")
    func noContentInjectionWithoutToolCalls() {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "test-key")

        let body = ChatRequestBody(
            messages: [
                .assistant(content: nil, reasoning: "just thinking"),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: true)

        if case let .assistant(content, _, reasoning, _) = resolved.messages[0] {
            #expect(content == nil, "Content should remain nil when there are no tool calls")
            #expect(reasoning == nil, "Reasoning should be stripped when no tool calls")
        } else {
            #expect(Bool(false), "Expected assistant message")
        }
    }

    @Test("Moonshot resolve handles mixed: tool-call message keeps reasoning, plain message strips it")
    func mixedMessagesSelectiveReasoning() {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "test-key")

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

    @Test("Moonshot resolve preserves tool and other message types")
    func preserveNonAssistantMessages() {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "test-key")

        let body = ChatRequestBody(
            messages: [
                .system(content: .text("System prompt")),
                .user(content: .text("Hello")),
                .tool(content: .text("{\"result\":42}"), toolCallID: "call_1"),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: true)

        #expect(resolved.messages.count == 3)
        #expect(resolved.messages[0].role == "system")
        #expect(resolved.messages[1].role == "user")
        #expect(resolved.messages[2].role == "tool")
    }

    @Test("Moonshot encoded JSON preserves reasoning_content in tool-call assistant message")
    func encodedJSONPreservesReasoningWithToolCalls() throws {
        let client = MoonshotClient(model: "kimi-k2.5", apiKey: "test-key")

        let toolCalls: [ChatRequestBody.Message.ToolCall] = [
            .init(id: "call_abc", function: .init(name: "get_time", arguments: "{}")),
        ]

        let body = ChatRequestBody(
            messages: [
                .assistant(content: nil, toolCalls: toolCalls, reasoning: "checking time"),
            ]
        )

        let resolved = client.applyModelSettings(to: body, streaming: true)
        let data = try JSONEncoder().encode(resolved)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"reasoning\":\"checking time\""), "reasoning field must be present for tool-call messages")
        #expect(json.contains("\"content\":\"\""), "content must be empty string not absent")
        #expect(json.contains("\"tool_calls\""), "tool_calls must be present")
    }
}
