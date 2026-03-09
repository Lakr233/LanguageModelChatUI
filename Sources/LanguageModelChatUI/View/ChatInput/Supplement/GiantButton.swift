//
//  GiantButton.swift
//  LanguageModelChatUI
//

import UIKit

class GiantButton: UIView {
    let imageView = UIImageView()
    let backgroundView = UIView()
    let labelView = UILabel()

    var actionBlock: () -> Void = {}

    init(title: String, icon: String) {
        super.init(frame: .zero)

        backgroundView.backgroundColor = .label.withAlphaComponent(0.05)
        backgroundView.layer.cornerRadius = 16
        backgroundView.layer.cornerCurve = .continuous
        addSubview(backgroundView)

        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label.withAlphaComponent(0.75)
        imageView.image = UIImage.chatInputIcon(named: icon)
        backgroundView.addSubview(imageView)

        labelView.text = title
        labelView.textAlignment = .center
        labelView.font = .preferredFont(forTextStyle: .footnote)
        labelView.textColor = .secondaryLabel
        addSubview(labelView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onTapped))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labelHeight: CGFloat = 32

        backgroundView.frame = .init(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - labelHeight
        )
        let imageSize = CGSize(width: 28, height: 28)
        imageView.frame = .init(
            x: (backgroundView.bounds.width - imageSize.width) / 2,
            y: (backgroundView.bounds.height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        labelView.frame = .init(
            x: 0,
            y: backgroundView.frame.maxY,
            width: bounds.width,
            height: labelHeight
        )
    }

    @objc private func onTapped() {
        puddingAnimate()
        actionBlock()
    }
}
