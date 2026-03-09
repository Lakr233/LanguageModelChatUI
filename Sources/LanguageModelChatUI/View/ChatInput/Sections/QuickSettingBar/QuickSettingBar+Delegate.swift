//
//  QuickSettingBar+Delegate.swift
//  LanguageModelChatUI
//

import Foundation

extension QuickSettingBar {
    @MainActor
    protocol Delegate: AnyObject {
        func quickSettingBarOnValueChanged()
    }
}
