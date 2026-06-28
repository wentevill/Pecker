# AI Recognition Confirmation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a typing-style recognition state, preview the recognized event in place, and persist it only after explicit user confirmation.

**Architecture:** Keep provider recognition and persistence separate. `SystemEventRecognitionCoordinator` creates an in-memory `ImageRecognitionDraft`; `ImageRecognitionCoordinator` persists its image and event only from `saveRecognizedImage`. `TodayView` owns the transient state machine and renders it through pure `TodayScreenContent` presentation values.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XCTest, async/await, JSONDecoder, Xcode iOS Simulator build.

---

## File Structure

- `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`: extract the final JSON object while discarding provider reasoning wrappers.
- `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`: define the image draft and recognize without repository writes; save a fully constructed record separately.
- `Pecker/Recognition/ImageRecognitionStore.swift`: split image recognition from persistence and add image rollback deletion.
- `Pecker/Features/Today/TodayScreenContent.swift`: model recognition UI states and pure result-card presentation.
- `Pecker/Features/Today/TodayView.swift`: own the transient draft, run recognize/save/cancel actions, and render typing and confirmation controls.
- `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`: provider response parsing regressions.
- `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`: draft, persistence, cancellation, and rollback behavior.
- `PeckerTests/TodayPresentationTests.swift`: recognition state-to-presentation mapping.

### Task 1: Parse Wrapped Provider Responses

**Files:**
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`

- [ ] **Step 1: Write the failing wrapped-response tests**

Add tests that feed Chat Completions content containing `<think>reasoning</think>` followed by the expected payload and assert that recognition returns the final payload. Add a second test whose content has no JSON object and assert `RecognitionError.invalidResponse`.

```swift
@Test func openAIProviderDiscardsReasoningBeforeFinalJSON() async throws {
    let client = StubRecognitionHTTPClient(
        data: Data(#"{"choices":[{"message":{"content":"<think>分析图片</think>\n{\"kind\":\"train\",\"fields\":{\"trainNumber\":\"G123\"}}"}}]}"#.utf8),
        statusCode: 200
    )
    let provider = OpenAIRecognitionProvider(
        configuration: .init(host: "https://api.example.com/v1", apiKey: "sk-test", model: "vision"),
        httpClient: client
    )
    let result = try await provider.recognize(
        .importedImage(id: "1", imageData: Data([1]), filename: "ticket.jpg")
    )
    #expect(result.payload.fields["trainNumber"] == "G123")
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
swift test --filter openAIProviderDiscardsReasoningBeforeFinalJSON
```

Expected: failure with `invalidResponse` because the entire assistant content is decoded as JSON.

- [ ] **Step 3: Implement final-object extraction**

Add a helper that first attempts to decode the trimmed content directly, then scans balanced braces while respecting JSON strings and escapes. Decode candidate objects from the last complete object backward and return the first valid `ExternalEventTemplatePayload`.

```swift
private func decodePayloadText(_ text: String) throws -> ExternalEventTemplatePayload {
    if let payload = decodePayloadObject(text) {
        return payload
    }
    for candidate in jsonObjectCandidates(in: text).reversed() {
        if let payload = decodePayloadObject(candidate) {
            return payload
        }
    }
    throw RecognitionError.invalidResponse
}
```

- [ ] **Step 4: Run all provider tests**

Run:

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: all provider tests pass.

### Task 2: Separate Image Recognition From Persistence

**Files:**
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`

- [ ] **Step 1: Replace immediate-storage expectations with failing draft tests**

Define the expected draft behavior:

```swift
let draft = try await coordinator.recognizeImage(
    data: imageData,
    source: .importedImage,
    filename: "ticket.jpg",
    settings: settings,
    now: now
)
#expect(draft.imageData == imageData)
#expect(draft.template.presentation.title == "G123")
#expect(await repository.records().isEmpty)
```

Add a save test:

```swift
let saved = try await coordinator.saveRecognizedImage(
    draft,
    imageReference: "Images/ticket.jpg"
)
#expect(saved.recognitionStatus == .recognized)
#expect(await repository.records() == [saved])
```

- [ ] **Step 2: Run coordinator tests and verify they fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests test
```

Expected: compile/test failure because draft and two-step methods do not exist.

- [ ] **Step 3: Add `ImageRecognitionDraft`**

Create an app-layer sendable/equatable value:

```swift
struct ImageRecognitionDraft: Sendable, Equatable, Identifiable {
    let id: String
    let sourceIdentifier: String
    let source: RecognitionSource
    let filename: String?
    let imageData: Data
    let recognizedAt: Date
    let template: TimelineEventTemplate
}
```

- [ ] **Step 4: Make recognition return a draft without writes**

Refactor image recognition to call the provider and template factory directly. Do not create pending/failed records and do not call `repository.upsert`.

- [ ] **Step 5: Add explicit draft persistence**

Construct and upsert a `.recognized` `StoredEventRecord` only in:

```swift
func saveRecognizedImage(
    _ draft: ImageRecognitionDraft,
    imageReference: String
) async throws -> StoredEventRecord
```

- [ ] **Step 6: Run coordinator tests**

Run the focused Xcode command from Step 2.

Expected: coordinator tests pass and recognition-only tests prove the repository remains empty.

### Task 3: Persist Confirmed Images With Rollback

**Files:**
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`
- Modify: `Pecker/Recognition/ImageRecognitionStore.swift`

- [ ] **Step 1: Add failing image coordinator tests**

Use a recording image store and system coordinator test double to verify:

- recognition calls no image-store write;
- saving calls `saveImage`, then event persistence;
- a persistence error calls `deleteImage(at:)`;
- retrying Save reuses the same draft without invoking recognition.

The image storage protocol becomes:

```swift
protocol ImageFileStoring: Sendable {
    func saveImage(data: Data, filename: String?, source: RecognitionSource) throws -> String
    func deleteImage(at relativePath: String) throws
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests test
```

Expected: compile/test failure because the protocol has only immediate recognition.

- [ ] **Step 3: Implement deletion and two-step coordinator methods**

`ImageRecognitionStore.deleteImage(at:)` resolves the relative path under its root and removes it when present. `ImageRecognitionCoordinator.saveRecognizedImage` catches repository errors, attempts image deletion, then rethrows the original error.

- [ ] **Step 4: Run focused tests**

Run the command from Step 2.

Expected: all image coordination tests pass.

### Task 4: Add Pure Recognition Presentation States

**Files:**
- Modify: `PeckerTests/TodayPresentationTests.swift`
- Modify: `Pecker/Features/Today/TodayScreenContent.swift`

- [ ] **Step 1: Write failing state mapping tests**

Cover `.recognizing`, `.awaitingConfirmation`, `.saving`, `.saveFailure`, `.success`, and `.failure`. Expected result presentation includes:

```swift
struct RecognitionPreview: Equatable {
    let titleText: String
    let subtitleText: String?
    let fields: [EventTemplatePresentation.Field]
    let saveButtonText: String
    let cancelButtonText: String
    let buttonsDisabled: Bool
    let errorText: String?
}
```

- [ ] **Step 2: Run presentation tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerTests/TodayPresentationTests test
```

Expected: compile failure because the new cases and presentation values do not exist.

- [ ] **Step 3: Implement pure mappings**

Extend `RecognitionActions` with a phase kind and optional preview. Derive preview strings from `draft.template.presentation`. Keep recognition controls disabled for recognizing, awaiting confirmation, saving, and save failure until Save or Cancel resolves the draft.

- [ ] **Step 4: Run presentation tests**

Run the command from Step 2.

Expected: all presentation tests pass.

### Task 5: Build Typing and Confirmation UI

**Files:**
- Modify: `Pecker/Features/Today/TodayView.swift`

- [ ] **Step 1: Wire the transient state machine**

Change photo and camera handlers to:

```swift
imageRecognitionPhase = .recognizing
let draft = try await imageRecognizer.recognizeImage(...)
imageRecognitionPhase = .awaitingConfirmation(draft)
```

Add:

```swift
private func saveRecognitionDraft(_ draft: ImageRecognitionDraft) async
private func cancelRecognitionDraft()
```

Save moves through `.saving`, calls `saveRecognizedImage`, clears the draft on success, and refreshes the timeline. Save failure retains the draft.

- [ ] **Step 2: Add typing indicator**

Create a small `RecognitionTypingIndicator` using `TimelineView(.animation)` and three dots with staggered opacity/vertical offset. Read `accessibilityReduceMotion`; render a static ellipsis when enabled. Expose one accessibility label: `正在识别图片`.

- [ ] **Step 3: Add in-place preview**

Inside the existing recognition `TimelineCard`, render title, subtitle, labeled fields, Save, and Cancel below a divider whenever a preview exists. Saving disables both buttons and shows `正在保存`.

- [ ] **Step 4: Compile the app**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-destination 'generic/platform=iOS Simulator' \
CODE_SIGNING_ALLOWED=NO build
```

Expected: `BUILD SUCCEEDED`.

### Task 6: Full Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run Swift package tests**

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 2: Run Pecker app tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 3: Run final build and diff checks**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-destination 'generic/platform=iOS Simulator' \
CODE_SIGNING_ALLOWED=NO build
git diff --check
git status --short
```

Expected: `BUILD SUCCEEDED`, no whitespace errors, and only intentional source/test changes remain.
