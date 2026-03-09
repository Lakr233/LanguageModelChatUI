//
//  ControlPanel+Delegate.swift
//  LanguageModelChatUI
//

import Foundation

extension ControlPanel {
    @MainActor
    protocol Delegate: AnyObject {
        func onControlPanelOpen()
        func onControlPanelClose()
        func onControlPanelCameraButtonTapped()
        func onControlPanelPickPhotoButtonTapped()
        func onControlPanelPickFileButtonTapped()
        func onControlPanelRequestWebScrubber()
    }
}
