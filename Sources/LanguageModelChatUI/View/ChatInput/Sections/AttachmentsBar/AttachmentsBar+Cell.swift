//
//  AttachmentsBar+Cell.swift
//  LanguageModelChatUI
//

import UIKit

extension AttachmentsBar {
    class AttachmentsImageCell: UICollectionViewCell {
        let contentContainer = UIView()
        let iconView = UIImageView()

        let deleteButton = DeleteButton()
        let deleteButtonSize: CGFloat = 20
        let deleteButtonInset: CGFloat = 4

        var isDeletable: Bool = true {
            didSet { setNeedsLayout() }
        }

        var item: Item?

        var attachmentBarView: AttachmentsBar? {
            var view: UIView = self
            while !(view is AttachmentsBar) {
                guard let nextView = view.superview else { break }
                view = nextView
            }
            return view as? AttachmentsBar
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentContainer.clipsToBounds = true
            contentContainer.layer.cornerRadius = 10
            contentContainer.layer.cornerCurve = .continuous
            contentContainer.backgroundColor = .gray.withAlphaComponent(0.1)
            contentView.addSubview(contentContainer)

            iconView.contentMode = .scaleAspectFill
            contentContainer.addSubview(iconView)

            contentContainer.addSubview(deleteButton)

            deleteButton.actionBlock = { [weak self] in
                self?.attachmentBarView?.delete(itemIdentifier: self?.item?.id)
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            contentContainer.frame = contentView.bounds
            iconView.frame = contentView.bounds
            deleteButton.isHidden = !isDeletable
            deleteButton.frame = .init(
                x: bounds.width - deleteButtonInset - deleteButtonSize,
                y: deleteButtonInset,
                width: deleteButtonSize,
                height: deleteButtonSize
            )
        }

        func configure(item: Item) {
            self.item = item
            iconView.image = .init(data: item.previewImageData)
        }
    }
}

extension AttachmentsBar {
    class AttachmentsTextCell: UICollectionViewCell {
        let contentContainer = UIView()
        let nameLabel = UILabel()
        let textLabel = UILabel()

        let deleteButton = DeleteButton()
        let iconSize: CGFloat = 20
        let inset: CGFloat = 4

        var item: Item?

        var isDeletable: Bool = true {
            didSet { setNeedsLayout() }
        }

        var attachmentBarView: AttachmentsBar? {
            var view: UIView = self
            while !(view is AttachmentsBar) {
                guard let nextView = view.superview else { break }
                view = nextView
            }
            return view as? AttachmentsBar
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentContainer.clipsToBounds = true
            contentContainer.layer.cornerRadius = 10
            contentContainer.layer.cornerCurve = .continuous
            contentContainer.backgroundColor = .gray.withAlphaComponent(0.1)
            contentView.addSubview(contentContainer)

            nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            nameLabel.textColor = .label
            nameLabel.numberOfLines = 1
            nameLabel.textAlignment = .left
            nameLabel.lineBreakMode = .byTruncatingTail
            contentContainer.addSubview(nameLabel)

            textLabel.font = .systemFont(ofSize: 12, weight: .regular)
            textLabel.textColor = .secondaryLabel
            textLabel.contentMode = .topLeft
            textLabel.numberOfLines = 0
            textLabel.textAlignment = .left
            textLabel.lineBreakMode = .byTruncatingTail
            contentContainer.addSubview(textLabel)

            contentContainer.addSubview(deleteButton)

            deleteButton.actionBlock = { [weak self] in
                self?.attachmentBarView?.delete(itemIdentifier: self?.item?.id)
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            contentContainer.frame = contentView.bounds
            nameLabel.frame = .init(
                x: inset,
                y: inset,
                width: bounds.width - inset * 3 - (isDeletable ? iconSize : 0),
                height: iconSize
            )
            deleteButton.isHidden = !isDeletable
            deleteButton.frame = .init(
                x: bounds.width - inset - iconSize,
                y: inset,
                width: iconSize,
                height: iconSize
            )
            textLabel.frame = .init(
                x: inset,
                y: nameLabel.frame.maxY + inset,
                width: bounds.width - inset * 2,
                height: bounds.height - nameLabel.frame.maxY - inset * 2
            )
        }

        func configure(item: Item) {
            self.item = item
            nameLabel.text = item.name
            var text = item.textContent.replacingOccurrences(of: "\n", with: " ")
            if text.count > 500 { text = String(text.prefix(500)) }
            textLabel.text = text
        }
    }
}

extension AttachmentsBar {
    class AttachmentsAudioCell: AttachmentsTextCell, UIGestureRecognizerDelegate {
        private lazy var quickLookTap: UITapGestureRecognizer = {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            gesture.cancelsTouchesInView = true
            gesture.delegate = self
            return gesture
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentContainer.isUserInteractionEnabled = true
            contentContainer.addGestureRecognizer(quickLookTap)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError()
        }

        override func configure(item: Item) {
            super.configure(item: item)
            textLabel.text = item.textContent
        }

        func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if touch.view?.isDescendant(of: deleteButton) == true {
                return false
            }
            return true
        }

        @objc private func handleTap() {
            guard let item else { return }
            contentView.puddingAnimate()
            attachmentBarView?.presentPreview(for: item)
        }
    }
}
