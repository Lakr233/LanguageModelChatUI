//
//  ChatViewControllerConfiguration.swift
//  LanguageModelChatUI
//

import MarkdownView
import UIKit

public extension ChatViewController {
    @MainActor
    struct Configuration {
        public var input: ChatInputConfiguration
        public var messageTheme: MarkdownTheme

        public init(
            input: ChatInputConfiguration = .default,
            messageTheme: MarkdownTheme = .default
        ) {
            self.input = input
            self.messageTheme = messageTheme
        }
    }
}
