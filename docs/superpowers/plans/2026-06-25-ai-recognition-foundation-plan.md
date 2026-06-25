# AI Recognition Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AI recognition settings, provider seams, local event storage, and sync preferences for Calendar/Reminder content.

**Architecture:** PeckerCore owns recognition/storage models and provider protocols. The app layer owns Keychain-backed API key storage and Settings UI. The existing template factory remains the conversion boundary from AI/external payloads into semantic event templates.

**Tech Stack:** Swift 6, Codable JSON storage, Swift Testing/XCTest, SwiftUI, Security/Keychain.

---

### Task 1: Core AI settings and recognition contracts

**Files:**
- Create: `Sources/PeckerCore/Recognition/RecognitionModels.swift`
- Create: `Sources/PeckerCore/Recognition/RecognitionProvider.swift`
- Modify: `Sources/PeckerCore/Models/TimelineSettings.swift`
- Test: `Tests/PeckerCoreTests/RecognitionModelTests.swift`

- [ ] Add failing tests for AI defaults, OpenAI-compatible settings, image/camera recognition inputs, and local-model unavailable behavior.
- [ ] Implement `AIRecognitionMode`, `RecognitionSource`, `RecognitionInput`, `RecognitionResult`, `RecognitionProvider`, and `LocalModelRecognitionProvider`.
- [ ] Extend `TimelineSettings` with AI mode, host/model, API key configured flag, and Calendar/Reminder storage sync toggles.

### Task 2: OpenAI-compatible provider skeleton

**Files:**
- Create: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Test: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] Add failing tests proving custom host/model/API key are used to build a `/v1/responses` request.
- [ ] Add tests proving text inputs and image inputs are represented in the request body.
- [ ] Implement request construction only; parsing and network execution remain behind the protocol seam.

### Task 3: Local event repository

**Files:**
- Create: `Sources/PeckerCore/Storage/EventRepository.swift`
- Test: `Tests/PeckerCoreTests/EventRepositoryTests.swift`

- [ ] Add failing tests for save/load/upsert/delete and source-specific filtering.
- [ ] Implement a JSON-backed actor repository for `StoredEventRecord`.
- [ ] Include source identifiers for Calendar/Reminder and image references for image/camera records.

### Task 4: App Keychain and Settings UI

**Files:**
- Create: `Pecker/Persistence/APIKeyStore.swift`
- Modify: `Pecker/Features/Settings/SettingsView.swift`
- Test: `PeckerTests/SettingsViewModelTests.swift`

- [ ] Add failing app tests for AI mode, host/model, API-key configured flag, and Calendar/Reminder sync toggles.
- [ ] Implement Keychain store protocol and production Keychain adapter.
- [ ] Extend `SettingsViewModel` with AI mutations and API-key save/clear status updates.
- [ ] Add Settings UI card with mode picker, OpenAI host/model fields, API-key status, local-model reserved copy, and sync toggles.

### Task 5: Verification and commit

**Files:**
- All changed files.

- [ ] Run `swift test`.
- [ ] Run `xcodegen generate --spec project.yml`.
- [ ] Run `xcodebuild test -scheme Pecker`.
- [ ] Commit the implementation.
