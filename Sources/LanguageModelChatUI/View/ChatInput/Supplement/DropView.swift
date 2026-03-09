//
//  DropView.swift
//  LanguageModelChatUI
//

import UIKit

class DropView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else {
            return super.hitTest(point, with: event)
        }
        return if let event,
                  NSStringFromClass(type(of: event)) == "UIDragEvent",
                  bounds.contains(point)
        { self } else { nil }
    }
}
