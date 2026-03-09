import UIKit

extension String {
    @MainActor
    func emojiImage(canvasSize: CGFloat = 128, scale: CGFloat = 0) -> UIImage? {
        let dimension = max(1, canvasSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = scale

        let nsString = self as NSString
        let candidateFontSizes: [CGFloat] = [dimension * 0.82, dimension * 0.78, dimension * 0.74, dimension * 0.70]

        let resolvedFontSize = candidateFontSizes.first { fontSize in
            let font = UIFont.systemFont(ofSize: fontSize)
            let measured = nsString.size(withAttributes: [.font: font])
            return measured.width <= dimension * 0.92 && measured.height <= dimension * 0.92
        } ?? dimension * 0.70

        let font = UIFont.systemFont(ofSize: resolvedFontSize)
        let measured = nsString.size(withAttributes: [.font: font])
        let drawRect = CGRect(
            x: (dimension - measured.width) / 2,
            y: (dimension - measured.height) / 2 - dimension * 0.03,
            width: measured.width,
            height: measured.height
        ).integral

        return UIGraphicsImageRenderer(size: CGSize(width: dimension, height: dimension), format: format).image { _ in
            nsString.draw(in: drawRect, withAttributes: [.font: font])
        }
    }
}
