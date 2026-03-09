//
//  ChatInputView+Drop.swift
//  LanguageModelChatUI
//

import UIKit
import UniformTypeIdentifiers

extension ChatInputView: UIDropInteractionDelegate {
    public func dropInteraction(_: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        var canHandleDrop = true
        for provider in session.items.map(\.itemProvider) {
            if session.localDragSession != nil {
                canHandleDrop = false
            }
            if canHandleDrop, provider.hasItemConformingToTypeIdentifier(UTType.folder.identifier) {
                canHandleDrop = false
            }
            if canHandleDrop, !provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                canHandleDrop = false
            }
        }
        return canHandleDrop
    }

    public func dropInteraction(_: UIDropInteraction, sessionDidUpdate _: UIDropSession) -> UIDropProposal {
        .init(operation: .copy)
    }

    public func dropInteraction(_: UIDropInteraction, sessionDidEnter _: UIDropSession) {
        UIView.animate(withDuration: 0.25) { self.dropColorView.alpha = 1 }
    }

    public func dropInteraction(_: UIDropInteraction, sessionDidExit _: any UIDropSession) {
        UIView.animate(withDuration: 0.25) { self.dropColorView.alpha = 0 }
    }

    public func dropInteraction(_: UIDropInteraction, sessionDidEnd _: UIDropSession) {
        UIView.animate(withDuration: 0.25) { self.dropColorView.alpha = 0 }
    }

    public func dropInteraction(_: UIDropInteraction, performDrop session: any UIDropSession) {
        let items = session.items
        UIView.animate(withDuration: 0.25) { self.dropColorView.alpha = 0 }
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanguageModelChatUI.Drop")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for provider in items.map(\.itemProvider) {
            provider.loadFileRepresentation(
                forTypeIdentifier: UTType.item.identifier
            ) { url, _ in
                guard let url else { return }
                let targetURL = tempDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.copyItem(at: url, to: targetURL)
                Task { @MainActor [weak self] in
                    self?.process(file: targetURL)
                    Task.detached {
                        try? await Task.sleep(for: .seconds(30))
                        try? FileManager.default.removeItem(at: tempDir)
                    }
                }
            }
        }
    }
}
