//
//  Withable.swift
//  LanguageModelChatUI
//

import Foundation

public protocol Withable {}

extension Withable where Self: Any {
    @inlinable
    @discardableResult
    public func with(_ block: (inout Self) throws -> Void) rethrows -> Self {
        var copy = self
        try block(&copy)
        return copy
    }

    @inlinable
    public func `do`(_ block: (Self) throws -> Void) rethrows {
        try block(self)
    }
}

extension Withable where Self: AnyObject {
    @inlinable
    @discardableResult
    public func with(_ block: (Self) throws -> Void) rethrows -> Self {
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
