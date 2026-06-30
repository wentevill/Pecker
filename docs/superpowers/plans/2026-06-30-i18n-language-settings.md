# I18n Language Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add English/Simplified Chinese localization with a Settings language picker and remove Chinese characters from source files.

**Architecture:** Persist language selection in `TimelineSettings`, resolve display copy through a small localization bundle helper, and move Chinese strings into `.lproj` resources. Keep source files ASCII except fixture content represented with Unicode escapes where tests need Chinese semantics.

**Tech Stack:** Swift, SwiftUI, Foundation `Bundle` localization resources, XCTest, Swift Testing.

---

### Task 1: Settings Language Model

**Files:**
- Modify: `Sources/PeckerCore/Models/TimelineSettings.swift`
- Modify: `PeckerTests/SettingsStoreTests.swift`

- [ ] Add `AppLanguage` enum with `system`, `english`, and `simplifiedChinese`.
- [ ] Add `language` to `TimelineSettings`, coding keys, initializer, and legacy decode default.
- [ ] Write and run a settings persistence test.

### Task 2: Localization Resources and Resolver

**Files:**
- Create: `Pecker/Resources/en.lproj/Localizable.strings`
- Create: `Pecker/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Pecker/Localization/AppLocalizer.swift`
- Test: `PeckerTests/AppLocalizerTests.swift`

- [ ] Add English and Simplified Chinese translation tables.
- [ ] Implement key lookup and formatted lookup using selected `AppLanguage`.
- [ ] Write lookup tests for English, Simplified Chinese, and system fallback.

### Task 3: Settings Picker

**Files:**
- Modify: `Pecker/Features/Settings/SettingsView.swift`
- Test: `PeckerTests/SettingsViewModelTests.swift`

- [ ] Add a `setLanguage(_:)` method to `SettingsViewModel`.
- [ ] Add a `Picker` styled as a menu in the settings timeline/display area.
- [ ] Localize settings labels, statuses, descriptions, buttons, and errors.

### Task 4: Localize App Presentation

**Files:**
- Modify: `Pecker/Features/Today/TodayPresentation.swift`
- Modify: `Pecker/Features/Today/TodayScreenContent.swift`
- Modify: `Pecker/Features/Today/TodayView.swift`
- Modify: `Pecker/Features/Timeline/FullTimelineView.swift`
- Modify: `Pecker/Features/Timeline/TimelineGrouping.swift`
- Modify: `Pecker/Features/Timeline/TimelineRecordEditor.swift`
- Modify: `Pecker/Features/Detail/ItemDetailView.swift`
- Modify: `Shared/PeckerLiveActivityPresentation.swift`
- Modify: `PeckerLiveActivity/*.swift`

- [ ] Replace embedded user-facing text with localization keys.
- [ ] Ensure date and duration formatting uses the selected language locale.
- [ ] Keep dynamic user data untouched.

### Task 5: Localize Recognition Copy

**Files:**
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `Pecker/Recognition/RecognizedEventValidator.swift`
- Modify: `Sources/PeckerCore/Recognition/RecognitionFunctionContract.swift`
- Modify: `Sources/PeckerCore/Classification/EventTemplateFactory.swift`

- [ ] Move user-facing recognition errors and field labels to localization.
- [ ] Convert OpenAI function descriptions to English-only source text.
- [ ] Keep recognized event payload values language-neutral.

### Task 6: Source Scan and Test Cleanup

**Files:**
- Modify: `PeckerTests/*.swift`
- Modify: `Tests/PeckerCoreTests/*.swift`
- Create: `scripts/check-no-han-source.sh`

- [ ] Replace Chinese literals in Swift tests with Unicode escapes or English sample data.
- [ ] Add a scan script that fails on Han characters outside `.lproj` resources and release artifacts.
- [ ] Run the scan and test suite.
