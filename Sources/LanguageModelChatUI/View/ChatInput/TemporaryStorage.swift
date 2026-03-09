//
//  TemporaryStorage.swift
//  LanguageModelChatUI
//
//  Created by 秋星桥 on 1/17/25.
//

import Foundation

final class TemporaryStorage {
    let storageDir: URL

    init(id: String) {
        storageDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LanguageModelChatUI.TemporaryStorage")
            .appendingPathComponent(id)
        try? FileManager.default.createDirectory(
            at: storageDir,
            withIntermediateDirectories: true
        )
    }

    func makeUniqueFilenameStem() -> String {
        UUID().uuidString
    }

    func fileURL(for filename: String) -> URL {
        storageDir.appendingPathComponent(filename)
    }

    func copyFileIntoStorageIfNeeded(_ file: URL) -> URL? {
        assert(file.isFileURL)
        if file.path.hasPrefix(storageDir.path) { return file }
        var filename = makeUniqueFilenameStem()
        let ext = file.pathExtension
        if !ext.isEmpty { filename += ".\(ext)" }
        let url = fileURL(for: filename)
        do {
            try FileManager.default.copyItem(at: file, to: url)
        } catch {
            return nil
        }
        return url
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: storageDir)
        try? FileManager.default.createDirectory(
            at: storageDir,
            withIntermediateDirectories: true
        )
    }
}
