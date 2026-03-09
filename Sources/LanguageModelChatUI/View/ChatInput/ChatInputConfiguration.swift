//
//  ChatInputConfiguration.swift
//  LanguageModelChatUI
//

import UIKit

/// Configuration for the chat input view behavior and contents.
@MainActor
public struct ChatInputConfiguration {
    public var pasteLargeTextAsFile: Bool
    public var compressImage: Bool
    public var quickSettingItems: [QuickSettingItem]
    public var controlPanelItems: [ControlPanelItem]

    public static let `default` = ChatInputConfiguration()

    public init(
        pasteLargeTextAsFile: Bool = true,
        compressImage: Bool = true,
        quickSettingItems: [QuickSettingItem] = [],
        controlPanelItems: [ControlPanelItem] = ControlPanelItem.defaults
    ) {
        self.pasteLargeTextAsFile = pasteLargeTextAsFile
        self.compressImage = compressImage
        self.quickSettingItems = quickSettingItems
        self.controlPanelItems = controlPanelItems
    }
}
