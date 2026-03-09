//
//  ModelCapability.swift
//  LanguageModelChatUI
//

import Foundation

/// Capabilities a language model may support.
public enum ModelCapability: String, Sendable, Hashable, CaseIterable {
    case visual
    case auditory
    case tool
    case developerRole
}
