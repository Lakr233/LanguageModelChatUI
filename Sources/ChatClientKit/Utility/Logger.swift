//
//  Created by ktiays on 2025/2/12.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import Foundation
import OSLog

let logger = Logger(subsystem: "ChatClientKit", category: "ChatClientKit")

extension ChatRequestBody {
    var debugSummary: String {
        let messageSummaries = messages.enumerated().map { index, message in
            "[\(index)] \(message.debugSummary)"
        }.joined(separator: " | ")

        return "model=\(model ?? "nil") stream=\(stream?.description ?? "nil") messages=\(messages.count) tools=\(tools?.count ?? 0) \(messageSummaries)"
    }
}

private extension ChatRequestBody.Message {
    var debugSummary: String {
        switch self {
        case let .assistant(content, toolCalls, reasoning, _):
            var components = ["role=assistant"]
            if let content {
                components.append("content=\(assistantContentSummary(content))")
            }
            if let reasoning {
                components.append("reasoningChars=\(reasoning.count)")
            }
            if let toolCalls {
                components.append("toolCalls=\(toolCalls.count)")
            }
            return components.joined(separator: " ")

        case let .developer(content, name):
            return "role=developer name=\(name ?? "nil") content=\(textContentSummary(content))"

        case let .system(content, name):
            return "role=system name=\(name ?? "nil") content=\(textContentSummary(content))"

        case let .tool(content, toolCallID):
            return "role=tool toolCallID=\(toolCallID) content=\(textContentSummary(content))"

        case let .user(content, name):
            switch content {
            case let .text(text):
                return "role=user name=\(name ?? "nil") content=text(chars=\(text.count))"
            case let .parts(parts):
                let partSummary = parts.map(\.debugSummary).joined(separator: ", ")
                return "role=user name=\(name ?? "nil") parts=\(parts.count) {\(partSummary)}"
            }
        }
    }

    private func textContentSummary(
        _ content: ChatRequestBody.Message.MessageContent<String, [String]>
    ) -> String {
        switch content {
        case let .text(text):
            return "text(chars=\(text.count))"
        case let .parts(parts):
            let lengths = parts.map { String($0.count) }.joined(separator: ",")
            return "parts(count=\(parts.count),chars=[\(lengths)])"
        }
    }

    private func assistantContentSummary(
        _ content: ChatRequestBody.Message.MessageContent<String, [String]>
    ) -> String {
        textContentSummary(content)
    }
}

private extension ChatRequestBody.Message.ContentPart {
    var debugSummary: String {
        switch self {
        case let .text(text):
            return "text(chars=\(text.count))"
        case let .imageURL(url, detail):
            let absoluteString = url.absoluteString
            if absoluteString.hasPrefix("data:"), let commaIndex = absoluteString.firstIndex(of: ",") {
                let header = String(absoluteString[..<commaIndex])
                let payloadLength = absoluteString.distance(from: absoluteString.index(after: commaIndex), to: absoluteString.endIndex)
                return "image(header=\(header),payloadChars=\(payloadLength),detail=\(detail?.rawValue ?? "nil"))"
            }
            return "image(url=\(absoluteString),detail=\(detail?.rawValue ?? "nil"))"
        case let .audioBase64(data, format):
            return "audio(format=\(format),payloadChars=\(data.count))"
        }
    }
}
