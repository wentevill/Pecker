# Pecker Live Activity Device Check

Date: 2026-06-24

Automated simulator verification has passed. Physical-device verification is
still required because ActivityKit Lock Screen presentation and Dynamic Island
behavior cannot be fully proven in simulator-only checks.

## Device scenarios to verify

- First activation requires a user action.
- Lock Screen state appears after Pecker refreshes relevant content.
- Compact, expanded, and minimal Dynamic Island states render.
- Countdown advances without reopening the app.
- Foreground refresh changes primary and next content.
- Pause ends the activity.
- Empty day ends the activity.
- Permission-required state ends stale/private previous activity content.
- Stale content is treated as stale by the system.

## Current automated result

- `swift test`: 40 tests passed.
- `xcodegen generate --spec project.yml`: generated project remained clean.
- Active old-identity scan: no active `NowTimeline` identity remained in
  source/config.
- `xcodebuild test -scheme Pecker`: 103 app tests and 40 core tests passed.
- `xcodebuild build -scheme Pecker -configuration Release`: simulator Release
  build succeeded and embedded `PeckerLiveActivity.appex`.

## Physical-device result

Pending physical-device verification.
