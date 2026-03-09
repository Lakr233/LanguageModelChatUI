//
//  APIKeyID.swift
//  Example
//
//  Created by qaq on 9/3/2026.
//

import Foundation

enum APIKeyID: String, CaseIterable {
    case moonshot
    case deepseek
    case anthropic
    case openRouter
    case mistral
    case cerebras

    var displayName: String {
        switch self {
        case .moonshot: "Moonshot"
        case .deepseek: "DeepSeek"
        case .anthropic: "Anthropic"
        case .openRouter: "OpenRouter"
        case .mistral: "Mistral"
        case .cerebras: "Cerebras"
        }
    }

    var icon: String {
        switch self {
        case .moonshot: "moon"
        case .deepseek: "magnifyingglass"
        case .anthropic: "sparkles"
        case .openRouter: "cloud"
        case .mistral: "wind"
        case .cerebras: "bolt"
        }
    }

    var userDefaultsKey: String {
        "api_key_\(rawValue)"
    }

    var currentValue: String {
        get { UserDefaults.standard.string(forKey: userDefaultsKey) ?? "" }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }
}
