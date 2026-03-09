//
//  ControlPanel.swift
//  LanguageModelChatUI
//

import Combine
import UIKit

class ControlPanel: EditorSectionView {
    let isPanelOpen: CurrentValueSubject<Bool, Never> = .init(false)

    let buttonHeight: CGFloat = 100
    let buttonSpacing: CGFloat = 10

    private var buttonViews: [GiantButton] = []
    private var items: [ControlPanelItem] = []

    weak var delegate: Delegate?

    override func initializeViews() {
        super.initializeViews()

        isPanelOpen
            .removeDuplicates()
            .ensureMainThread()
            .sink { [weak self] input in
                guard let self else { return }
                heightPublisher.send(input ? buttonHeight : 0)
                if input {
                    delegate?.onControlPanelOpen()
                } else {
                    delegate?.onControlPanelClose()
                }
            }
            .store(in: &cancellables)
    }

    func configure(with items: [ControlPanelItem]) {
        self.items = items

        for view in buttonViews {
            view.removeFromSuperview()
        }
        buttonViews.removeAll()

        for item in items {
            let button = GiantButton(title: item.title, icon: item.icon)
            button.alpha = 0
            button.actionBlock = { [weak self] in
                guard let self else { return }
                switch item.id {
                case "camera":
                    delegate?.onControlPanelCameraButtonTapped()
                case "photo":
                    delegate?.onControlPanelPickPhotoButtonTapped()
                case "file":
                    delegate?.onControlPanelPickFileButtonTapped()
                case "web":
                    delegate?.onControlPanelRequestWebScrubber()
                default:
                    item.action()
                }
                close()
            }
            addSubview(button)
            buttonViews.append(button)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard !buttonViews.isEmpty else { return }
        let buttonWidth = ceil(bounds.width + buttonSpacing) / CGFloat(buttonViews.count) - buttonSpacing
        for (idx, view) in buttonViews.enumerated() {
            view.frame = .init(
                x: CGFloat(idx) * (buttonWidth + buttonSpacing),
                y: 0,
                width: buttonWidth,
                height: buttonHeight
            )
            view.alpha = isPanelOpen.value ? 1 : 0
        }
    }

    func toggle() {
        doEditorLayoutAnimation { [self] in isPanelOpen.send(!isPanelOpen.value) }
    }

    func close() {
        guard isPanelOpen.value else { return }
        toggle()
    }
}
