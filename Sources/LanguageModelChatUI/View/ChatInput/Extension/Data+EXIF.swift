//
//  Data+EXIF.swift
//  LanguageModelChatUI
//
//  Created by 秋星桥 on 1/18/25.
//

import UIKit

extension Data {
    func byRemovingEXIF() -> Data? {
        guard let source = CGImageSourceCreateWithData(self as NSData, nil),
              let type = CGImageSourceGetType(source)
        else { return nil }

        let count = CGImageSourceGetCount(source)
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, type, count, nil) else { return nil }

        let exifToRemove: CFDictionary = [
            kCGImagePropertyExifDictionary: kCFNull,
            kCGImagePropertyGPSDictionary: kCFNull,
        ] as CFDictionary

        for index in 0 ..< count {
            CGImageDestinationAddImageFromSource(destination, source, index, exifToRemove)
            if !CGImageDestinationFinalize(destination) {
                return nil
            }
        }

        return mutableData as Data
    }
}
