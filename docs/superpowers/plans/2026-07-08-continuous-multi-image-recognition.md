# Continuous Multi-Image Recognition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable one event recognition action to use multiple ordered images as continuous evidence for a single event.

**Architecture:** Extend `RecognitionInput` with ordered image inputs while preserving legacy single-image fields. Send every image to the OpenAI-compatible provider and add continuous narrative prompt guidance. Add multi-image App coordinator methods and make the SwiftUI photo picker pass multiple prepared images while saving only the first image as the primary attachment.

**Tech Stack:** Swift, SwiftUI `PhotosPicker`, Swift Testing, XCTest, OpenAI-compatible Chat Completions request bodies.

---

### Task 1: Core Recognition Model

**Files:**
- Modify: `Sources/PeckerCore/Recognition/RecognitionModels.swift`
- Test: `Tests/PeckerCoreTests/RecognitionModelTests.swift`

- [ ] Write failing tests for `RecognitionImageInput`, single-image compatibility, and ordered multi-image factories.
- [ ] Run `swift test --filter RecognitionModelTests` and confirm compile/test failure because multi-image API does not exist.
- [ ] Add `RecognitionImageInput`, `RecognitionInput.images`, and imported/camera multi-image factories.
- [ ] Run `swift test --filter RecognitionModelTests` and confirm pass.

### Task 2: Provider Request and Prompts

**Files:**
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Test: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] Write failing tests that multi-image requests include two ordered `image_url` blocks and continuous narrative guidance.
- [ ] Run `swift test --filter OpenAIRecognitionProviderTests` and confirm failure.
- [ ] Update request content to iterate `input.images`, add image inventory to `inputDescription`, and add continuous narrative guidance to classification, extraction, and verification tasks.
- [ ] Update image failure detection to use `!input.images.isEmpty`.
- [ ] Run `swift test --filter OpenAIRecognitionProviderTests` and confirm pass.

### Task 3: App Coordinator Multi-Image Flow

**Files:**
- Modify: `Pecker/Recognition/ImageRecognitionStore.swift`
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Test: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`

- [ ] Write failing tests that `recognizeImages` passes all images in order, rejects empty arrays, and keeps the first image as the draft primary image.
- [ ] Run `xcodebuild test -scheme Pecker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PeckerTests/SystemEventRecognitionCoordinatorImageXCTests` and confirm failure.
- [ ] Add `recognizeImages` protocol and coordinator methods; make existing single-image methods delegate to them.
- [ ] Run the same XCTest target and confirm pass.

### Task 4: SwiftUI Multi-Photo Picker

**Files:**
- Modify: `Pecker/Features/Today/TodayView.swift`

- [ ] Change `selectedPhoto` to `[PhotosPickerItem]`.
- [ ] Replace `recognizePhoto(_:)` with `recognizePhotos(_:)` that loads and preprocesses every selected image.
- [ ] Set `PhotosPicker(selection:maxSelectionCount:matching:)` to allow multiple images for one event.
- [ ] Run `xcodebuild build -scheme Pecker -destination 'platform=iOS Simulator,name=iPhone 16'` and confirm compile success.

### Task 5: Verification

**Files:**
- All modified files.

- [ ] Run focused Swift package tests: `swift test --filter RecognitionModelTests && swift test --filter OpenAIRecognitionProviderTests`.
- [ ] Run focused app tests: `xcodebuild test -scheme Pecker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PeckerTests/SystemEventRecognitionCoordinatorImageXCTests`.
- [ ] Run a full build: `xcodebuild build -scheme Pecker -destination 'platform=iOS Simulator,name=iPhone 16'`.
- [ ] Review `git diff --stat` and `git diff --check`.
