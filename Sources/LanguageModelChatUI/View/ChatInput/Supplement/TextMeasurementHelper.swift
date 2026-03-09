//
//  TextMeasurementHelper.swift
//  LanguageModelChatUI
//
//  Created by 秋星桥 on 2025/1/17.
//

import UIKit

class TextMeasurementHelper {
    nonisolated(unsafe) static let shared = TextMeasurementHelper()

    private var textStorage: NSTextStorage
    private var textContainer: NSTextContainer
    private var layoutManager: NSLayoutManager

    private let lock = NSLock()

    init() {
        textStorage = NSTextStorage()
        textContainer = NSTextContainer(size: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
        layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0
    }

    func measureSize(
        of attributedString: NSAttributedString,
        usingWidth width: CGFloat,
        lineLimit: Int = 0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail
    ) -> CGSize {
        lock.lock()
        defer { lock.unlock() }

        textContainer.size = CGSize(width: width, height: .infinity)
        textContainer.maximumNumberOfLines = lineLimit
        textContainer.lineBreakMode = lineBreakMode
        textStorage.beginEditing()
        textStorage.setAttributedString(attributedString)
        textStorage.endEditing()

        let size = layoutManager.usedRect(for: textContainer).size
        return .init(width: ceil(size.width), height: ceil(size.height))
    }
}
