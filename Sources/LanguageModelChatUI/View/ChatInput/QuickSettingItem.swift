//
//  QuickSettingItem.swift
//  LanguageModelChatUI
//

import UIKit

/// An abstract item displayed in the quick setting bar.
@MainActor
public enum QuickSettingItem {
    /// A toggle switch with on/off state.
    case toggle(id: String, title: String, icon: String, isOn: Bool, onChange: @MainActor (Bool) -> Void)
    /// A button that shows a menu when tapped.
    case menu(id: String, title: String, icon: String, menuProvider: @MainActor () -> [UIMenuElement])

    var id: String {
        switch self {
        case let .toggle(id, _, _, _, _): id
        case let .menu(id, _, _, _): id
        }
    }
}
