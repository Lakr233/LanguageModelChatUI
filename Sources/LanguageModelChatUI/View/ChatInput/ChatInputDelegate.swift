//
//  ChatInputDelegate.swift
//  LanguageModelChatUI
//

import UIKit

/// Delegate protocol for handling chat input events.
@MainActor
public protocol ChatInputDelegate: AnyObject {
    /// Called when the user submits input. Call `completion(true)` to confirm, `false` to reject.
    func chatInputDidSubmit(_ input: ChatInputView, object: ChatInputContent, completion: @escaping @Sendable (Bool) -> Void)
    /// Called when the input content changes.
    func chatInputDidUpdateObject(_ input: ChatInputView, object: ChatInputContent)
    /// Called to request a previously saved object for restoration.
    func chatInputDidRequestObjectForRestore(_ input: ChatInputView) -> ChatInputContent?
    /// Called when an error occurs in the input view.
    func chatInputDidReportError(_ input: ChatInputView, error: String)
}

/// Default implementations making all methods optional.
@MainActor
public extension ChatInputDelegate {
    func chatInputDidUpdateObject(_: ChatInputView, object _: ChatInputContent) {}
    func chatInputDidRequestObjectForRestore(_: ChatInputView) -> ChatInputContent? {
        nil
    }

    func chatInputDidReportError(_: ChatInputView, error _: String) {}
}
