//
//  Created by ktiays on 2025/2/28.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import UIKit

final class ToolHintView: MessageListRowView {
    var text: String?

    var toolName: String = .init()

    var state: ToolCallState = .running {
        didSet {
            updateContentText()
            updateStateImage()
        }
    }

    var clickHandler: (() -> Void)?

    private let backgroundGradientLayer = CAGradientLayer()
    private let label: ShimmerTextLabel = .init().with {
        $0.font = UIFont.preferredFont(forTextStyle: .body)
        $0.textColor = .label
        $0.minimumScaleFactor = 0.5
        $0.adjustsFontForContentSizeCategory = true
        $0.lineBreakMode = .byTruncatingTail
        $0.numberOfLines = 1
        $0.adjustsFontSizeToFitWidth = true
        $0.textAlignment = .left
        $0.animationDuration = 1.6
    }

    private let symbolView: UIImageView = .init().with {
        $0.contentMode = .scaleAspectFit
    }

    private let decoratedView: UIImageView = .init(image: .init(named: "tools"))
    private var isClickable: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        decoratedView.contentMode = .scaleAspectFit
        decoratedView.tintColor = .label

        backgroundGradientLayer.startPoint = .init(x: 0.6, y: 0)
        backgroundGradientLayer.endPoint = .init(x: 0.4, y: 1)

        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous
        contentView.layer.insertSublayer(backgroundGradientLayer, at: 0)
        contentView.addSubview(decoratedView)
        contentView.addSubview(symbolView)
        contentView.addSubview(label)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        contentView.addGestureRecognizer(tapGesture)

        updateStateImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labelSize = label.intrinsicContentSize

        symbolView.frame = .init(
            x: 12,
            y: (contentView.bounds.height - labelSize.height) / 2,
            width: labelSize.height, // 1:1
            height: labelSize.height
        )

        label.frame = .init(
            x: symbolView.frame.maxX + 8,
            y: (contentView.bounds.height - labelSize.height) / 2,
            width: labelSize.width,
            height: labelSize.height
        )

        contentView.frame.size.width = label.frame.maxX + 18
        decoratedView.frame = .init(x: contentView.bounds.width - 12, y: -4, width: 16, height: 16)
        backgroundGradientLayer.frame = contentView.bounds
        backgroundGradientLayer.cornerRadius = contentView.layer.cornerRadius
    }

    override func themeDidUpdate() {
        super.themeDidUpdate()
        label.font = theme.fonts.body
    }

    private func updateStateImage() {
        let configuration = UIImage.SymbolConfiguration(scale: .small)
        switch state {
        case .succeeded:
            backgroundGradientLayer.colors = [
                UIColor.systemGreen.withAlphaComponent(0.08).cgColor,
                UIColor.systemGreen.withAlphaComponent(0.12).cgColor,
            ]
            let image = UIImage(systemName: "checkmark.seal", withConfiguration: configuration)
            symbolView.image = image
            symbolView.tintColor = .systemGreen
            label.stopShimmer()
        case .running:
            backgroundGradientLayer.colors = [
                UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.12).cgColor,
            ]
            let image = UIImage(systemName: "hourglass", withConfiguration: configuration)
            symbolView.image = image
            symbolView.tintColor = .systemBlue
            label.startShimmer()
        case .failed:
            backgroundGradientLayer.colors = [
                UIColor.systemRed.withAlphaComponent(0.08).cgColor,
                UIColor.systemRed.withAlphaComponent(0.12).cgColor,
            ]
            let image = UIImage(systemName: "xmark.seal", withConfiguration: configuration)
            symbolView.image = image
            symbolView.tintColor = .systemRed
            label.stopShimmer()
        }
        invalidateLayout()
    }

    private func updateContentText() {
        switch state {
        case .running:
            isClickable = false
            label.text = String.localized("Tool call for \(toolName) running")
        case .succeeded:
            isClickable = true
            label.text = String.localized("Tool call for \(toolName) completed.")
        case .failed:
            isClickable = true
            label.text = String.localized("Tool call for \(toolName) failed.")
        }
        invalidateLayout()
    }

    func invalidateLayout() {
        label.invalidateIntrinsicContentSize()
        label.sizeToFit()
        setNeedsLayout()

        doWithAnimation {
            self.layoutIfNeeded()
        }
    }

    @objc
    private func handleTap(_ sender: UITapGestureRecognizer) {
        if isClickable, sender.state == .ended {
            clickHandler?()
        }
    }
}
