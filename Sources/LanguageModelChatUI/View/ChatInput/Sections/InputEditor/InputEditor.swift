//
//  InputEditor.swift
//  LanguageModelChatUI
//

import Combine
import UIKit

class InputEditor: EditorSectionView {
    let font = UIFont.preferredFont(forTextStyle: .body)
    let textHeight: CurrentValueSubject<CGFloat, Never> = .init(0)
    let maxTextEditorHeight: CGFloat = 200

    let elementClipper = UIView()

    let bossButton = IconButton(icon: "camera")
    let textView = TextEditorView()
    let placeholderLabel = UILabel()
    let voiceButton = IconButton(icon: "mic")
    let moreButton = IconButton(icon: "plus.circle")
    let sendButton = IconButton(icon: "send")

    let inset: UIEdgeInsets = .init(top: 10, left: 10, bottom: 10, right: 10)
    let iconSpacing: CGFloat = 10
    let iconSize = CGSize(width: 30, height: 30)

    var isControlPanelOpened: Bool = false {
        didSet { moreButton.change(icon: isControlPanelOpened ? "x.circle" : "plus.circle") }
    }

    enum LayoutStatus {
        case standard
        case preFocusText
        case editingText
    }

    var layoutStatus: LayoutStatus = .standard {
        didSet {
            guard oldValue != layoutStatus else { return }
            setNeedsLayout()
        }
    }

    /// Configuration injected from ChatInputView.
    var configuration: ChatInputConfiguration = .default

    weak var delegate: Delegate?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func initializeViews() {
        super.initializeViews()

        bossButton.tapAction = { [weak self] in
            self?.delegate?.onInputEditorCaptureButtonTapped()
        }
        addSubview(elementClipper)
        elementClipper.clipsToBounds = true
        elementClipper.addSubview(bossButton)
        textView.font = font
        textView.delegate = self
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.alwaysBounceVertical = false
        textView.alwaysBounceHorizontal = false
        textView.textColor = .label
        textView.textAlignment = .natural
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.textContainer.lineFragmentPadding = .zero
        textView.textContainer.maximumNumberOfLines = 0
        textView.clipsToBounds = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.onReturnKeyPressed = { [weak self] in
            guard let self else { return }
            textView.insertText("\n")
        }
        textView.onCommandReturnKeyPressed = { [weak self] in
            self?.sendButton.tapAction()
        }
        textView.onImagePasted = { [weak self] image in
            self?.delegate?.onInputEditorPastingImage(image: image)
        }
        elementClipper.addSubview(textView)
        placeholderLabel.text = String.localized("Type something...")
        placeholderLabel.font = font
        placeholderLabel.textColor = .placeholderText
        elementClipper.addSubview(placeholderLabel)
        voiceButton.tapAction = { [weak self] in
            self?.delegate?.onInputEditorMicButtonTapped()
        }
        elementClipper.addSubview(voiceButton)
        moreButton.tapAction = { [weak self] in
            self?.isControlPanelOpened.toggle()
            self?.setNeedsLayout()
            self?.delegate?.onInputEditorToggleMoreButtonTapped()
        }
        elementClipper.addSubview(moreButton)
        sendButton.tapAction = { [weak self] in
            self?.delegate?.onInputEditorSubmitButtonTapped()
        }
        elementClipper.addSubview(sendButton)

        textHeight.removeDuplicates()
            .compactMap { [weak self] textHeight -> CGFloat? in
                guard let self else { return nil }
                return max(textLayoutHeight(textHeight), iconSize.height)
                    + inset.top + inset.bottom
            }
            .ensureMainThread()
            .sink { [weak self] height in self?.heightPublisher.send(height) }
            .store(in: &cancellables)
        updateTextHeight()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        elementClipper.frame = bounds

        switch layoutStatus {
        case .standard:
            layoutAsStandard()
        case .preFocusText:
            layoutAsPreEditingText()
        case .editingText:
            layoutAsEditingText()
        }

        updatePlaceholderAlpha()
    }

    func set(text: String) {
        textView.text = text
        updatePlaceholderAlpha()
        switchToRequiredStatus()
        updateTextHeight()
    }
}
