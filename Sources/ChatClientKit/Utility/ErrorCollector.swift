//
//  ErrorCollector.swift
//  ChatClientKit
//
//  Created by AI Assistant on 2025/11/11.
//

import Foundation

@MainActor
public class ErrorCollector {
    var error: String?

    public init() {}

    public func collect(_ error: String) {
        self.error = error
    }

    public var currentError: String? {
        error
    }

    public func clear() {
        error = nil
    }
}

public nonisolated extension ErrorCollector {
    static func new() -> ErrorCollector {
        MainActor.isolated { .init() }
    }
}
