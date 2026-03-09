//
//  ControlPanelItem.swift
//  LanguageModelChatUI
//

import UIKit

/// An item displayed in the control panel grid.
@MainActor
public struct ControlPanelItem {
    public let id: String
    public let title: String
    public let icon: String
    public let action: @MainActor () -> Void

    public init(id: String, title: String, icon: String, action: @MainActor @escaping () -> Void) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
    }
}

public extension ControlPanelItem {
    /// Default control panel items: Camera (iOS only), Photo, File.
    static var defaults: [ControlPanelItem] {
        var items: [ControlPanelItem] = []
        items.append(.init(id: "camera", title: String.localized("Camera"), icon: "camera", action: {}))
        items.append(.init(id: "photo", title: String.localized("Photo"), icon: "image.up", action: {}))
        items.append(.init(id: "file", title: String.localized("File"), icon: "attachment", action: {}))
        return items
    }
}
