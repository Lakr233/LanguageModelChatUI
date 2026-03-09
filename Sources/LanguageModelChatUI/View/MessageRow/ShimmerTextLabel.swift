//
//  ShimmerTextLabel.swift
//  LanguageModelChatUI
//

import UIKit

final class ShimmerTextLabel: UILabel {
    private let gradientLayer = CAGradientLayer()
    private var originalTextColor: UIColor?
    private var isShimmering = false

    var animationDuration: TimeInterval = 1.6

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard isShimmering else { return }
        gradientLayer.frame = bounds
        gradientLayer.mask?.frame = bounds
    }

    func startShimmer() {
        guard !isShimmering else { return }
        isShimmering = true
        originalTextColor = textColor
        textColor = .clear

        gradientLayer.colors = [
            UIColor.label.withAlphaComponent(0.35).cgColor,
            UIColor.label.cgColor,
            UIColor.label.withAlphaComponent(0.35).cgColor,
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.frame = bounds
        layer.addSublayer(gradientLayer)

        let mask = CATextLayer()
        mask.contentsScale = UIScreen.main.scale
        mask.string = attributedText ?? NSAttributedString(string: text ?? "", attributes: [.font: font as Any])
        mask.frame = bounds
        mask.alignmentMode = .left
        gradientLayer.mask = mask

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1, -0.5, 0]
        animation.toValue = [1, 1.5, 2]
        animation.duration = animationDuration
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "shimmer")
    }

    func stopShimmer() {
        isShimmering = false
        gradientLayer.removeAllAnimations()
        gradientLayer.removeFromSuperlayer()
        gradientLayer.mask = nil
        textColor = originalTextColor ?? .label
    }
}
