//
//  ChatTitleView.swift
//  LanguageModelChatUI
//

import GlyphixTextFx
import UIKit

final class ChatTitleView: UIView {
    private let horizontalPadding: CGFloat = 18
    private let verticalPadding: CGFloat = 4

    let textLabel: GlyphixTextLabel = .init().with {
        $0.font = .preferredFont(forTextStyle: .body).bold
        $0.isBlurEffectEnabled = false
        $0.textColor = .label
        $0.textAlignment = .center
        $0.lineBreakMode = .byTruncatingTail
        $0.numberOfLines = 1
        $0.clipsToBounds = false
    }

    var titleText: String? {
        didSet {
            doWithAnimation(duration: 0.2) {
                self.textLabel.text = self.titleText
            }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(textLabel)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let labelSize = textLabel.intrinsicContentSize
        return CGSize(
            width: max(labelSize.width + horizontalPadding * 2, 96),
            height: max(labelSize.height + verticalPadding * 2, 36)
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textLabel.frame = bounds.insetBy(dx: horizontalPadding, dy: verticalPadding)
    }
}
