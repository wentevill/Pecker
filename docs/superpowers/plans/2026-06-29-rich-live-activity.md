# Rich Live Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give all Pecker Live Activities a strong single-item presentation, dedicated train and flight ticket layouts, and local boundary-driven switching or dismissal.

**Architecture:** Preserve rich recognition data in PeckerCore, map each `TimelineItem` through one pure app-side adapter into a bounded ActivityKit content state, and render that state consistently in Lock Screen and Dynamic Island views. Add a cancellable foreground boundary scheduler plus best-effort `BGAppRefreshTaskRequest`; every boundary performs a full Today refresh, which either updates to the next primary item or immediately ends the activity.

**Tech Stack:** Swift 6, SwiftUI, ActivityKit, WidgetKit, BackgroundTasks, XCTest, XcodeGen.

---

## File Structure

- `Sources/PeckerCore/Classification/EventTemplateFactory.swift`
  - Add `FlightTicketTemplate`.
  - Preserve normalized generic recognition fields with backward-compatible decoding.
- `Tests/PeckerCoreTests/EventTemplateFactoryTests.swift`
  - Verify flight mapping and generic-field preservation.
- `Shared/PeckerActivityAttributes.swift`
  - Replace multi-item content with one bounded semantic presentation.
- `Pecker/Activity/LiveActivityPresentationAdapter.swift`
  - Convert `TimelineItem` to display-ready content state.
- `PeckerTests/LiveActivityPresentationAdapterTests.swift`
  - Table-test every kind and dedicated ticket degradation.
- `Pecker/Activity/ActivityCoordinator.swift`
  - Use the adapter and expose the next scheduling boundary.
- `Pecker/Activity/ActivityClient.swift`
  - Keep ActivityKit start/update/end behavior; adapt operation test values.
- `PeckerTests/ActivityCoordinatorTests.swift`
  - Cover Now → Next, Next → Now, pinned fallback, and final dismissal.
- `PeckerLiveActivity/LockScreenLiveActivityView.swift`
  - Render dedicated ticket and generic single-item layouts.
- `PeckerLiveActivity/DynamicIslandLiveActivityView.swift`
  - Render matching expanded, compact, and minimal layouts.
- `Shared/PeckerLiveActivityPresentation.swift`
  - Centralize symbols, localized copy, status, metadata, and stale-state helpers.
- `PeckerTests/LiveActivityPresentationTests.swift`
  - Test symbols, copy, countdown, and ended fallback.
- `Pecker/Activity/LiveActivityBoundaryScheduler.swift`
  - Own cancellable foreground timers and background request scheduling.
- `PeckerTests/LiveActivityBoundarySchedulerTests.swift`
  - Verify replacement, cancellation, and immediate past-boundary behavior.
- `Pecker/Features/Today/TodayViewModel.swift`
  - Publish the next boundary after reconciliation and handle boundary refresh.
- `Pecker/App/AppModel.swift`
  - Connect active/inactive lifecycle to the scheduler.
- `Pecker/App/PeckerApp.swift`
  - Register the SwiftUI background refresh handler.
- `Pecker/App/AppDependencies.swift`
  - Inject scheduler dependencies for production and tests.
- `Pecker/Resources/Info.plist`
  - Permit the app-refresh identifier and background fetch mode.
- `PeckerTests/TodayViewModelTests.swift`
  - Verify scheduler integration does not let stale refresh generations win.
- `project.yml`, `Pecker.xcodeproj/project.pbxproj`
  - Include new sources by regenerating the Xcode project.

### Task 1: Preserve Dedicated Flight and Generic Recognition Data

**Files:**
- Modify: `Sources/PeckerCore/Classification/EventTemplateFactory.swift`
- Modify: `Tests/PeckerCoreTests/EventTemplateFactoryTests.swift`

- [ ] **Step 1: Write failing model tests**

Add tests that create these payloads:

```swift
func testFlightPayloadCreatesStructuredTicket() {
    let payload = ExternalEventTemplatePayload(
        kind: .flight,
        fields: [
            "flightNumber": "SQ 833",
            "carrier": "Singapore Airlines",
            "departureAirport": "Shanghai Pudong",
            "departureAirportCode": "PVG",
            "arrivalAirport": "Singapore Changi",
            "arrivalAirportCode": "SIN",
            "terminal": "T3",
            "gate": "B7",
            "seat": "12A"
        ]
    )

    XCTAssertEqual(
        EventTemplateFactory().makeTemplate(from: payload),
        .flightTicket(.init(
            flightNumber: "SQ 833",
            carrier: "Singapore Airlines",
            departureAirport: "Shanghai Pudong",
            departureAirportCode: "PVG",
            arrivalAirport: "Singapore Changi",
            arrivalAirportCode: "SIN",
            departureTimeText: nil,
            arrivalTimeText: nil,
            terminal: "T3",
            gate: "B7",
            seat: "12A",
            travelStatus: nil
        ))
    )
}

func testGenericPayloadPreservesUnconsumedFieldsAcrossCodableRoundTrip() throws {
    let template = EventTemplateFactory().makeTemplate(from: .init(
        kind: .interview,
        fields: [
            "title": "Design interview",
            "location": "Zoom",
            "interviewer": "Design Lead"
        ]
    ))
    let encoded = try JSONEncoder().encode(template)
    let decoded = try JSONDecoder().decode(TimelineEventTemplate.self, from: encoded)

    guard case let .generic(event) = decoded else {
        return XCTFail("Expected generic event")
    }
    XCTAssertEqual(event.fields["interviewer"], "Design Lead")
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
swift test --filter EventTemplateFactoryTests
```

Expected: compilation fails because `flightTicket`, `FlightTicketTemplate`, and `GenericEventTemplate.fields` do not exist.

- [ ] **Step 3: Add the minimal models and mappings**

Add a `flightTicket(FlightTicketTemplate)` case and update `kind` and
`presentation`. Define `FlightTicketTemplate` with the exact properties used
by the test and a presentation whose title is the flight number, subtitle is
the `departure → arrival` route, and fields contain non-empty carrier,
terminal, gate, seat, and status values.

Change `GenericEventTemplate` to:

```swift
public let fields: [String: String]

public init(
    kind: TimelineKind,
    title: String,
    location: String?,
    notes: String?,
    fields: [String: String] = [:]
) {
    self.kind = kind
    self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    self.location = location?.nilIfBlank
    self.notes = notes?.nilIfBlank
    self.fields = fields.compactMapValues(\.nilIfBlank)
}
```

Provide a custom `init(from:)` that decodes missing `fields` as `[:]` so
existing stored records remain readable. Pass `payload.fields` into generic
templates. Map `.flight` payloads to `FlightTicketTemplate`; keep calendar
events classified as flight but without a dedicated template when no
structured payload exists.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run:

```bash
swift test --filter EventTemplateFactoryTests
```

Expected: all EventTemplateFactory tests pass.

- [ ] **Step 5: Commit the model change**

```bash
git add Sources/PeckerCore/Classification/EventTemplateFactory.swift Tests/PeckerCoreTests/EventTemplateFactoryTests.swift
git commit -m "feat: preserve structured live activity fields"
```

### Task 2: Define the Single-Item Activity State and Adapter

**Files:**
- Modify: `Shared/PeckerActivityAttributes.swift`
- Create: `Pecker/Activity/LiveActivityPresentationAdapter.swift`
- Create: `PeckerTests/LiveActivityPresentationAdapterTests.swift`
- Modify: `project.yml`
- Regenerate: `Pecker.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing adapter tests for all kinds**

Create a table of all `TimelineKind` values with expected SF Symbols:

```swift
let expected: [TimelineKind: String] = [
    .meeting: "person.2.fill",
    .task: "checklist",
    .flight: "airplane",
    .train: "train.side.front.car",
    .travel: "suitcase.fill",
    .interview: "person.text.rectangle",
    .deadline: "calendar.badge.exclamationmark",
    .unknown: "clock.fill"
]
```

For each kind, map an item and assert its identifier, title, dates, kind raw
value, and symbol. Add train and flight tests asserting route endpoints and
metadata order:

```swift
XCTAssertEqual(state.leadingEndpoint, "成都东")
XCTAssertEqual(state.trailingEndpoint, "重庆西")
XCTAssertEqual(state.metadata, ["02 车", "06D 座", "B3 检票口", "二等座"])
```

Add a generic test asserting location wins over one supporting field and
metadata never exceeds four values.

- [ ] **Step 2: Regenerate the project and verify RED**

Run:

```bash
xcodegen generate
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/LiveActivityPresentationAdapterTests
```

Expected: compilation fails because `LiveActivityPresentationAdapter` and the
new single-item content fields do not exist.

- [ ] **Step 3: Replace ContentState with bounded semantic fields**

Keep canonical dates and add:

```swift
public let itemIdentifier: String
public let title: String
public let secondaryIdentity: String?
public let kindRawValue: String
public let symbolName: String
public let statusRawValue: String
public let startDate: Date?
public let endDate: Date?
public let leadingEndpoint: String?
public let trailingEndpoint: String?
public let location: String?
public let supportingDetail: String?
public let metadata: [String]
public let generatedAt: Date
```

Retain `countdownTargetDate(at:)` and `isPrimaryRunning(at:)`, rewritten
against `startDate` and `endDate`. Remove next/pinned/supporting-row fields.

- [ ] **Step 4: Implement the pure adapter**

Implement:

```swift
struct LiveActivityPresentationAdapter: Sendable {
    func makeState(
        item: TimelineItem,
        status: PeckerLiveActivityStatus,
        generatedAt: Date
    ) -> PeckerActivityAttributes.ContentState
}
```

For train and flight templates, map dedicated endpoints and at most four
credential values. For generic items, use `item.location` then the first
non-empty value from `item.notes` and sorted preserved fields. Derive symbols
from `TimelineKind`. Never parse dates from display strings.

- [ ] **Step 5: Verify GREEN**

Run the focused xcodebuild command from Step 2.

Expected: all adapter tests pass.

- [ ] **Step 6: Commit the state and adapter**

```bash
git add Shared/PeckerActivityAttributes.swift Pecker/Activity/LiveActivityPresentationAdapter.swift PeckerTests/LiveActivityPresentationAdapterTests.swift project.yml Pecker.xcodeproj/project.pbxproj
git commit -m "feat: add single-item live activity presentation"
```

### Task 3: Reconcile and Transition One Primary Item

**Files:**
- Modify: `Pecker/Activity/ActivityCoordinator.swift`
- Modify: `Pecker/Activity/ActivityClient.swift`
- Modify: `PeckerTests/ActivityCoordinatorTests.swift`

- [ ] **Step 1: Replace coordinator expectations with failing transition tests**

Add tests:

```swift
func testRunningItemEndUpdatesToNextEligibleItem() async throws
func testFinalEligibleItemEndImmediatelyDismissesActivity() async throws
func testPrimaryStateContainsNoSupportingNextOrPinnedRows() async throws
func testDecisionReportsNearestFutureBoundary() async throws
```

The final-item test supplies an existing activity whose item identifier has
ended and an empty snapshot, then expects `.end` plus `.end(id: "current")`.
The transition test supplies the post-boundary snapshot with a new
`resolvedNextItem` and expects `.update` containing only that item.

- [ ] **Step 2: Run coordinator tests and verify RED**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/ActivityCoordinatorTests
```

Expected: tests fail against the old multi-item state and missing boundary.

- [ ] **Step 3: Inject and use the adapter**

Initialize `ActivityCoordinator` with a
`LiveActivityPresentationAdapter`. Replace `desiredState` construction with
the adapter and preserve primary priority Now → Next → unfinished pinned.

Introduce:

```swift
struct ActivityReconciliationResult: Equatable, Sendable {
    let decision: ActivityDecision
    let nextBoundary: Date?
}
```

Return the nearest future primary start/end, next start, pinned start/end, or
snapshot stale boundary. Equality of content states still suppresses redundant
ActivityKit updates, while the result always carries the current boundary.

- [ ] **Step 4: Verify coordinator GREEN**

Run the focused command from Step 2.

Expected: all coordinator tests pass.

- [ ] **Step 5: Commit reconciliation**

```bash
git add Pecker/Activity/ActivityCoordinator.swift Pecker/Activity/ActivityClient.swift PeckerTests/ActivityCoordinatorTests.swift
git commit -m "feat: reconcile live activity at item boundaries"
```

### Task 4: Render Dedicated and Generic Live Activities

**Files:**
- Modify: `Shared/PeckerLiveActivityPresentation.swift`
- Replace: `PeckerLiveActivity/LockScreenLiveActivityView.swift`
- Replace: `PeckerLiveActivity/DynamicIslandLiveActivityView.swift`
- Modify: `PeckerTests/LiveActivityPresentationTests.swift`

- [ ] **Step 1: Write failing presentation-helper tests**

Test:

```swift
XCTAssertEqual(PeckerLiveActivityCopy.endedLabel(locale: zh), "已结束")
XCTAssertEqual(PeckerLiveActivityCopy.endedLabel(locale: en), "Ended")
XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "flight"), "airplane")
XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "bogus"), "clock.fill")
XCTAssertTrue(state.hasEnded(at: endDate))
XCTAssertNil(state.countdownTargetDate(at: endDate))
```

Add metadata-bound tests ensuring only four chips render and blank strings are
removed.

- [ ] **Step 2: Run helper tests and verify RED**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/LiveActivityPresentationTests
```

Expected: missing copy/style helpers fail compilation.

- [ ] **Step 3: Implement shared style and stale helpers**

Use the approved semantic colors: green for running, blue for time/route, and
orange for travel identity. Add localized Now, Next, Pinned, remaining,
starts, and ended copy. Add `hasEnded(at:)` and safe progress calculation that
returns `nil` for invalid intervals.

- [ ] **Step 4: Build the Lock Screen layouts**

Route `train` and `flight` states through a dedicated two-endpoint view:

- Header status and timer
- Symbol plus identifier
- Endpoint times and names
- Up to four chips
- Progress only for a valid running interval

Route other kinds through one generic view:

- Header status and timer
- Type symbol, title, canonical time range
- Location and one supporting detail
- Progress only for a valid running interval

At or after `endDate`, render a neutral ended label, remove progress, and
freeze countdown at zero.

- [ ] **Step 5: Build matching Dynamic Island layouts**

Expanded uses the same single primary hierarchy with fewer chips. Compact uses
symbol plus the shortest useful identifier and remaining time. Minimal uses
the type symbol, not title abbreviation. Add previews for all eight kinds and
missing-field ticket states.

- [ ] **Step 6: Run tests and build the extension**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/LiveActivityPresentationTests
xcodebuild build -project Pecker.xcodeproj -scheme Pecker \
  -destination 'generic/platform=iOS Simulator'
```

Expected: tests pass and both app and widget extension build.

- [ ] **Step 7: Commit UI**

```bash
git add Shared/PeckerLiveActivityPresentation.swift PeckerLiveActivity/LockScreenLiveActivityView.swift PeckerLiveActivity/DynamicIslandLiveActivityView.swift PeckerTests/LiveActivityPresentationTests.swift
git commit -m "feat: render rich single-item live activities"
```

### Task 5: Add the Foreground Boundary Scheduler

**Files:**
- Create: `Pecker/Activity/LiveActivityBoundaryScheduler.swift`
- Create: `PeckerTests/LiveActivityBoundarySchedulerTests.swift`
- Modify: `Pecker/Features/Today/TodayViewModel.swift`
- Modify: `Pecker/App/AppModel.swift`
- Modify: `Pecker/App/AppDependencies.swift`
- Modify: `PeckerTests/TodayViewModelTests.swift`
- Regenerate: `Pecker.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing scheduler tests with a controllable sleeper**

Define test doubles for:

```swift
protocol LiveActivitySleeping: Sendable {
    func sleep(until date: Date) async throws
}

protocol LiveActivityBackgroundScheduling: Sendable {
    func submit(earliestBeginDate: Date?) throws
    func cancel()
}
```

Verify:

- Scheduling a second boundary cancels the first task.
- A past boundary invokes refresh immediately.
- `becameInactive` submits the current boundary.
- `cancel` prevents refresh.

- [ ] **Step 2: Regenerate and verify RED**

Run:

```bash
xcodegen generate
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/LiveActivityBoundarySchedulerTests
```

Expected: scheduler types do not exist.

- [ ] **Step 3: Implement scheduler**

Create a `@MainActor` scheduler that owns one `Task<Void, Never>`, one boundary,
and an async refresh closure. `schedule(_:)` cancels and replaces the task.
The task sleeps through the injected sleeper, checks cancellation, invokes
refresh, and relies on the resulting reconciliation to publish the next
boundary.

Production sleeping uses:

```swift
try await Task.sleep(until: .now + .seconds(delay), clock: .continuous)
```

- [ ] **Step 4: Integrate with Today and App lifecycle**

Have `TodayViewModel` publish `nextLiveActivityBoundary` from
`ActivityReconciliationResult`. Have `AppModel` update the scheduler after
each refresh, keep its foreground task while active, submit best-effort
background work when inactive, and reschedule on activation.

Preserve refresh-generation checks so a cancelled or older refresh cannot
schedule an obsolete boundary.

- [ ] **Step 5: Verify GREEN**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/LiveActivityBoundarySchedulerTests \
  -only-testing:PeckerTests/TodayViewModelTests
```

Expected: scheduler and Today model tests pass.

- [ ] **Step 6: Commit foreground scheduling**

```bash
git add Pecker/Activity/LiveActivityBoundaryScheduler.swift Pecker/Features/Today/TodayViewModel.swift Pecker/App/AppModel.swift Pecker/App/AppDependencies.swift PeckerTests/LiveActivityBoundarySchedulerTests.swift PeckerTests/TodayViewModelTests.swift Pecker.xcodeproj/project.pbxproj
git commit -m "feat: refresh live activities at foreground boundaries"
```

### Task 6: Add Best-Effort Background Boundary Refresh

**Files:**
- Modify: `Pecker/Activity/LiveActivityBoundaryScheduler.swift`
- Modify: `Pecker/App/PeckerApp.swift`
- Modify: `Pecker/App/AppModel.swift`
- Modify: `Pecker/Resources/Info.plist`
- Modify: `PeckerTests/LiveActivityBoundarySchedulerTests.swift`

- [ ] **Step 1: Write failing background-request tests**

Using a fake `LiveActivityBackgroundScheduling`, assert:

```swift
XCTAssertEqual(background.submittedDates, [boundary])
XCTAssertEqual(background.cancelCount, 1)
```

Also verify a disabled Live Activity cancels pending requests and that handling
a background refresh performs one model refresh before rescheduling.

- [ ] **Step 2: Run focused tests and verify RED**

Run the scheduler test command from Task 5.

Expected: missing background behavior assertions fail.

- [ ] **Step 3: Implement BackgroundTasks adapter**

Use identifier:

```swift
com.wenttang.pecker.live-activity-refresh
```

The production adapter removes pending requests for that identifier before
submitting a `BGAppRefreshTaskRequest` with `earliestBeginDate`.

Add to `Info.plist`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.wenttang.pecker.live-activity-refresh</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
```

Register the SwiftUI background task on the app scene and call
`AppModel.handleLiveActivityBackgroundRefresh()`. The handler refreshes once,
honors cancellation, and schedules the next boundary.

- [ ] **Step 4: Verify GREEN and configuration**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/LiveActivityBoundarySchedulerTests
plutil -lint Pecker/Resources/Info.plist
```

Expected: tests pass and plist reports `OK`.

- [ ] **Step 5: Commit background scheduling**

```bash
git add Pecker/Activity/LiveActivityBoundaryScheduler.swift Pecker/App/PeckerApp.swift Pecker/App/AppModel.swift Pecker/Resources/Info.plist PeckerTests/LiveActivityBoundarySchedulerTests.swift
git commit -m "feat: schedule background live activity refresh"
```

### Task 7: Full Regression and Visual Verification

**Files:**
- No planned source changes. A regression failure returns execution to the
  task that owns the failing behavior before this verification task resumes.

- [ ] **Step 1: Run the complete Swift package tests**

```bash
swift test
```

Expected: all PeckerCore tests pass.

- [ ] **Step 2: Run the complete app test suite**

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all PeckerTests and PeckerCoreTests pass with zero failures.

- [ ] **Step 3: Build the complete app and extension**

```bash
xcodebuild build -project Pecker.xcodeproj -scheme Pecker \
  -destination 'generic/platform=iOS Simulator'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Compare previews to the approved artifact**

Open the Lock Screen and Dynamic Island previews for train, flight, meeting,
task, travel, interview, deadline, and unknown states. Compare information
order, symbols, colors, route alignment, metadata limits, and ended fallback
against:

```text
docs/visual-design/live-activity-all-types.html
```

Correct only concrete mismatches. Re-run Step 2 after any correction.

- [ ] **Step 5: Verify the working tree and final diff**

```bash
git status --short
git diff --check
git log --oneline -8
```

Expected: no uncommitted implementation changes, no whitespace errors, and
the feature commits appear after the design and plan commits.
