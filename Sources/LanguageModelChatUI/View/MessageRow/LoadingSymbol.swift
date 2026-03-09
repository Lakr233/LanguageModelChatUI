//
//  LoadingSymbol.swift
//  LanguageModelChatUI
//

import UIKit

final class LoadingSymbol: UIView {
    var dotRadius: CGFloat = 2
    var spacing: CGFloat = 3
    var animationDuration: TimeInterval = 0.4
    var animationInterval: TimeInterval = 0.1

    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: dotRadius * 2 * 3 + spacing * 2, height: max(10, dotRadius * 2))
    }

    @objc
    private func step(_ link: CADisplayLink) {
        let duration = max(0.1, animationDuration)
        phase += CGFloat(link.duration / duration)
        if phase > 1 {
            phase -= floor(phase)
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(rect)

        let totalWidth = dotRadius * 2 * 3 + spacing * 2
        let originX = (rect.width - totalWidth) / 2

        for index in 0 ..< 3 {
            let delay = CGFloat(index) * CGFloat(animationInterval / max(0.1, animationDuration))
            let t = (phase - delay).truncatingRemainder(dividingBy: 1)
            let normalized = t < 0 ? t + 1 : t
            let offset = sin(normalized * .pi * 2) * dotRadius * 1.2
            let centerY = rect.midY + offset

            let x = originX + CGFloat(index) * (dotRadius * 2 + spacing)
            let dotRect = CGRect(x: x, y: centerY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            context.setFillColor(UIColor.label.cgColor)
            context.fillEllipse(in: dotRect)
        }
    }
}
