# Full Page Language Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every app-owned page string render from the selected language.

**Architecture:** Expand `AppLocalizer`, inject it through the screen hierarchy, move page copy into resource keys, and verify resource parity plus source scanning. Dynamic user and recognition payload data remains unchanged.

**Tech Stack:** Swift, SwiftUI, Foundation bundles, XCTest, Swift Testing.

---

### Task 1: Localizer Coverage

**Files:**
- Modify: `Pecker/Localization/AppLocalizer.swift`
- Modify: `Pecker/Resources/en.lproj/Localizable.strings`
- Modify: `Pecker/Resources/zh-Hans.lproj/Localizable.strings`
- Test: `PeckerTests/AppLocalizerTests.swift`

- [ ] Add key parity tests for English and Simplified Chinese resources.
- [ ] Add keys for Today, Settings, Timeline, Detail, Editor, Onboarding, shared notices, dialogs, and Live Activity labels.
- [ ] Add convenience APIs for list joining and duration strings.

### Task 2: Inject Localizer

**Files:**
- Modify: `Pecker/Features/Today/TodayView.swift`
- Modify: `Pecker/Features/Settings/SettingsView.swift`
- Modify: `Pecker/Features/Timeline/FullTimelineView.swift`
- Modify: `Pecker/Features/Detail/ItemDetailView.swift`
- Modify: `Pecker/Features/Timeline/TimelineRecordEditor.swift`
- Modify: `Pecker/Features/Onboarding/OnboardingView.swift`

- [ ] Derive `AppLocalizer(language: settingsStore.value.language)` at roots that own settings.
- [ ] Pass localizer into child screens and presentation builders.
- [ ] Ensure changing `settingsStore.value.language` invalidates visible views.

### Task 3: Replace Page Copy

**Files:**
- Modify: all files in Task 2 plus `TodayScreenContent`, `TodayPresentation`, `TimelineGrouping`, `TimelineStates`, `ItemDetailView`, and Live Activity presentation files.

- [ ] Replace app-owned literals with localizer keys.
- [ ] Keep user event content and model input/output data unchanged.
- [ ] Update tests to assert localized English and Simplified Chinese outputs where practical.

### Task 4: Verification

**Files:**
- Modify: `scripts/check-no-han-source.sh` only if needed.

- [ ] Run `bash scripts/check-no-han-source.sh`.
- [ ] Run `swift test`.
- [ ] Try targeted `xcodebuild test` and report if local Xcode selection blocks it.
