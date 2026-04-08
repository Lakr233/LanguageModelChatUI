//
//  ConversationSession+Title.swift
//  LanguageModelChatUI
//
//  Auto-generate conversation title from content.
//

import ChatClientKit
import Foundation

extension ConversationSession {
    /// Auto-generate a title for the conversation using the title-generation model.
    func updateTitle() async {
        guard let titleGenerationModel = models.titleGeneration else { return }

        let existingMetadata = ConversationTitleMetadata(storageValue: storageProvider.title(for: id))
        let existingTitle = existingMetadata?.title ?? ""
        let hasCustomTitle = !existingTitle.isEmpty && existingTitle != "Untitled"

        // Skip if already titled
        if hasCustomTitle { return }

        await generateTitle(using: titleGenerationModel)
    }

    /// Force-regenerate the title, ignoring any existing title.
    func regenerateTitle() async {
        guard let titleGenerationModel = models.titleGeneration else { return }
        await generateTitle(using: titleGenerationModel)
    }

    private func generateTitle(using titleGenerationModel: Model) async {
        // Build a summary request
        let summaryLines = messages.prefix(10).compactMap { message -> String? in
            let text = message.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : "\(message.role.rawValue): \(String(text.prefix(200)))"
        }

        guard !summaryLines.isEmpty else { return }

        let conversationXML = summaryLines.enumerated().map { index, line in
            "  <message index=\"\(index)\">\(escapeTitleXML(line))</message>"
        }.joined(separator: "\n")

        let prompt = """
        You are generating compact chat metadata.

        Input XML:
        <conversation>
        \(conversationXML)
        </conversation>

        You must call the tool `\(ConversationTitleMetadata.generationToolName)` exactly once.

        If tool calling is unavailable, return XML only using exactly this schema:
        <conversationTitle>
          <title>Short title, max 6 words</title>
          <titleAvatar>One emoji only</titleAvatar>
        </conversationTitle>

        Rules:
        - Prefer the required tool call over plain text.
        - Output valid XML only.
        - titleAvatar must be exactly one emoji.
        - No markdown, no code fence, no explanation.
        """

        do {
            let client = titleGenerationModel.client
            let stream = try await client.streamingChat(body: .init(
                model: titleGenerationModel.model,
                messages: [.user(content: .text(prompt))],
                stream: true,
                tools: [ConversationTitleMetadata.generationTool]
            ))
            var toolRequest: ToolRequest?
            var streamedText = ""
            for try await chunk in stream {
                if case let .tool(request) = chunk,
                   request.name == ConversationTitleMetadata.generationToolName
                {
                    toolRequest = request
                } else if case let .text(value) = chunk {
                    streamedText += value
                }
            }

            let titleMetadata = toolRequest
                .flatMap { ConversationTitleMetadata(toolArguments: $0.arguments) }
                ?? ConversationTitleMetadata(storageValue: streamedText)

            if let titleMetadata, !titleMetadata.title.isEmpty, titleMetadata.title.count < 50 {
                storageProvider.setTitle(titleMetadata.storageValue, for: id)
            }
        } catch {
            // Title generation is best-effort, ignore errors
        }
    }

    private func escapeTitleXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
