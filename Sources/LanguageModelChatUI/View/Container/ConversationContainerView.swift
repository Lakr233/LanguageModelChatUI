//
//  ConversationContainerView.swift
//  LanguageModelChatUI
//
//  The main embeddable chat view. Manages a message list and input editor.
//

import SnapKit
import UIKit

/// The main chat container view that third-party apps embed.
///
/// Usage:
///
///     let container = ConversationContainerView()
///     container.load(conversationID: "conv-1", sessionConfiguration: configuration)
///     parentView.addSubview(container)
///
open class ConversationContainerView: UIView {
    private var draftInputObject: ChatInputContent?
    public var conversationModels: ConversationSession.Models = .init()

    public let messageListView = MessageListView()
    public let chatInputView = ChatInputView()

    public var inputConfiguration: ChatInputConfiguration {
        get { chatInputView.configuration }
        set { chatInputView.configuration = newValue }
    }

    public init() {
        super.init(frame: .zero)
        setupUI()
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setupUI() {
        backgroundColor = .clear
        addSubview(messageListView)
        addSubview(chatInputView)
        chatInputView.delegate = self

        chatInputView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(keyboardLayoutGuide.snp.top)
        }

        messageListView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(chatInputView.snp.top)
        }
    }

    /// Load a conversation by ID. This sets up the message list and session.
    public func load(
        conversationID: String,
        models: ConversationSession.Models = .init(),
        sessionConfiguration: ConversationSession.Configuration
    ) {
        conversationModels = models
        let session = ConversationSessionManager.shared.session(for: conversationID, configuration: sessionConfiguration)
        applyConversationModels(models, to: session)
        messageListView.session = session
        chatInputView.bind(conversationID: conversationID)
    }
}

extension ConversationContainerView: ChatInputDelegate {
    public func chatInputDidSubmit(_ input: ChatInputView, object: ChatInputContent, completion: @escaping @Sendable (Bool) -> Void) {
        _ = input
        guard let session = messageListView.session else {
            completion(false)
            return
        }
        guard let model = session.models.chat else {
            completion(false)
            return
        }
        let userInput = makeUserInput(from: object)
        draftInputObject = nil
        session.runInference(model: model, messageListView: messageListView, input: userInput) {
            completion(true)
        }
    }

    public func chatInputDidUpdateObject(_: ChatInputView, object: ChatInputContent) {
        draftInputObject = object
    }

    public func chatInputDidRequestObjectForRestore(_: ChatInputView) -> ChatInputContent? {
        draftInputObject
    }

    public func chatInputDidReportError(_: ChatInputView, error: String) {
        guard let viewController = parentViewController else { return }
        let alert = UIAlertController(title: String.localized("Error"), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("OK"), style: .default))
        viewController.present(alert, animated: true)
    }

    private var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}
