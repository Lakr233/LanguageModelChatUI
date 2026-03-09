//
//  ChatInputContent.swift
//  LanguageModelChatUI
//

import Foundation
import UIKit

/// The data collected from the chat input view on submission.
public struct ChatInputContent: Codable, Sendable {
    public var text: String = ""
    public var attachments: [ChatInputAttachment] = []
    public var options: [String: ChatInputOptionValue] = [:]

    public var hasEmptyContent: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty
    }
}

/// An attachment in the chat input.
public struct ChatInputAttachment: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let type: AttachmentType
    public var name: String
    public var previewImageData: Data
    public var fileData: Data
    public var textContent: String
    public var storageFilename: String

    public enum AttachmentType: String, Codable, Sendable {
        case image
        case document
        case audio
    }

    public init(
        id: UUID = .init(),
        type: AttachmentType,
        name: String = "",
        previewImageData: Data = .init(),
        fileData: Data = .init(),
        textContent: String = "",
        storageFilename: String = ""
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.previewImageData = previewImageData
        self.fileData = fileData
        self.textContent = textContent
        self.storageFilename = storageFilename
    }
}

/// A value stored in chat input options.
public enum ChatInputOptionValue: Codable, Sendable {
    case string(String)
    case bool(Bool)
    case url(URL)
}
