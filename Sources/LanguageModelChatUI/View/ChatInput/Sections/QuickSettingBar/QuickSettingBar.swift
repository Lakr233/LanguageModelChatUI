//
//  QuickSettingBar.swift
//  LanguageModelChatUI
//

import UIKit

class QuickSettingBar: EditorSectionView {
    let scrollView = UIScrollView()

    private var buttons: [BlockButton] = []
    private var items: [QuickSettingItem] = []

    weak var delegate: Delegate?

    var computedHeight: CGFloat {
        if isOpen {
            buttons.filter { !$0.isHidden }.map(\.intrinsicContentSize.height).max() ?? 0
        } else {
            0
        }
    }

    var isOpen = true {
        didSet {
            heightPublisher.send(computedHeight)
            doEditorLayoutAnimation { self.setNeedsLayout() }
        }
    }

    override func initializeViews() {
        super.initializeViews()

        scrollView.clipsToBounds = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        addSubview(scrollView)

        heightPublisher.send(computedHeight)
    }

    func configure(with items: [QuickSettingItem]) {
        self.items = items

        // Remove old buttons
        for button in buttons {
            button.removeFromSuperview()
        }
        buttons.removeAll()

        // Create new buttons
        for item in items {
            switch item {
            case let .toggle(_, title, icon, isOn, onChange):
                let button = ToggleBlockButton(text: title, icon: icon)
                button.isOn = isOn
                button.onValueChanged = { [weak button, weak self] in
                    guard let button else { return }
                    onChange(button.isOn)
                    self?.delegate?.quickSettingBarOnValueChanged()
                }
                scrollView.addSubview(button)
                buttons.append(button)

            case let .menu(_, title, icon, menuProvider):
                let button = BlockButton(text: title, icon: icon)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [
                    UIDeferredMenuElement.uncached { completion in
                        let elements = menuProvider()
                        completion(elements)
                    },
                ])
                button.actionBlock = {}
                scrollView.addSubview(button)
                buttons.append(button)
            }
        }

        if items.isEmpty {
            isOpen = false
        } else {
            heightPublisher.send(computedHeight)
            setNeedsLayout()
        }
    }

    func updateToggle(id: String, isOn: Bool) {
        for (index, item) in items.enumerated() {
            if case let .toggle(itemId, _, _, _, _) = item, itemId == id {
                if let button = buttons[safe: index] as? ToggleBlockButton {
                    button.isOn = isOn
                }
                break
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        defer {
            let contentSizeWidth = scrollView.contentSize.width
            if contentSizeWidth < bounds.width {
                scrollView.frame = .init(
                    x: (bounds.width - contentSizeWidth) / 2,
                    y: 0,
                    width: contentSizeWidth,
                    height: bounds.height
                )
            }
        }

        alpha = isOpen ? 1 : 0
        guard isOpen else { return }

        buttons.forEach { $0.transform = .identity }
        let visibleButtons = buttons.filter { !$0.isHidden }
        let sizes = visibleButtons.map(\.intrinsicContentSize)

        var anchorX: CGFloat = horizontalAdjustment
        for (index, button) in visibleButtons.enumerated() {
            let size = sizes[index]
            button.frame = .init(
                x: anchorX,
                y: 0,
                width: size.width,
                height: size.height
            )
            anchorX += size.width + 10
        }

        let lastOne = visibleButtons.last?.frame.maxX ?? 0
        let contentSizeWidth = lastOne + horizontalAdjustment
        scrollView.contentSize = .init(width: contentSizeWidth, height: bounds.height)
    }

    func hide() {
        isOpen = false
    }

    func show() {
        isOpen = !items.isEmpty
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
