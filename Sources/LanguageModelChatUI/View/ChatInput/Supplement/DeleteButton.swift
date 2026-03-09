//
//  DeleteButton.swift
//  LanguageModelChatUI
//

import UIKit

class DeleteButton: UIView {
    let background = UIView()
    let imageView = UIImageView()

    var actionBlock: () -> Void = {}

    init() {
        super.init(frame: .zero)

        addSubview(background)
        background.backgroundColor = .gray.withAlphaComponent(0.75)

        addSubview(imageView)
        imageView.tintColor = .systemBackground
        imageView.contentMode = .scaleAspectFit
        let configuration = UIImage.SymbolConfiguration(weight: .heavy)
        imageView.image = UIImage(systemName: "xmark", withConfiguration: configuration)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onTapped))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        background.frame = bounds
        background.layer.cornerRadius = min(bounds.width, bounds.height) / 2

        imageView.frame = bounds.insetBy(dx: 5, dy: 5)
    }

    @objc func onTapped() {
        puddingAnimate()
        actionBlock()
    }
}
