//
//  SerializationIdempotencyTests.swift
//  ChatClientKitTests
//

@testable import ChatClientKit
import Foundation
import Testing

struct SerializationIdempotencyTests {
    @Test("Encoding ChatRequestBody twice produces identical bytes")
    func encodeTwiceProducesSameBytes() throws {
        let body = ChatRequestBody(
            model: "test-model",
            messages: [
                .system(content: .text("You are helpful.")),
                .user(content: .text("Hello")),
                .assistant(content: .text("Hi there"), reasoning: "thinking..."),
            ],
            maxCompletionTokens: 1024,
            stream: true,
            temperature: 0.7
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let data1 = try encoder.encode(body)
        let data2 = try encoder.encode(body)

        #expect(data1 == data2)
    }

    @Test("Encoding with tools produces deterministic output")
    func encodeWithToolsIsDeterministic() throws {
        let body = ChatRequestBody(
            model: "test-model",
            messages: [
                .user(content: .text("What's the weather?")),
            ],
            tools: [
                .function(
                    name: "get_weather",
                    description: "Get current weather",
                    parameters: [
                        "type": .string("object"),
                        "properties": .object([
                            "location": .object([
                                "type": .string("string"),
                                "description": .string("City name"),
                            ]),
                        ]),
                    ],
                    strict: true
                ),
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let results = try (0 ..< 10).map { _ in try encoder.encode(body) }
        for i in 1 ..< results.count {
            #expect(results[0] == results[i], "Encoding \(i) differs from encoding 0")
        }
    }

    @Test("SHA256 cache identifier is stable across multiple calls")
    func cacheIdentifierIsStable() {
        let request = ChatRequest {
            ChatRequest.system("You are a helpful assistant.")
            ChatRequest.user("Hello!")
        }

        let id1 = request.cacheIdentifier
        let id2 = request.cacheIdentifier

        #expect(id1 == id2)
        #expect(!id1.rawValue.isEmpty)
    }
}
