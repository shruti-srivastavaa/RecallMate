# RecallMate

> **On-device Personal Recall — Privacy-first AI + Deep OS Integration**

An iOS 17+ app that remembers what you saw, copied, or saved and lets you ask natural language questions like:

- *"Where did I save that PDF yesterday?"*
- *"What was the address shared in Messages?"*
- *"Show my recent links"*

All processing happens **entirely on-device** — your data never leaves your phone.

## Features

| Feature | Technology |
|---------|-----------|
| 🧠 Semantic Search | Apple `NaturalLanguage` framework (`NLEmbedding`) |
| 📋 Clipboard Capture | `UIPasteboard` monitoring with deduplication |
| 📁 File Scanning | `FileManager` with supported file type detection |
| 🔍 Spotlight Integration | `CoreSpotlight` — memories appear in system search |
| 🗣️ Siri Integration | `AppIntents` — *"Recall meeting notes in RecallMate"* |
| 🔒 Privacy Controls | Toggle capture sources, set retention periods, clear data |
| 🎨 Premium Dark UI | Glassmorphism, ambient gradients, micro-animations |

## Architecture

```
Models/         → Core Data entities + persistence stack
Services/       → Clipboard monitoring, file scanning, NLP search, Spotlight
Intents/        → AppIntents + Siri shortcut phrases
Views/          → SwiftUI screens (Home, Search, Timeline, Detail, Settings)
  Components/   → Reusable UI components (cards, badges, glass effects)
```

## Getting Started

1. Open the `AIMemoryAssistant` folder in **Xcode 15+**
2. Select an iOS 17+ simulator or device
3. Build and run (`⌘R`)

## Siri Commands

- *"Recall [query] in RecallMate"*
- *"Search [query] in RecallMate"*
- *"Find [query] in RecallMate"*
- *"What was [query] in RecallMate"*
