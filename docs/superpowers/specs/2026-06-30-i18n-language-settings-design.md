# I18n Language Settings Design

## Goal

Pecker supports English and Simplified Chinese, lets the user choose the app language in Settings, and keeps Chinese text out of source code.

## Scope

- Add a persisted language setting with `system`, `english`, and `simplifiedChinese` options.
- Add a Settings language picker.
- Resolve user-facing strings through a localization layer.
- Store Chinese translations in localization resources, not Swift source.
- Add automated coverage for language persistence, lookup, and source scanning.

## Architecture

- `TimelineSettings` stores the selected language as a codable enum.
- A lightweight localization service resolves keys from bundled `Localizable.strings` resources using the selected language.
- Presentation structs and SwiftUI views receive or read localized strings instead of embedding user-facing Chinese text.
- Tests that need Chinese sample data use Unicode escapes or fixture resources so `.swift` files contain no Han characters.

## Non-Goals

- No server-side locale negotiation.
- No dynamic in-app translation.
- No broad UI redesign beyond adding the language picker.

## Acceptance

- Settings exposes a picker for System, English, and Simplified Chinese.
- App text can render in English and Simplified Chinese.
- A source scan over code and project files reports no Chinese characters outside approved localization resources.
- Existing SwiftPM tests pass; iOS XCTest should be runnable when Xcode is configured.
