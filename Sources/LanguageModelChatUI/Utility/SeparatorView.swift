import UIKit

final class SeparatorView: UIView {
    static let color: UIColor = .gray.withAlphaComponent(0.1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Self.color
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }
}
