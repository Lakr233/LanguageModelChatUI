//
//  EditorSectionView.swift
//  LanguageModelChatUI
//

import Combine
import UIKit

@MainActor
open class EditorSectionView: UIView {
    let heightPublisher: CurrentValueSubject<CGFloat, Never> = .init(0)
    var cancellables: Set<AnyCancellable> = .init()

    var horizontalAdjustment: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    public required init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        clipsToBounds = false
        layer.masksToBounds = false

        initializeViews()

        for view in subviews {
            guard let view = view as? EditorSectionView else { continue }
            view.heightPublisher
                .removeDuplicates()
                .ensureMainThread()
                .sink { [weak self] _ in self?.subviewHeightDidChanged() }
                .store(in: &cancellables)
        }
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError()
    }

    func initializeViews() {
        setNeedsLayout()
    }

    func subviewHeightDidChanged() {
        setNeedsLayout()
        layoutIfNeeded()
    }

    var owningChatInputView: ChatInputView? {
        var look: UIView? = self
        while let current = look {
            if let inputView = current as? ChatInputView {
                return inputView
            }
            look = current.superview
        }
        return nil
    }

    func doEditorLayoutAnimation(
        duration: TimeInterval = 0.5,
        _ execute: @escaping () -> Void,
        completion: @escaping () -> Void = {}
    ) {
        if let owningChatInputView {
            owningChatInputView.doCoordinatedLayoutAnimation(duration: duration, execute, completion: completion)
        } else {
            doWithAnimation(duration: duration, execute, completion: completion)
        }
    }
}
