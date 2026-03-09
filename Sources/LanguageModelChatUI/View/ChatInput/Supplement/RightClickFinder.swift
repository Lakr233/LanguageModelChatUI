//
//  RightClickFinder.swift
//  LanguageModelChatUI
//

import UIKit

class RightClickFinder: NSObject, UIContextMenuInteractionDelegate {
    private lazy var interaction = UIContextMenuInteraction(delegate: self)
    private var action: (() -> Void)?
    private var contextMenuActivationTime: CFTimeInterval = 0

    override init() {
        super.init()
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation _: CGPoint
    ) -> UIContextMenuConfiguration? {
        contextMenuActivationTime = CACurrentMediaTime()
        action?()
        return nil
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        willEndFor _: UIContextMenuConfiguration,
        animator _: UIContextMenuInteractionAnimating?
    ) {
        contextMenuActivationTime = 0
    }

    var isContextMenuActive: Bool {
        let timeSinceActivation = CACurrentMediaTime() - contextMenuActivationTime
        return contextMenuActivationTime > 0 && timeSinceActivation < 0.5
    }

    func install(on view: UIView, action: @escaping () -> Void) {
        assert(self.action == nil, "RightClickFinder can only be installed once")
        self.action = action
        view.isUserInteractionEnabled = true
        view.addInteraction(interaction)
    }
}
