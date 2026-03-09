//
//  InputEditor+Delegate.swift
//  LanguageModelChatUI
//

import UIKit

extension InputEditor {
    @MainActor
    protocol Delegate: AnyObject {
        func onInputEditorCaptureButtonTapped()
        func onInputEditorPickAttachmentTapped()
        func onInputEditorMicButtonTapped()
        func onInputEditorToggleMoreButtonTapped()
        func onInputEditorBeginEditing()
        func onInputEditorEndEditing()
        func onInputEditorSubmitButtonTapped()
        func onInputEditorPasteAsAttachmentTapped()
        func onInputEditorTextChanged(text: String)
        func onInputEditorPastingLargeTextAsDocument(content: String)
        func onInputEditorPastingImage(image: UIImage)
    }
}
