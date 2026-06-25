# Recognition Source Ingestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete recognition ingestion loop for Calendar, Reminder, imported image, and camera image inputs.

**Architecture:** Core owns provider request/response parsing and repository models. The app owns source ingestion because EventKit, Keychain, PhotosPicker, and camera UI are app concerns. `TodayViewModel.refresh()` synchronizes Calendar/Reminder records into the repository and decorates timeline items with recognized templates. `SettingsView` exposes image and camera recognition entry points.

**Tech Stack:** Swift 6, SwiftUI, PhotosUI, UIKit camera bridge, EventKit, Keychain, OpenAI Responses API, JSON-backed `EventRepository`, XCTest and Swift Testing.

---

### Task 1: OpenAI Provider Network Execution

**Files:**
- Modify: `Sources/PeckerCore/Recognition/RecognitionModels.swift`
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Test: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Write failing tests**

Add tests proving `recognize(_:)` posts the generated request through an injectable HTTP client and parses `output_text` JSON into `RecognitionResult`.

- [ ] **Step 2: Run test and verify RED**

Run: `swift test --filter OpenAIRecognitionProviderTests`

Expected: fails because `OpenAIRecognitionProvider` does not accept an HTTP client and `recognize(_:)` still throws `networkExecutionNotImplemented`.

- [ ] **Step 3: Implement minimal provider execution**

Add a `RecognitionHTTPClient` protocol, URLSession conformance, response status validation, and JSON extraction from `output_text` or `output[].content[].text`.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `swift test --filter OpenAIRecognitionProviderTests`

Expected: all OpenAI provider tests pass.

### Task 2: Calendar and Reminder Repository Synchronization

**Files:**
- Create: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `Pecker/App/AppDependencies.swift`
- Modify: `Pecker/Features/Today/TodayViewModel.swift`
- Modify: `Pecker/EventKit/EventKitMapper.swift`
- Test: `PeckerTests/TodayViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

Add tests proving refresh stores Calendar/Reminder records when sync toggles are enabled, skips disabled sources, and decorates timeline items with recognized templates from the repository.

- [ ] **Step 2: Run test and verify RED**

Run: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project Pecker.xcodeproj -scheme Pecker -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' -only-testing:PeckerTests/TodayViewModelTests -derivedDataPath /tmp/PeckerRecognitionSources CODE_SIGNING_ALLOWED=NO`

Expected: fails because dependencies do not expose recognition coordination and `TodayViewModel` does not synchronize sources.

- [ ] **Step 3: Implement synchronization**

Create a coordinator that converts `EventRecord` and `ReminderRecord` to `StoredEventRecord`, runs provider recognition when enabled and configured, stores status, and returns recognized templates by timeline item ID.

- [ ] **Step 4: Run tests and verify GREEN**

Run the same `xcodebuild` command.

Expected: TodayViewModel tests pass.

### Task 3: Image and Camera Recognition Entry Points

**Files:**
- Create: `Pecker/Recognition/ImageRecognitionStore.swift`
- Create: `Pecker/Features/Settings/CameraCaptureView.swift`
- Modify: `Pecker/Features/Settings/SettingsView.swift`
- Modify: `Pecker/Features/Today/TodayView.swift`
- Modify: `Pecker/App/PeckerApp.swift`
- Modify: `Pecker/Resources/Info.plist`
- Test: `PeckerTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

Add tests proving `SettingsViewModel` can submit imported image and camera image data to an injected recognizer and exposes success/failure status text.

- [ ] **Step 2: Run test and verify RED**

Run: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project Pecker.xcodeproj -scheme Pecker -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' -only-testing:PeckerTests/SettingsViewModelTests -derivedDataPath /tmp/PeckerImageRecognition CODE_SIGNING_ALLOWED=NO`

Expected: fails because image recognition methods and status do not exist.

- [ ] **Step 3: Implement image ingestion**

Add a small image file store under the app group, wire `PhotosPicker` and a UIKit camera bridge into Settings, save image bytes, create `StoredEventRecord`, run the same recognition coordinator, and surface status.

- [ ] **Step 4: Run tests and verify GREEN**

Run the same `xcodebuild` command.

Expected: SettingsViewModel tests pass.

### Task 4: Full Verification and Commit

**Files:**
- All files changed above.

- [ ] **Step 1: Regenerate Xcode project**

Run: `xcodegen generate --spec project.yml`

- [ ] **Step 2: Run package tests**

Run: `swift test`

Expected: all package tests pass.

- [ ] **Step 3: Run Xcode scheme tests**

Run: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project Pecker.xcodeproj -scheme Pecker -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' -derivedDataPath /tmp/PeckerRecognitionFull CODE_SIGNING_ALLOWED=NO`

Expected: all app and core tests pass.

- [ ] **Step 4: Commit**

Run: `git add ... && git commit -m "feat: connect recognition sources"`

Expected: commit created on `codex/ai-recognition-foundation`.

## Self-review

- Spec coverage: Calendar/Reminder synchronization, OpenAI execution, image import, camera capture, local storage, and status UI are covered.
- Placeholder scan: no placeholders remain.
- Type consistency: app-level coordinators use existing `EventRecord`, `ReminderRecord`, `StoredEventRecord`, `RecognitionInput`, and `RecognitionProvider` types.
