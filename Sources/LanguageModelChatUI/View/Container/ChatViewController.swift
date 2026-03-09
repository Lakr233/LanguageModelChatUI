//
//  ChatViewController.swift
//  LanguageModelChatUI
//

import Combine
import UIKit

/// A complete chat view controller that provides message display and user input.
///
/// Usage:
///
///     let vc = ChatViewController(conversationID: "conv-1", sessionConfiguration: configuration)
///     present(vc, animated: true)
///
open class ChatViewController: UIViewController {
    private enum Layout {
        static let topBarHorizontalInset: CGFloat = 16
        static let topBarTopSpacing: CGFloat = 12
        static let topBarBottomSpacing: CGFloat = 14
        static let topBarTouchSize: CGFloat = 44
        static let topBarTitleSpacing: CGFloat = 16
        static let topBarDividerHeight: CGFloat = 1
        static let topBarAvatarSize: CGFloat = 24
    }

    public let conversationID: String
    public let conversationModels: ConversationSession.Models
    public let sessionConfiguration: ConversationSession.Configuration
    public var configuration: Configuration

    /// When `true`, the controller assumes it is embedded inside a
    /// `UINavigationController` and hides its own top bar, instead
    /// placing the title in the navigation bar (always inline/compact)
    /// and moving the menu to a toolbar bar-button item.
    public var prefersNavigationBarManaged: Bool = false {
        didSet {
            guard isViewLoaded else { return }
            applyNavigationBarManagedMode()
        }
    }

    public var inputConfiguration: ChatInputConfiguration {
        get { configuration.input }
        set {
            configuration.input = newValue
            chatInputView.configuration = newValue
        }
    }

    public private(set) var chatInputView = ChatInputView()
    public private(set) var messageListView = MessageListView()
    public weak var menuDelegate: ChatViewControllerMenuDelegate? {
        didSet {
            guard isViewLoaded else { return }
            configureNavigationItems()
        }
    }

    private let topBarBackgroundView = UIView()
    private let topBarBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    private let topBarDividerView = SeparatorView()
    private let topBarContentView = UIView()
    private let titleAvatarContainerView = UIView()
    private let titleAvatarView = UIImageView()
    private lazy var menuButton: UIButton = .init(type: .system)
    private let navigationTitleView = ChatTitleView()
    private weak var currentSession: ConversationSession?
    private var resolvedTitleMetadata: ConversationTitleMetadata = .init(title: String.localized("Chat"))
    private lazy var dismissKeyboardTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapToDismiss))
        gesture.cancelsTouchesInView = false
        return gesture
    }()

    private var cancellables = Set<AnyCancellable>()
    private var keyboardHeight: CGFloat = 0

    private var draftInputObject: ChatInputContent?

    public init(
        conversationID: String = UUID().uuidString,
        models: ConversationSession.Models = .init(),
        sessionConfiguration: ConversationSession.Configuration = .init(storage: DisposableStorageProvider.shared),
        configuration: Configuration = .init()
    ) {
        self.conversationID = conversationID
        conversationModels = models
        self.sessionConfiguration = sessionConfiguration
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
        chatInputView.configuration = self.configuration.input
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()

        view.backgroundColor = .systemBackground
        topBarBackgroundView.backgroundColor = .clear

        configureTopBarViews()

        view.addSubview(topBarBackgroundView)
        view.addSubview(messageListView)
        view.addSubview(chatInputView)
        messageListView.addGestureRecognizer(dismissKeyboardTapGesture)
        messageListView.theme = configuration.messageTheme

        let session = ConversationSessionManager.shared.session(for: conversationID, configuration: sessionConfiguration)
        applyConversationModels(conversationModels, to: session)
        currentSession = session
        messageListView.session = session
        chatInputView.delegate = self
        chatInputView.bind(conversationID: conversationID)
        configureNavigationItems()
        bindNavigationTitleUpdates(session: session)
        refreshNavigationTitle()

        setupKeyboardObservation()
        setupInputHeightObservation()

        applyNavigationBarManagedMode()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutViews()
    }

    private func layoutViews() {
        let safeArea = view.safeAreaInsets
        let inputHeight = chatInputView.heightPublisher.value
        let bottomPadding = max(safeArea.bottom, 0)
        let topBarHeight = layoutTopBar(safeAreaTop: safeArea.top)
        let inputExtension = bottomPadding
        let totalInputHeight = inputHeight + inputExtension

        chatInputView.bottomBackgroundExtension = inputExtension

        let inputY = view.bounds.height - totalInputHeight - keyboardHeight
        chatInputView.frame = CGRect(
            x: 0,
            y: max(inputY, safeArea.top),
            width: view.bounds.width,
            height: totalInputHeight
        )

        if prefersNavigationBarManaged {
            // Extend the list view behind the translucent navigation bar.
            // Content is offset via contentSafeAreaInsets so it starts below the bar,
            // but scrolls underneath it for the glass morphism effect.
            messageListView.frame = CGRect(
                x: 0,
                y: 0,
                width: view.bounds.width,
                height: chatInputView.frame.minY
            )
            messageListView.contentSafeAreaInsets = UIEdgeInsets(
                top: safeArea.top,
                left: 0,
                bottom: 0,
                right: 0
            )
        } else {
            messageListView.frame = CGRect(
                x: 0,
                y: topBarHeight,
                width: view.bounds.width,
                height: chatInputView.frame.minY - topBarHeight
            )
            messageListView.contentSafeAreaInsets = .zero
        }
    }

    @discardableResult
    private func layoutTopBar(safeAreaTop: CGFloat) -> CGFloat {
        if prefersNavigationBarManaged {
            topBarBackgroundView.frame = .zero
            return safeAreaTop
        }
        let contentY = safeAreaTop + Layout.topBarTopSpacing
        let contentHeight = max(Layout.topBarTouchSize, navigationTitleView.intrinsicContentSize.height)
        let iconSide = Layout.topBarAvatarSize

        topBarContentView.frame = CGRect(
            x: 0,
            y: contentY,
            width: view.bounds.width,
            height: contentHeight
        )

        topBarBackgroundView.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: topBarContentView.frame.maxY + Layout.topBarBottomSpacing
        )
        topBarBlurView.frame = topBarBackgroundView.bounds
        topBarDividerView.frame = CGRect(
            x: 0,
            y: topBarBackgroundView.bounds.height - Layout.topBarDividerHeight,
            width: topBarBackgroundView.bounds.width,
            height: Layout.topBarDividerHeight
        )

        let avatarY = (contentHeight - iconSide) / 2
        titleAvatarContainerView.frame = CGRect(
            x: Layout.topBarHorizontalInset,
            y: 0,
            width: Layout.topBarTouchSize,
            height: contentHeight
        )
        titleAvatarView.frame = CGRect(x: 0, y: avatarY, width: iconSide, height: iconSide)
        let menuY = (contentHeight - Layout.topBarTouchSize) / 2
        menuButton.frame = CGRect(
            x: topBarContentView.bounds.width - Layout.topBarHorizontalInset - Layout.topBarTouchSize,
            y: menuY,
            width: Layout.topBarTouchSize,
            height: Layout.topBarTouchSize
        )

        let titleSize = navigationTitleView.intrinsicContentSize
        let leadingReservedWidth = titleAvatarContainerView.frame.maxX + Layout.topBarTitleSpacing
        let trailingReservedWidth = topBarContentView.bounds.width - menuButton.frame.minX + Layout.topBarTitleSpacing
        let symmetricReservedWidth = max(leadingReservedWidth, trailingReservedWidth)
        let availableWidth = max(0, topBarContentView.bounds.width - symmetricReservedWidth * 2)
        let titleWidth = min(titleSize.width, availableWidth)
        let titleHeight = min(contentHeight, titleSize.height)

        navigationTitleView.frame = CGRect(
            x: (topBarContentView.bounds.width - titleWidth) / 2,
            y: (contentHeight - titleHeight) / 2,
            width: titleWidth,
            height: titleHeight
        )

        return topBarBackgroundView.frame.maxY
    }

    private func setupKeyboardObservation() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .sink { [weak self] frame in
                guard let self else { return }
                let converted = view.convert(frame, from: nil)
                keyboardHeight = max(view.bounds.height - converted.minY - view.safeAreaInsets.bottom, 0)
                UIView.animate(withDuration: 0.25) {
                    self.layoutViews()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.keyboardHeight = 0
                UIView.animate(withDuration: 0.25) {
                    self?.layoutViews()
                }
            }
            .store(in: &cancellables)
    }

    @objc private func handleBackgroundTapToDismiss() {
        view.endEditing(true)
    }

    private func setupInputHeightObservation() {
        chatInputView.heightPublisher
            .removeDuplicates()
            .sink { [weak self] _ in
                UIView.animate(withDuration: 0.2) {
                    self?.layoutViews()
                }
            }
            .store(in: &cancellables)
    }

    private func configureNavigationItems() {
        if prefersNavigationBarManaged {
            // In managed mode, title and menu live in the navigation bar.
            navigationItem.title = resolvedTitleMetadata.title
            navigationItem.largeTitleDisplayMode = .inline

            if let menu = menuDelegate?.chatViewControllerMenu(self) {
                let barButton = UIBarButtonItem(
                    image: UIImage(systemName: "ellipsis.circle"),
                    menu: menu
                )
                navigationItem.rightBarButtonItem = barButton
            } else {
                navigationItem.rightBarButtonItem = nil
            }

            // Hide the custom top bar menu button since nav bar owns it now.
            menuButton.isHidden = true
        } else {
            navigationItem.titleView = nil
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil

            if let menu = menuDelegate?.chatViewControllerMenu(self) {
                menuButton.menu = menu
                menuButton.isHidden = false
            } else {
                menuButton.menu = nil
                menuButton.isHidden = true
            }
        }

        if isViewLoaded {
            view.setNeedsLayout()
        }
    }

    private func applyNavigationBarManagedMode() {
        let managed = prefersNavigationBarManaged
        topBarBackgroundView.isHidden = managed
        if managed {
            navigationItem.largeTitleDisplayMode = .inline
            if let nav = navigationController {
                nav.navigationBar.prefersLargeTitles = false
            }
        }
        configureNavigationItems()
        view.setNeedsLayout()
    }

    private func bindNavigationTitleUpdates(session: ConversationSession) {
        session.messagesDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.refreshNavigationTitle()
            }
            .store(in: &cancellables)
    }

    private func resolveTitle(from metadata: ConversationTitleMetadata?) -> String {
        guard currentSession != nil else { return String.localized("Chat") }
        if let storedTitle = metadata?.title {
            let normalized = storedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, normalized != "Untitled" else { return String.localized("Chat") }
            return storedTitle
        }
        return String.localized("Chat")
    }

    private func refreshNavigationTitle() {
        let storedTitleMetadata = ConversationTitleMetadata(storageValue: currentSession?.storageProvider.title(for: conversationID))
        let resolvedTitle = resolveTitle(from: storedTitleMetadata)

        resolvedTitleMetadata = .init(title: resolvedTitle, avatar: storedTitleMetadata?.avatar ?? ConversationTitleMetadata.defaultAvatar)
        titleAvatarView.image = resolvedTitleMetadata.avatar.emojiImage(canvasSize: 128)
        navigationTitleView.titleText = resolvedTitleMetadata.title
        if prefersNavigationBarManaged {
            navigationItem.title = resolvedTitleMetadata.title
        }
        if isViewLoaded {
            view.setNeedsLayout()
        }
    }

    private func configureTopBarViews() {
        topBarBackgroundView.clipsToBounds = true
        topBarBlurView.isUserInteractionEnabled = false
        topBarContentView.backgroundColor = .clear

        titleAvatarContainerView.isUserInteractionEnabled = false
        titleAvatarView.contentMode = .scaleAspectFit
        titleAvatarView.image = resolvedTitleMetadata.avatar.emojiImage(canvasSize: 128)

        menuButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        menuButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold),
            forImageIn: .normal
        )
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.tintColor = UIColor.secondaryLabel.withAlphaComponent(0.5)
        menuButton.imageView?.contentMode = .scaleAspectFit
        menuButton.contentHorizontalAlignment = .right
        menuButton.contentVerticalAlignment = .center
        menuButton.isHidden = true

        topBarBackgroundView.addSubview(topBarBlurView)
        topBarBackgroundView.addSubview(topBarDividerView)
        topBarBackgroundView.addSubview(topBarContentView)
        topBarContentView.addSubview(titleAvatarContainerView)
        titleAvatarContainerView.addSubview(titleAvatarView)
        topBarContentView.addSubview(navigationTitleView)
        topBarContentView.addSubview(menuButton)
    }
}

// MARK: - Title Regeneration

public extension ChatViewController {
    /// Regenerate the conversation title and emoji avatar.
    /// Shows a loading alert during generation and dismisses it upon completion.
    func regenerateTitle() {
        guard let session = currentSession else { return }

        let alert = UIAlertController(
            title: nil,
            message: String.localized("Generating…"),
            preferredStyle: .alert
        )
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor),
            indicator.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
        ])

        present(alert, animated: true)

        Task { @MainActor in
            await session.regenerateTitle()
            alert.dismiss(animated: true) { [weak self] in
                self?.refreshNavigationTitle()
            }
        }
    }

    func clearConversation() {
        guard let session = currentSession else { return }

        draftInputObject = nil
        chatInputView.resetValues()
        chatInputView.storage.removeAll()
        chatInputView.bind(conversationID: conversationID)
        session.clear { [weak self] in
            Task { @MainActor in
                self?.messageListView.updateList()
                self?.refreshNavigationTitle()
            }
        }
    }
}

// MARK: - Chat Input

extension ChatViewController: ChatInputDelegate {
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
        let alert = UIAlertController(title: String.localized("Error"), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("OK"), style: .default))
        present(alert, animated: true)
    }
}
