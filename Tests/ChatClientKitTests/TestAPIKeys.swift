//
//  TestAPIKeys.swift
//  ChatClientKitTests
//
//  Centralized API key configuration for integration tests.
//  Keys are read from environment variables so that CI can inject
//  them via GitHub Actions secrets.
//

import Foundation

enum TestAPIKeys {
    static let deepseek = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
    static let moonshot = ProcessInfo.processInfo.environment["MOONSHOT_API_KEY"] ?? ""
    static let openRouter = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""
    static let anthropic = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    static let mistral = ProcessInfo.processInfo.environment["MISTRAL_API_KEY"] ?? ""
    static let cerebras = ProcessInfo.processInfo.environment["CEREBRAS_API_KEY"] ?? ""
    static let groq = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
}
