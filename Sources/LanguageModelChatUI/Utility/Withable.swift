//
//  Withable.swift
//  LanguageModelChatUI
//

import Foundation

public protocol Withable {}

public extension Withable where Self: Any {
    @inlinable
    @discardableResult
    func with(_ block: (inout Self) throws -> Void) rethrows -> Self {
        var copy = self
        try block(&copy)
        return copy
    }

    @inlinable
    func `do`(_ block: (Self) throws -> Void) rethrows {
        try block(self)
    }
}

public extension Withable where Self: AnyObject {
    @inlinable
    @discardableResult
    func with(_ block: (Self) throws -> Void) rethrows -> Self {
        try block(self)
        return self
    }
}

extension NSObject: Withable {}
extension Array: Withable {}
extension Dictionary: Withable {}
extension Set: Withable {}
extension JSONDecoder: Withable {}
extension JSONEncoder: Withable {}
