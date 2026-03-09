//
//  UIView+Animation.swift
//  LanguageModelChatUI
//

import UIKit

extension UIView {
    func doWithAnimation(duration: TimeInterval = 0.5, _ execute: @escaping () -> Void, completion: @escaping () -> Void = {}) {
        layoutIfNeeded()
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 1.0,
            options: .curveEaseInOut
        ) {
            execute()
            self.layoutIfNeeded()
        } completion: { _ in
            completion()
        }
    }

    func puddingAnimate() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        transform = CGAffineTransform(scaleX: 0.975, y: 0.975)
        layoutIfNeeded()
        doWithAnimation { self.transform = .identity }
    }

    var nearestScrollView: UIScrollView? {
        var look: UIView = self
        while let superview = look.superview {
            look = superview
            if let scrollView = superview as? UIScrollView {
                return scrollView
            }
        }
        return nil
    }
}
