//
//  ModelDefinition.swift
//  Example
//
//  Created by qaq on 9/3/2026.
//

import ChatClientKit
import LanguageModelChatUI

struct ModelDefinition {
    let title: String
    let subtitle: String
    let icon: String
    let systemPrompt: String
    let collapseReasoning: Bool
    let requiredAPIKey: APIKeyID
    let createModel: () -> ConversationSession.Model
}

let modelDefinitions: [ModelDefinition] = [
    ModelDefinition(
        title: "Kimi K2.5",
        subtitle: "Moonshot AI",
        icon: "brain.head.profile",
        systemPrompt: "You are a helpful AI assistant powered by Kimi K2.5. Be concise, friendly, and helpful. You can use tools when explicitly asked.",
        collapseReasoning: true,
        requiredAPIKey: .moonshot,
        createModel: {
            .init(
                model: "kimi-k2.5",
                client: MoonshotClient(apiKey: APIKeyID.moonshot.currentValue),
                capabilities: [.tool, .visual],
                contextLength: 128_000
            )
        }
    ),
    ModelDefinition(
        title: "DeepSeek Reasoner",
        subtitle: "DeepSeek",
        icon: "waveform.path.ecg",
        systemPrompt: "You are a helpful AI assistant powered by DeepSeek. Think carefully and be helpful.",
        collapseReasoning: true,
        requiredAPIKey: .deepseek,
        createModel: {
            .init(
                model: "deepseek-reasoner",
                client: DeepSeekClient(apiKey: APIKeyID.deepseek.currentValue),
                capabilities: [.tool],
                contextLength: 64000
            )
        }
    ),
    ModelDefinition(
        title: "Claude Haiku 4.5",
        subtitle: "Anthropic (Extended Thinking)",
        icon: "sparkles",
        systemPrompt: "You are a helpful AI assistant powered by Claude. Be concise and helpful. You can use tools when asked.",
        collapseReasoning: true,
        requiredAPIKey: .anthropic,
        createModel: {
            .init(
                model: "claude-haiku-4-5-20251001",
                client: AnthropicClient(
                    apiKey: APIKeyID.anthropic.currentValue,
                    thinkingBudgetTokens: 2048
                ),
                capabilities: [.tool, .visual],
                contextLength: 200_000
            )
        }
    ),
    ModelDefinition(
        title: "Claude Sonnet 4.6",
        subtitle: "Anthropic via OpenRouter",
        icon: "cloud",
        systemPrompt: "You are a helpful AI assistant. Be concise and helpful.",
        collapseReasoning: false,
        requiredAPIKey: .openRouter,
        createModel: {
            .init(
                model: "anthropic/claude-sonnet-4.6",
                client: OpenRouterClient(apiKey: APIKeyID.openRouter.currentValue),
                capabilities: [.tool, .visual],
                contextLength: 200_000
            )
        }
    ),
    ModelDefinition(
        title: "Gemini 3 Flash",
        subtitle: "Google via OpenRouter",
        icon: "diamond",
        systemPrompt: "You are a helpful AI assistant. Be concise and helpful.",
        collapseReasoning: true,
        requiredAPIKey: .openRouter,
        createModel: {
            .init(
                model: "google/gemini-3-flash-preview",
                client: OpenRouterClient(apiKey: APIKeyID.openRouter.currentValue),
                capabilities: [.tool, .visual],
                contextLength: 1_000_000
            )
        }
    ),
    ModelDefinition(
        title: "Mistral Small",
        subtitle: "Mistral AI",
        icon: "wind",
        systemPrompt: "You are a helpful AI assistant powered by Mistral. Be concise and helpful.",
        collapseReasoning: false,
        requiredAPIKey: .mistral,
        createModel: {
            .init(
                model: "mistral-small-latest",
                client: OpenAICompatibleClient(
                    baseURL: "https://api.mistral.ai",
                    path: "/v1/chat/completions",
                    apiKey: APIKeyID.mistral.currentValue
                ),
                capabilities: [.tool, .visual],
                contextLength: 32000
            )
        }
    ),
    ModelDefinition(
        title: "Llama 3.1 8B",
        subtitle: "Cerebras",
        icon: "bolt",
        systemPrompt: "You are a helpful AI assistant. Be concise and helpful.",
        collapseReasoning: false,
        requiredAPIKey: .cerebras,
        createModel: {
            .init(
                model: "llama3.1-8b",
                client: OpenAICompatibleClient(
                    baseURL: "https://api.cerebras.ai",
                    path: "/v1/chat/completions",
                    apiKey: APIKeyID.cerebras.currentValue
                ),
                capabilities: [],
                contextLength: 8192
            )
        }
    ),
]
