# LanguageModelChatUI

A UIKit chat interface for building LLM-powered conversations on iOS. Supports streaming responses, tool calling, vision inputs, speech-to-text, and markdown rendering out of the box.

## Preview

This library was extracted from [FlowDown](https://github.com/Lakr233/FlowDown).

![A Fun Preview](./Example/SCR-PREVIEW.png)

## Requirements

- iOS 17+
- Swift 6+
- Xcode 16+

## Installation

```swift
.package(url: "https://github.com/Lakr233/LanguageModelChatUI", from: "0.1.0")
```

Two products are available:

| Product               | Description                                           |
| --------------------- | ----------------------------------------------------- |
| `ChatClientKit`       | Lightweight client for language model networking APIs |
| `LanguageModelChatUI` | Full chat UI built on top of ChatClientKit            |

## Quick Start

```swift
import ChatClientKit
import LanguageModelChatUI

// checkout demo app for more
let client = OpenAICompatibleClient(
    model: "your-model-id",
    baseURL: "https://api.example.com/v1",
    path: "/chat/completions",
    apiKey: "your-api-key"
)

let model = ConversationSession.Model(
    client: client,
    capabilities: [.tool, .visual],
    contextLength: 128_000
)

let controller = ChatViewController(
    models: .init(chat: model, titleGeneration: model),
    sessionConfiguration: .init(
        storage: DisposableStorageProvider.shared
    )
)
```

See the `Example/` directory for a complete demo app.

## License

MIT License. Copyright (c) 2026 Lakr233.
