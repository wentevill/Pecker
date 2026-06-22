# Now Timeline MVP Implementation Roadmap

> **For agentic workers:** Execute the linked plans in order. Each plan is a
> separately testable delivery milestone.

**Goal:** Deliver the approved Now Timeline iOS 26 MVP without coupling the
pure timeline rules, EventKit/UI workflow, and ActivityKit extension into one
unreviewable change.

**Architecture:** A platform-neutral Swift package owns models, classification,
ranking, snapshots, settings, and JSON persistence. The iOS app adapts EventKit
into that package and renders the approved SwiftUI flow. A Widget Extension
renders shared ActivityKit state and is coordinated by the app.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, EventKit, ActivityKit,
WidgetKit, App Groups, UserDefaults, XCTest/Swift Testing, XcodeGen, iOS 26.

---

## Execution order

1. [Core and persistence](2026-06-22-now-timeline-core-plan.md)
   - Deliverable: `NowTimelineCore` package with deterministic timeline
     calculation and versioned storage.
   - Verification: `swift test`.

2. [iOS app, EventKit, and complete SwiftUI flow](2026-06-22-now-timeline-app-plan.md)
   - Deliverable: generated iOS project with onboarding, Today, full timeline,
     detail, settings, permissions, refresh, empty, stale, and error states.
   - Verification: app test target, previews, simulator build, and real-device
     EventKit permission checks.

3. [Live Activity and Dynamic Island](2026-06-22-now-timeline-live-activity-plan.md)
   - Deliverable: explicit activation, lifecycle reconciliation, Lock Screen,
     compact, expanded, and minimal Dynamic Island views.
   - Verification: coordinator tests, extension build, previews, and real-device
     ActivityKit checks.

## Required environment before plans 2 and 3

The current machine has Swift 6.1.2 and XcodeGen but no selected full Xcode
installation. Before iOS project work:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Expected: Xcode 26.x and an iOS 26 SDK. If Xcode is installed under another
name, select that application path instead.

## Cross-plan conventions

- Bundle identifier: `com.went.NowTimeline`.
- Widget bundle identifier: `com.went.NowTimeline.LiveActivity`.
- App Group: `group.com.went.nowtimeline`.
- Scheme: `NowTimeline`.
- The app never writes Calendar or Reminder objects.
- User-visible event titles remain unchanged.
- `demo.png` and `docs/visual-design/` are the visual source of truth.
- Each task uses test-first development and ends with a focused commit.

## Specification coverage

- Product constraints, models, ranking, classification, storage, and pure
  tests: plan 1.
- Information architecture, EventKit mapping, refresh lifecycle, onboarding,
  visual system, accessibility, Today, full timeline, detail, settings, and
  empty/error states: plan 2.
- Explicit activation, stale handling, lifecycle decisions, Lock Screen,
  Dynamic Island, and physical-device verification: plan 3.
- Final MVP acceptance requires all three plans and both device verification
  records to pass.
