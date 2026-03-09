//
//  ModalContentController.swift
//  LanguageModelChatUI
//

import UIKit

class ModalContentController: UIViewController {
    private let backgroundBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let dimmingView = UIView()
    private let contentBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    let contentView = UIView()

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        backgroundBlurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundBlurView)
        NSLayoutConstraint.activate([
            backgroundBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimmingView)
        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dimmingViewTapped))
        dimmingView.addGestureRecognizer(tap)

        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        contentBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentBackgroundView.isUserInteractionEnabled = false
        contentBackgroundView.layer.cornerRadius = 16
        contentBackgroundView.layer.cornerCurve = .continuous
        contentBackgroundView.clipsToBounds = true
        contentView.addSubview(contentBackgroundView)
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        contentViewDidLoad()
        contentView.sendSubviewToBack(contentBackgroundView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        contentViewLayout(in: contentView.bounds)
    }

    func contentViewDidLoad() {}

    @objc func dimmingViewTapped() {
        dismiss(animated: true)
    }

    func contentViewLayout(in _: CGRect) {}
}
