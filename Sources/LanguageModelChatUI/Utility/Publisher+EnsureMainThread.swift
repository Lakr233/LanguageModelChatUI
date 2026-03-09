//
//  Publisher+EnsureMainThread.swift
//  LanguageModelChatUI
//

import Combine
import Foundation

extension Publisher {
    func ensureMainThread() -> AnyPublisher<Output, Failure> {
        receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
}
