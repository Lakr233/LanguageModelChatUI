//
//  AttachmentsBar+Delegate.swift
//  LanguageModelChatUI
//

import Foundation

extension AttachmentsBar {
    @MainActor
    protocol Delegate: AnyObject {
        func attachmentBarDidUpdateAttachments(_ attachments: [Item])
    }
}
