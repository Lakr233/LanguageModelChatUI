import UIKit

extension UIImage {
    static func chatInputIcon(named name: String) -> UIImage? {
        UIImage(named: name, in: .module, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
    }
}
