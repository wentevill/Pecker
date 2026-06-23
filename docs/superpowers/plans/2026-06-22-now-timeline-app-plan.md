# Now Timeline iOS App and EventKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> Historical note: this implementation plan predates the rename. The shipping
> app and project identity is now Pecker: Xcode project/scheme/app target
> `Pecker`, core module `PeckerCore`, bundle identifier `com.wenttang.pecker`,
> and App Group `group.com.wenttang.pecker`.

**Goal:** Build the complete approved iOS app flow on top of `NowTimelineCore`, including EventKit permissions, refresh orchestration, Today, full timeline, detail, settings, and all failure states.

**Architecture:** XcodeGen creates a reproducible iOS 26 project. EventKit is isolated behind an actor/protocol; an observable app model converts gateway records through `TimelineEngine`, persists snapshots, and supplies focused SwiftUI screens.

**Tech Stack:** Xcode 26, Swift 6, SwiftUI, EventKit, XcodeGen, XCTest, NowTimelineCore.

---

## File map

```text
project.yml
NowTimeline/
  App/NowTimelineApp.swift
  App/AppModel.swift
  App/AppDependencies.swift
  EventKit/EventKitGateway.swift
  EventKit/EventKitGatewayProtocol.swift
  EventKit/EventKitMapper.swift
  Persistence/AppGroup.swift
  Persistence/SettingsStore.swift
  Design/TimelineTheme.swift
  Design/TimelineCard.swift
  Features/Onboarding/OnboardingView.swift
  Features/Today/TodayView.swift
  Features/Today/TodayViewModel.swift
  Features/Timeline/FullTimelineView.swift
  Features/Detail/ItemDetailView.swift
  Features/Settings/SettingsView.swift
  Features/Shared/TimelineStates.swift
  Resources/Assets.xcassets/
  Resources/Info.plist
  Resources/NowTimeline.entitlements
NowTimelineTests/
  EventKitMapperTests.swift
  TodayViewModelTests.swift
  SettingsStoreTests.swift
```

### Task 1: Generate the iOS project and smoke-test target

**Files:**
- Create: `project.yml`
- Create: `NowTimeline/App/NowTimelineApp.swift`
- Create: `NowTimeline/Resources/Info.plist`
- Create: `NowTimeline/Resources/NowTimeline.entitlements`
- Create: `NowTimelineTests/SmokeTests.swift`

- [ ] **Step 1: Select Xcode 26 and verify the SDK**

Run:

```bash
xcodebuild -version
xcodebuild -showsdks | rg 'iphoneos26'
```

Expected: Xcode 26.x and an iOS 26 SDK. Stop this plan if unavailable.

- [ ] **Step 2: Add a failing smoke test and XcodeGen definition**

Create `SmokeTests.swift`:

```swift
import XCTest
@testable import NowTimeline

final class SmokeTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertEqual(AppIdentity.displayName, "Now Timeline")
    }
}
```

Define `project.yml` with:

- deployment target `26.0`;
- app target `NowTimeline`;
- unit-test target `NowTimelineTests`;
- local package dependency at `.` using product `NowTimelineCore`;
- bundle identifiers from the roadmap;
- App Group entitlement;
- `GENERATE_INFOPLIST_FILE: NO`;
- Swift 6 language mode.

- [ ] **Step 3: Generate and verify initial failure**

Run:

```bash
xcodegen generate
xcodebuild test -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: FAIL because `AppIdentity` is missing.

- [ ] **Step 4: Add the minimal app**

```swift
import SwiftUI

enum AppIdentity {
    static let displayName = "Now Timeline"
}

@main
struct NowTimelineApp: App {
    var body: some Scene {
        WindowGroup { Text(AppIdentity.displayName) }
    }
}
```

Info.plist must contain Calendar and Reminders full-access usage descriptions.

- [ ] **Step 5: Run and commit**

Run the same `xcodebuild test`; expected PASS.

```bash
git add project.yml NowTimeline NowTimelineTests
git commit -m "build: scaffold Now Timeline iOS app"
```

### Task 2: Map EventKit events and reminders

**Files:**
- Create: `NowTimeline/EventKit/EventKitGatewayProtocol.swift`
- Create: `NowTimeline/EventKit/EventKitMapper.swift`
- Create: `NowTimeline/EventKit/EventKitGateway.swift`
- Test: `NowTimelineTests/EventKitMapperTests.swift`

- [ ] **Step 1: Write mapper tests**

Use simple mapper input structs rather than constructing difficult EventKit
objects:

```swift
func testReminderUsesConfiguredDuration() {
    let due = Date(timeIntervalSince1970: 1_000)
    let item = EventKitMapper().mapReminder(
        .init(identifier: "r1", title: "Pay bill", dueDate: due, notes: nil),
        durationMinutes: 45
    )
    XCTAssertEqual(item?.endDate, due.addingTimeInterval(45 * 60))
    XCTAssertEqual(item?.source, .reminder)
}

func testReminderWithoutDueDateIsExcluded() {
    XCTAssertNil(EventKitMapper().mapReminder(
        .init(identifier: "r2", title: "Someday", dueDate: nil, notes: nil),
        durationMinutes: 30
    ))
}
```

- [ ] **Step 2: Verify failure**

Run the mapper test class with `xcodebuild test -only-testing:NowTimelineTests/EventKitMapperTests`.

Expected: FAIL because mapper types are missing.

- [ ] **Step 3: Implement mapper and gateway contract**

Define:

```swift
struct EventRecord: Sendable {
    let identifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
}

struct ReminderRecord: Sendable {
    let identifier: String
    let title: String
    let dueDate: Date?
    let notes: String?
}

protocol EventKitGatewayProtocol: Sendable {
    func authorization() -> SourceAuthorization
    func requestCalendarAccess() async throws -> Bool
    func requestReminderAccess() async throws -> Bool
    func fetchToday(calendar: Calendar, now: Date) async throws -> [EventRecord]
    func fetchReminders(calendar: Calendar, now: Date) async throws -> [ReminderRecord]
}
```

`EventKitGateway` owns one `EKEventStore`, requests full access, fetches events
over the local-day interval, includes overlapping cross-midnight events, and
fetches incomplete reminders due on or before today.

- [ ] **Step 4: Run mapper tests and commit**

Expected: PASS.

```bash
git add NowTimeline/EventKit NowTimelineTests/EventKitMapperTests.swift
git commit -m "feat: read and map EventKit records"
```

### Task 3: Persist settings in the App Group

**Files:**
- Create: `NowTimeline/Persistence/AppGroup.swift`
- Create: `NowTimeline/Persistence/SettingsStore.swift`
- Test: `NowTimelineTests/SettingsStoreTests.swift`

- [ ] **Step 1: Write failing round-trip tests**

Inject a `UserDefaults` suite name and verify default values, update, reload,
manual pin clearing, and invalid reminder duration normalization.

- [ ] **Step 2: Verify failure**

Run:

```bash
xcodebuild test -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NowTimelineTests/SettingsStoreTests
```

Expected: FAIL because `SettingsStore` is missing.

- [ ] **Step 3: Implement settings storage**

```swift
@MainActor
@Observable
final class SettingsStore {
    private(set) var value: TimelineSettings
    func update(_ mutation: (inout TimelineSettings) -> Void)
}
```

Use `UserDefaults(suiteName: AppGroup.identifier)`, encode one
`TimelineSettings` value as JSON, and normalize reminder duration to
`[15, 30, 45, 60]`.

- [ ] **Step 4: Run tests and commit**

```bash
git add NowTimeline/Persistence NowTimelineTests/SettingsStoreTests.swift
git commit -m "feat: persist app settings"
```

### Task 4: Build refresh orchestration and Today view model

**Files:**
- Create: `NowTimeline/App/AppDependencies.swift`
- Create: `NowTimeline/App/AppModel.swift`
- Create: `NowTimeline/Features/Today/TodayViewModel.swift`
- Create: `NowTimeline/Features/Shared/TimelineStates.swift`
- Test: `NowTimelineTests/TodayViewModelTests.swift`

- [ ] **Step 1: Write state-transition tests**

With fake gateway/store dependencies, test:

- first load reaches `.content(snapshot)`;
- one denied source still loads the other;
- both denied reaches `.permissionRequired`;
- failed refresh retains previous snapshot as `.stale(snapshot, error)`;
- no items reaches `.empty`;
- changing reminder duration triggers recalculation.

- [ ] **Step 2: Verify failure**

Run the `TodayViewModelTests`; expected FAIL.

- [ ] **Step 3: Implement the model**

```swift
enum TimelineScreenState: Equatable {
    case loading
    case content(TodaySnapshot)
    case empty
    case permissionRequired(SourceAuthorization)
    case stale(TodaySnapshot, String)
    case failure(String)
}

@MainActor @Observable
final class TodayViewModel {
    private(set) var state: TimelineScreenState = .loading
    func refresh(now: Date = .now) async
}
```

Refresh calendar and reminders concurrently when authorized, map records,
classify them, build a snapshot, save it, and retain the last successful
snapshot on failure. `AppModel` calls refresh on cold launch, foreground entry,
pull-to-refresh, relevant settings changes, and `EKEventStoreChanged` while
the app is running.

- [ ] **Step 4: Run tests and commit**

```bash
git add NowTimeline/App NowTimeline/Features/Today/TodayViewModel.swift \
  NowTimeline/Features/Shared NowTimelineTests/TodayViewModelTests.swift
git commit -m "feat: orchestrate timeline refresh"
```

### Task 5: Implement onboarding and permission flow

**Files:**
- Create: `NowTimeline/Features/Onboarding/OnboardingView.swift`
- Modify: `NowTimeline/App/AppModel.swift`
- Modify: `NowTimeline/App/NowTimelineApp.swift`
- Test: `NowTimelineTests/OnboardingStateTests.swift`

- [ ] **Step 1: Test onboarding state progression**

Assert welcome → calendar → reminders → live activity introduction → complete,
including denial of one source without blocking progression.

- [ ] **Step 2: Verify failure**

Run only `OnboardingStateTests`; expected FAIL.

- [ ] **Step 3: Implement the flow**

Use a paged `NavigationStack` with one primary action per step. Explain that
data remains on-device. Do not request system permission until the user taps
the corresponding button. Store completion in App Group defaults.

The Live Activity step only records intent in this plan; plan 3 replaces the
stub action with the ActivityKit request.

- [ ] **Step 4: Run tests and commit**

```bash
git add NowTimeline/Features/Onboarding NowTimeline/App NowTimelineTests/OnboardingStateTests.swift
git commit -m "feat: add onboarding and permissions"
```

### Task 6: Implement the approved Today visual design

**Files:**
- Create: `NowTimeline/Design/TimelineTheme.swift`
- Create: `NowTimeline/Design/TimelineCard.swift`
- Create: `NowTimeline/Features/Today/TodayView.swift`
- Modify: `NowTimeline/App/NowTimelineApp.swift`

- [ ] **Step 1: Add compile-time previews**

Create preview fixtures for default content, concurrent Now, long titles,
empty, stale, partial authorization, and extra-large Dynamic Type.

- [ ] **Step 2: Verify the preview target currently fails to compile**

Run:

```bash
xcodebuild build -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: FAIL because the views do not exist.

- [ ] **Step 3: Implement the Today screen**

Match `docs/visual-design/previews/03-home-design.jpg`:

- deep navy gradient;
- date, `Today`, and settings button;
- vertical semantic timeline;
- green Now card with progress and concurrent count;
- blue Next card;
- orange Pinned card with automatic/manual badge;
- summary row and refresh timestamp.

Use system typography, SF Symbols, `Material`, accessibility labels, Reduce
Transparency fallback, and no fixed text heights.

- [ ] **Step 4: Build and visually inspect**

Run:

```bash
xcodebuild build -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED. Compare previews with the saved design reference.

- [ ] **Step 5: Commit**

```bash
git add NowTimeline/Design NowTimeline/Features/Today NowTimeline/App
git commit -m "feat: build Today timeline interface"
```

### Task 7: Add full timeline, detail, settings, and states

**Files:**
- Create: `NowTimeline/Features/Timeline/FullTimelineView.swift`
- Create: `NowTimeline/Features/Detail/ItemDetailView.swift`
- Create: `NowTimeline/Features/Settings/SettingsView.swift`
- Modify: `NowTimeline/Features/Today/TodayView.swift`

- [ ] **Step 1: Add grouping and pin-action tests**

Test the grouping function produces overdue, all-day, active, upcoming, and
elapsed sections in order. Test pin/unpin updates `SettingsStore` and triggers
refresh.

- [ ] **Step 2: Verify failure**

Run the new tests; expected FAIL because grouping/actions are missing.

- [ ] **Step 3: Implement screens**

Implement:

- timeline section list and active-only filter;
- read-only detail fields and local pin action;
- source toggles and authorization status;
- travel toggle;
- reminder duration picker;
- Live Activity status row showing `尚未启用`;
- system Settings deep link for denied access;
- empty, permission, stale, and failure components.

- [ ] **Step 4: Run full app tests and build**

Run:

```bash
xcodebuild test -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild build -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'generic/platform=iOS'
```

Expected: tests PASS and both builds succeed.

- [ ] **Step 5: Commit**

```bash
git add NowTimeline/Features NowTimelineTests
git commit -m "feat: complete timeline app flow"
```

### Task 8: Real-device EventKit verification

- [ ] **Step 1: Install on an iOS 26 device**

Expected: both permission prompts use the configured purpose strings.

- [ ] **Step 2: Exercise acceptance fixtures**

Create or use:

- one active meeting;
- two overlapping active events;
- one upcoming event;
- one all-day event;
- one overdue reminder;
- one flight-like event;
- one reminder without due date.

Verify the screen follows the spec and does not modify source data.

- [ ] **Step 3: Record verification**

Create `docs/verification/eventkit-device-check.md` with device/OS, cases,
results, and screenshots. Commit it:

```bash
git add docs/verification/eventkit-device-check.md
git commit -m "test: verify EventKit flow on device"
```
