# Full Page Language Switching Design

## Goal

Every Pecker page should render app-owned copy in the selected language immediately after the user changes Settings language.

## Scope

- Route one `AppLocalizer` from `SettingsStore.value.language` through the SwiftUI screen tree.
- Localize page titles, buttons, empty states, cards, dialogs, errors, editor labels, onboarding copy, and Live Activity display labels.
- Keep user-provided event titles, locations, notes, OCR payload content, and model prompt text unchanged.
- Keep Chinese characters out of Swift/YAML/project source; Simplified Chinese copy lives in `zh-Hans.lproj/Localizable.strings`.

## Architecture

- `AppLocalizer` remains the lightweight lookup service.
- Views derive a localizer from `settingsStore.value.language` or receive one from parents.
- Presentation builders accept a localizer when they create user-facing copy.
- Shared/extension presentation uses language-aware resource lookup where settings are available; otherwise it falls back to system locale.

## Acceptance

- Changing language in Settings updates all currently visible app-owned copy.
- English and Simplified Chinese resource key sets match.
- `scripts/check-no-han-source.sh` passes.
- `swift test` passes.
