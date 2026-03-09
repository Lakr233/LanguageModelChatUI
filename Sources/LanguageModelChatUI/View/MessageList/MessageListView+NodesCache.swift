//
//  MessageListView+NodesCache.swift
//  LanguageModelChatUI
//
//  Thread-safe cache for preprocessed markdown content.
//

import Foundation
import MarkdownParser
import MarkdownView

extension MessageListView {
    class MarkdownPackageCache {
        private var cachedPackages: [String: MarkdownTextView.PreprocessedContent] = [:]
        private var cachedHashes: [String: Int] = [:]
        private let lock = NSLock()
        private let parser = MarkdownParser()

        func package(
            for messageRepresentation: MessageRepresentation,
            theme: MarkdownTheme
        ) -> MarkdownTextView.PreprocessedContent {
            let id = messageRepresentation.id
            let contentHash = messageRepresentation.content.hashValue

            lock.lock()
            if let cached = cachedPackages[id], cachedHashes[id] == contentHash {
                lock.unlock()
                return cached
            }
            lock.unlock()

            let content = updateCache(content: messageRepresentation.content, theme: theme)

            lock.lock()
            cachedPackages[id] = content
            cachedHashes[id] = contentHash
            lock.unlock()

            return content
        }

        private func updateCache(content: String, theme: MarkdownTheme) -> MarkdownTextView.PreprocessedContent {
            let parseResult = parser.parse(content)
            if Thread.isMainThread {
                return MainActor.assumeIsolated {
                    MarkdownTextView.PreprocessedContent(parserResult: parseResult, theme: theme)
                }
            }
            return DispatchQueue.main.sync {
                MarkdownTextView.PreprocessedContent(parserResult: parseResult, theme: theme)
            }
        }
    }
}
