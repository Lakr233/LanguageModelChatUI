//
//  Created by ktiays on 2025/2/11.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import MarkdownView
import UIKit

final class HintMessageView: MessageListRowView {
    private lazy var label: UILabel = .init()
    var text: String? {
        set { label.text = newValue }
        get { label.text }
    }

    override var theme: MarkdownTheme {
        didSet { updateLabelStyle() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.textAlignment = .center
        label.alpha = 0.5
        updateLabelStyle()
        contentView.addSubview(label)
    }

    @available(*, unavailable)
    @MainActor required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateLabelStyle() {
        label.textColor = theme.colors.body
        label.font = theme.fonts.footnote
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        label.frame = contentView.bounds.insetBy(dx: 8, dy: 8)
    }
}
