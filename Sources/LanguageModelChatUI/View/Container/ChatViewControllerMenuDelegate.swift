//
//  ChatViewControllerMenuDelegate.swift
//  LanguageModelChatUI
//

import UIKit

@MainActor
public protocol ChatViewControllerMenuDelegate: AnyObject {
    /// Return the trailing menu shown in the navigation bar. Return nil to hide the trailing item.
    func chatViewControllerMenu(_ controller: ChatViewController) -> UIMenu?
}

public extension ChatViewControllerMenuDelegate {
    func chatViewControllerMenu(_ controller: ChatViewController) -> UIMenu? {
        _ = controller
        return nil
    }
}
