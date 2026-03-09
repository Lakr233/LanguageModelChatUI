//
//  ModelChatMenuWrapper.swift
//  Example
//
//  Created by qaq on 9/3/2026.
//

import LanguageModelChatUI
import UIKit

class ModelChatMenuWrapper: NSObject, ChatViewControllerMenuDelegate {
    let def: ModelDefinition

    init(chatViewController: ChatViewController, def: ModelDefinition) {
        self.def = def
        super.init()
        objc_setAssociatedObject(chatViewController, &AssociatedKeys.menuWrapper, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func chatViewControllerMenu(_ controller: ChatViewController) -> UIMenu? {
        let infoMenu = UIMenu(
            title: String(localized: "Info"),
            image: UIImage(systemName: "info.circle"),
            children: [
                UIAction(title: "Model: \(def.title)", image: UIImage(systemName: def.icon), attributes: .disabled) { _ in },
                UIAction(title: "Provider: \(def.subtitle)", image: UIImage(systemName: "cloud"), attributes: .disabled) { _ in },
            ]
        )

        let titleMenu = UIMenu(
            title: String(localized: "Title"),
            image: UIImage(systemName: "textformat"),
            children: [
                UIAction(title: String(localized: "Regenerate Title"), image: UIImage(systemName: "arrow.trianglehead.2.clockwise")) { _ in
                    controller.regenerateTitle()
                },
            ]
        )

        return UIMenu(children: [
            infoMenu,
            titleMenu,
            UIAction(title: String(localized: "Clear"), image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                controller.clearConversation()
            },
        ])
    }
}

enum AssociatedKeys {
    static var menuWrapper: UInt8 = 0
}
