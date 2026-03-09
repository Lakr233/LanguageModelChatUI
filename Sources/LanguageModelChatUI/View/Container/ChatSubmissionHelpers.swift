import Foundation
import OSLog
import UniformTypeIdentifiers

private let submissionLogger = Logger(subsystem: "LanguageModelChatUI", category: "Submission")

@MainActor func applyConversationModels(
    _ models: ConversationSession.Models,
    to session: ConversationSession
) {
    if let chat = models.chat {
        session.models.chat = chat
    }
    if let titleGeneration = models.titleGeneration {
        session.models.titleGeneration = titleGeneration
    }
}

func makeUserInput(from object: ChatInputContent) -> ConversationSession.UserInput {
    let attachmentSummary = object.attachments.map { attachment in
        "\(attachment.type.rawValue)(fileBytes=\(attachment.fileData.count),previewBytes=\(attachment.previewImageData.count),textChars=\(attachment.textContent.count))"
    }.joined(separator: ", ")
    submissionLogger.info(
        "makeUserInput textChars=\(object.text.count) attachments=\(object.attachments.count) [\(attachmentSummary)]"
    )

    return .init(
        text: object.text,
        attachments: object.attachments.map(makeContentPart)
    )
}

private func makeContentPart(from attachment: ChatInputAttachment) -> ContentPart {
    switch attachment.type {
    case .image:
        .image(.init(
            mediaType: mediaType(for: attachment, fallback: "image/jpeg"),
            data: attachment.fileData,
            previewData: attachment.previewImageData.isEmpty ? nil : attachment.previewImageData,
            name: attachment.name
        ))
    case .document:
        .file(.init(
            mediaType: mediaType(for: attachment, fallback: "text/plain"),
            data: Data(attachment.textContent.utf8),
            textContent: attachment.textContent,
            name: attachment.name
        ))
    case .audio:
        .audio(.init(
            mediaType: mediaType(for: attachment, fallback: "audio/m4a"),
            data: attachment.fileData,
            transcription: attachment.textContent.isEmpty ? nil : attachment.textContent,
            name: attachment.name
        ))
    }
}

private func mediaType(for attachment: ChatInputAttachment, fallback: String) -> String {
    let ext = URL(fileURLWithPath: attachment.storageFilename).pathExtension
    guard !ext.isEmpty else { return fallback }
    if let type = UTType(filenameExtension: ext), let mimeType = type.preferredMIMEType {
        return mimeType
    }
    return fallback
}
