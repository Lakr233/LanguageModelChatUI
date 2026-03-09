//
//  ChatInputView+Object.swift
//  LanguageModelChatUI
//

import Foundation
import UIKit

extension ChatInputView {
    public func collectObject() -> ChatInputContent {
        var text = (inputEditor.textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = attachmentsBar.attachments.values
        if text.isEmpty, !attachments.isEmpty {
            text = String.localized("Attached \(attachments.count) Documents")
        }
        return ChatInputContent(
            text: text,
            attachments: .init(attachments),
            options: [
                "storagePrefix": .url(storage.storageDir),
            ]
        )
    }

    func resetValues() {
        inputEditor.set(text: "")
        inputEditor.endEditing(true)
        attachmentsBar.attachments.removeAll()
        controlPanel.close()
        inputEditor.isControlPanelOpened = false
        setNeedsLayout()
        publishNewEditorStatus()
    }

    func submitValues() {
        let object = collectObject()
        guard !object.hasEmptyContent else { return }
        endEditing(true)

        resetValues()
        storage.removeAll()

        let completion: @Sendable (Bool) -> Void = { success in
            Task { @MainActor in
                guard !success else { return }
                self.refill(withText: object.text, attachments: object.attachments)
                self.publishNewEditorStatus()
            }
        }
        delegate?.chatInputDidSubmit(self, object: object, completion: completion)
    }

    func publishNewEditorStatus() {
        assert(Thread.isMainThread)
        let object = collectObject()
        guard !objectTransactionInProgress else { return }
        objectTransactionInProgress = true
        defer { objectTransactionInProgress = false }
        delegate?.chatInputDidUpdateObject(self, object: object)
    }

    func restoreEditorStatusIfPossible() {
        assert(Thread.isMainThread)
        guard let object = delegate?.chatInputDidRequestObjectForRestore(self) else { return }
        objectTransactionInProgress = true
        defer { objectTransactionInProgress = false }
        resetValues()
        inputEditor.set(text: object.text.trimmingCharacters(in: .whitespacesAndNewlines))
        attachmentsBar.attachments.removeAll()
        for attachment in object.attachments {
            attachmentsBar.insert(item: attachment)
        }
    }

    public func refill(withText text: String, attachments: [ChatInputAttachment]) {
        inputEditor.set(text: text)
        attachmentsBar.attachments.removeAll()
        for attachment in attachments {
            attachmentsBar.insert(item: attachment)
        }
    }
}
