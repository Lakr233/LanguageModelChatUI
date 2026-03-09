//
//  IconButton.swift
//  LanguageModelChatUI
//

import UIKit

class IconButton: UIView {
    let imageView = UIImageView()

    var tapAction: () -> Void = {}

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        let tap = UITapGestureRecognizer(target: self, action: #selector(buttonAction))
        addGestureRecognizer(tap)

        isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    convenience init(icon: String) {
        self.init(frame: .zero)
        imageView.image = UIImage.chatInputIcon(named: icon)
    }

    func change(icon: String, animated: Bool = true) {
        if animated {
            UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
                self.change(icon: icon, animated: false)
            }, completion: nil)
        } else {
            imageView.image = UIImage.chatInputIcon(named: icon)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds.insetBy(dx: 2, dy: 2)
    }

    @objc private func buttonAction() {
        guard !isHidden else { return }
        guard alpha > 0 else { return }
        puddingAnimate()
        tapAction()
    }
}
