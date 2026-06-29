# Timeline Management and Universal Live Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Today strictly day-scoped, persist recognized event time, add a filterable Today/Future/History manager with local CRUD, and allow every card kind to drive Live Activity while preserving Pecker's warm visual system.

**Architecture:** Add a shared `TimelineDateScope` classifier in PeckerCore, range-based EventKit reads, and a local-record mutation service. Keep the home snapshot optimized for Today while a separate observable manager loads and filters all scopes. Recognition saves canonical dates, and Live Activity uses one kind-agnostic eligibility path plus a type-aware subtitle formatter.

**Tech Stack:** Swift 6, SwiftUI, Observation, EventKit, ActivityKit, WidgetKit, Swift Testing, XCTest, JSON file persistence.

---

## File Structure

### Core

- Create `Sources/PeckerCore/Models/TimelineDateScope.swift` — shared Today/Future/History interval classification.
- Modify `Sources/PeckerCore/Models/TimelineItem.swift` — carry reminder completion state with a backward-compatible default.
- Modify `Sources/PeckerCore/Recognition/RecognitionModels.swift` — expose canonical start/end strings from provider output.
- Modify `Sources/PeckerCore/Storage/EventRepository.swift` — update and delete one local record.
- Modify `Sources/PeckerCore/Classification/EventTemplateFactory.swift` — preserve editable train fields.

### App data and behavior

- Modify `Pecker/EventKit/EventKitGatewayProtocol.swift` and `Pecker/EventKit/EventKitGateway.swift` — strict Today reminder reads and month-range reads.
- Modify `Pecker/EventKit/EventKitMapper.swift` — map completion state.
- Modify `Pecker/Recognition/SystemEventRecognitionCoordinator.swift` — parse and persist recognized dates; stop substituting recognition time.
- Modify `Pecker/Recognition/ImageRecognitionStore.swift` — expose safe image deletion to local CRUD.
- Create `Pecker/Features/Timeline/TimelineManagerModel.swift` — independent loading, scope filtering, edit, delete, and refresh.
- Create `Pecker/Features/Timeline/TimelineRecordEditor.swift` — validated editable local-record draft.
- Modify `Pecker/Features/Today/TodayViewModel.swift` — enforce the shared Today scope.
- Modify `Pecker/Features/Today/TodayPresentation.swift` — correct remaining count.
- Modify `Pecker/Activity/ActivityCoordinator.swift` — universal card eligibility and type-aware subtitles.

### UI and composition

- Modify `Pecker/App/AppDependencies.swift` — inject repository, image store, and timeline manager dependencies.
- Modify `Pecker/App/AppModel.swift` — own and refresh the manager.
- Modify `Pecker/Features/Today/TodayView.swift` — route the summary to the manager and local detail to editing.
- Replace `Pecker/Features/Timeline/FullTimelineView.swift` — warm Today/Future/History segmented timeline with kind chips and local actions.
- Modify `Pecker/Features/Detail/ItemDetailView.swift` — show read-only system details and local edit/delete controls.
- Modify `Pecker/Design/TimelineTheme.swift` and `Pecker/Design/TimelineCard.swift` only to add reusable warm controls; retain the existing warm background.
- Modify `Shared/PeckerLiveActivityPresentation.swift` and Live Activity views only where needed for kind-agnostic status presentation.
- Modify `Pecker.xcodeproj/project.pbxproj` — add new source and test files to the app/test targets.

### Tests

- Create `Tests/PeckerCoreTests/TimelineDateScopeTests.swift`.
- Modify `Tests/PeckerCoreTests/EventRepositoryTests.swift`.
- Modify `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`.
- Modify `PeckerTests/EventKitMapperTests.swift`.
- Modify `PeckerTests/TodayViewModelTests.swift`.
- Modify `PeckerTests/TodayPresentationTests.swift`.
- Modify `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`.
- Create `PeckerTests/TimelineManagerModelTests.swift`.
- Create `PeckerTests/TimelineRecordEditorTests.swift`.
- Modify `PeckerTests/ActivityCoordinatorTests.swift`.
- Modify `PeckerTests/LiveActivityPresentationTests.swift`.

## Task 1: Shared date scopes and completion metadata

**Files:**
- Create: `Sources/PeckerCore/Models/TimelineDateScope.swift`
- Modify: `Sources/PeckerCore/Models/TimelineItem.swift`
- Create: `Tests/PeckerCoreTests/TimelineDateScopeTests.swift`

- [ ] **Step 1: Write failing scope tests**

Cover exact-midnight boundaries, an item intersecting Today, a future item,
a historical item, and a cross-midnight item:

```swift
@Test func classifiesCrossMidnightItemAsToday() throws {
    let calendar = utcCalendar()
    let now = date("2026-06-28T12:00:00Z")
    let item = makeItem(
        start: date("2026-06-27T23:30:00Z"),
        end: date("2026-06-28T00:30:00Z")
    )

    #expect(
        TimelineDateScope.classify(item, calendar: calendar, now: now) == .today
    )
}

@Test func completionDoesNotChangeHistoricalScope() throws {
    let item = makeItem(
        start: date("2026-06-27T09:00:00Z"),
        end: nil,
        isCompleted: false
    )
    #expect(
        TimelineDateScope.classify(
            item,
            calendar: utcCalendar(),
            now: date("2026-06-28T12:00:00Z")
        ) == .history
    )
}
```

- [ ] **Step 2: Run the tests and verify failure**

Run:

```bash
swift test --filter TimelineDateScopeTests
```

Expected: compilation fails because `TimelineDateScope` and
`TimelineItem.isCompleted` do not exist.

- [ ] **Step 3: Add the classifier and completion field**

Implement:

```swift
public enum TimelineDateScope: String, CaseIterable, Sendable {
    case today
    case future
    case history

    public static func classify(
        _ item: TimelineItem,
        calendar: Calendar,
        now: Date
    ) -> Self {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: startOfToday
        )!
        let effectiveEnd = item.endDate.flatMap { $0 > item.startDate ? $0 : nil }
            ?? item.startDate.addingTimeInterval(0.001)

        if item.startDate < startOfTomorrow && effectiveEnd > startOfToday {
            return .today
        }
        return item.startDate >= startOfTomorrow ? .future : .history
    }
}
```

Add `public let isCompleted: Bool` to `TimelineItem`, add
`isCompleted: Bool = false` to its initializer, and assign it.

- [ ] **Step 4: Run core tests**

Run:

```bash
swift test
```

Expected: all PeckerCore tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PeckerCore/Models/TimelineDateScope.swift Sources/PeckerCore/Models/TimelineItem.swift Tests/PeckerCoreTests/TimelineDateScopeTests.swift
git commit -m "feat: add shared timeline date scopes"
```

## Task 2: Strict Today reads and correct remaining count

**Files:**
- Modify: `Pecker/EventKit/EventKitGatewayProtocol.swift`
- Modify: `Pecker/EventKit/EventKitGateway.swift`
- Modify: `Pecker/EventKit/EventKitMapper.swift`
- Modify: `Pecker/Features/Today/TodayViewModel.swift`
- Modify: `Pecker/Features/Today/TodayPresentation.swift`
- Modify: `PeckerTests/EventKitMapperTests.swift`
- Modify: `PeckerTests/TodayViewModelTests.swift`
- Modify: `PeckerTests/TodayPresentationTests.swift`
- Modify: gateway fakes in `PeckerTests/OnboardingStateTests.swift`

- [ ] **Step 1: Write failing Today regression tests**

Add tests that provide an old incomplete reminder, a future external ticket,
an active item, an upcoming item, an elapsed item, and a completed reminder:

```swift
func testRemainingCountIncludesActiveAndUpcomingOnly() {
    let snapshot = snapshot(items: [
        item(id: "active", start: hour(10), end: hour(13)),
        item(id: "upcoming", start: hour(14), end: hour(15)),
        item(id: "elapsed", start: hour(8), end: hour(9)),
        item(id: "done", start: hour(16), end: nil, isCompleted: true)
    ])

    XCTAssertEqual(
        TodayPresentation.summaryCount(for: snapshot, now: hour(12)),
        2
    )
}
```

In `TodayViewModelTests`, assert that both the old reminder and tomorrow's
local ticket are absent from the resulting snapshot.

- [ ] **Step 2: Run the targeted app tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/TodayPresentationTests \
  -only-testing:PeckerTests/TodayViewModelTests
```

Expected: count and strict-day assertions fail.

- [ ] **Step 3: Make EventKit range-based**

Extend the gateway protocol with:

```swift
func fetchEvents(
    in interval: DateInterval,
    calendar: Calendar
) async throws -> [EventRecord]

func fetchReminders(
    in interval: DateInterval,
    calendar: Calendar
) async throws -> [ReminderRecord]
```

Add `isCompleted` to `ReminderRecord`. Make `fetchToday` delegate to
`fetchEvents(in:)`. Make the Today reminder call use a lower and upper bound,
not `nil`, and filter with:

```swift
interval.contains(dueDate)
```

Range reminder loading uses `predicateForReminders(in: nil)` and filters
returned reminders by due date, mapping `reminder.isCompleted`.

- [ ] **Step 4: Enforce scope after all Today sources are merged**

After mapping calendar, reminder, and recognized image items in
`TodayViewModel.refresh()`, retain only:

```swift
items.filter {
    TimelineDateScope.classify($0, calendar: dependencies.calendar, now: now)
        == .today
}
```

Map reminder completion through `EventKitMapper`.

- [ ] **Step 5: Correct the count**

Change the API to:

```swift
static func summaryCount(for snapshot: TodaySnapshot, now: Date) -> Int {
    snapshot.items.filter { item in
        guard !item.isCompleted else { return false }
        if let endDate = item.endDate {
            return endDate > now
        }
        return item.startDate >= now
    }.count
}
```

Update `TodayScreenContent` to pass its current `now`.

- [ ] **Step 6: Run targeted and full app tests**

Run the targeted command from Step 2, then:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Pecker/EventKit Pecker/Features/Today PeckerTests
git commit -m "fix: keep the Today timeline day scoped"
```

## Task 3: Canonical recognized event timing

**Files:**
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Modify: `Sources/PeckerCore/Classification/EventTemplateFactory.swift`
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `Pecker/Features/Today/TodayScreenContent.swift`
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`
- Modify: `Tests/PeckerCoreTests/EventTemplateFactoryTests.swift`
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`

- [ ] **Step 1: Write failing provider and persistence tests**

Decode a response with `eventDate`, `startDateTime`, and `endDateTime`, then
recognize/save the C5770 fixture:

```swift
let payload = ExternalEventTemplatePayload(
    kind: .train,
    fields: [
        "eventDate": "2026-06-28",
        "startDateTime": "2026-06-28T10:30:00+08:00",
        "endDateTime": "2026-06-28T11:48:00+08:00",
        "trainNumber": "C5770",
        "departureStation": "成都东",
        "arrivalStation": "重庆西",
        "carriageNumber": "02",
        "seatNumber": "06D",
        "checkInGate": "B3",
        "seatClass": "二等座",
        "price": "¥96",
        "ticketNumber": "E123456789"
    ]
)
```

Assert the saved dates equal `2026-06-28T02:30:00Z` and
`2026-06-28T03:48:00Z`. Add an overnight test where 23:30 to 01:00 rolls the
end to the next day.

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter OpenAIRecognitionProviderTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests
```

Expected: saved record still uses recognition time.

- [ ] **Step 3: Strengthen the recognition prompt**

Require these fields for actionable image events:

```text
eventDate, startDateTime, endDateTime
```

State that ISO-8601 with an explicit offset is preferred, visible values must
not be guessed, and train fields remain strings.

- [ ] **Step 4: Parse canonical timing into the draft**

Add `startDate` and `endDate` to `ImageRecognitionDraft`. Introduce a focused
parser in `SystemEventRecognitionCoordinator` that:

1. Parses ISO-8601 `startDateTime` and `endDateTime`.
2. Falls back to `eventDate` plus `departureTime`/`arrivalTime`.
3. Applies the current calendar/time zone.
4. Rolls arrival forward one day only when no explicit arrival date exists.
5. Throws `RecognitionError.invalidResponse` for a missing or invalid start.

Store those dates in `saveRecognizedImage`; keep `recognizedAt` only as
`updatedAt`.

- [ ] **Step 5: Preserve the complete train card**

Add optional `seatClass` and `priceText` fields to `TrainTicketTemplate`,
including backward-compatible decoding defaults, payload aliases, presentation
rows, and editor fields. Keep `ticketNumber` as the canonical order/ticket
identifier so E123456789 is not lost.

- [ ] **Step 6: Show timing in confirmation UI**

Add the parsed date/time range to the recognition confirmation card and keep
Save unavailable for an invalid draft. Do not display model reasoning; the
existing typing state remains the only recognition-in-progress presentation.

- [ ] **Step 7: Run core and app tests**

Run:

```bash
swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all tests pass, including the C5770 and overnight fixtures.

- [ ] **Step 8: Commit**

```bash
git add Sources/PeckerCore/Recognition Pecker/Recognition Pecker/Features/Today PeckerTests Tests
git commit -m "feat: persist recognized event timing"
```

## Task 4: Local record editing and deletion

**Files:**
- Modify: `Sources/PeckerCore/Storage/EventRepository.swift`
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `Pecker/Recognition/ImageRecognitionStore.swift`
- Create: `Pecker/Features/Timeline/TimelineRecordEditor.swift`
- Modify: `Tests/PeckerCoreTests/EventRepositoryTests.swift`
- Create: `PeckerTests/TimelineRecordEditorTests.swift`

- [ ] **Step 1: Write failing repository and editor tests**

Test delete-by-ID, preservation of unrelated records, end-before-start
validation, editable train fields, and deletion of the attached image:

```swift
try await repository.delete(id: "image:ticket")
let remaining = try await repository.loadAll()
#expect(remaining.map(\.id) == ["image:other"])
```

```swift
func testRejectsEndBeforeStart() {
    var draft = TimelineRecordEditor(record: record)
    draft.startDate = hour(12)
    draft.endDate = hour(11)
    XCTAssertEqual(draft.validationError, .endBeforeStart)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter EventRepositoryTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/TimelineRecordEditorTests
```

Expected: missing mutation APIs and editor type.

- [ ] **Step 3: Add record-level mutation**

Add:

```swift
public func record(id: String) throws -> StoredEventRecord?
public func delete(id: String) throws
```

Keep `upsert` as the update operation and preserve atomic JSON writes.

- [ ] **Step 4: Add a local record service**

Extend the app-side repository protocol with load/upsert/delete-by-ID. Add a
`LocalTimelineRecordService` that owns the repository and image store.
Deletion first removes the record atomically, then removes the image reference;
an image cleanup failure is surfaced as a cleanup error without restoring the
record.

- [ ] **Step 5: Add the editable draft**

`TimelineRecordEditor` exposes title, kind, start, optional end, location,
notes, and train template fields. `makeRecord(updatedAt:)` validates a
non-empty title, valid start, and `end > start`, then returns a new
`StoredEventRecord` preserving id, source, source identifier, and image
reference.

- [ ] **Step 6: Run tests**

Run the commands from Step 2, then `swift test`.

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/PeckerCore/Storage Pecker/Recognition Pecker/Features/Timeline PeckerTests Tests
git commit -m "feat: edit and delete local timeline records"
```

## Task 5: Independent timeline manager

**Files:**
- Create: `Pecker/Features/Timeline/TimelineManagerModel.swift`
- Replace: `Pecker/Features/Timeline/FullTimelineView.swift`
- Modify: `Pecker/Features/Timeline/TimelineGrouping.swift`
- Modify: `Pecker/App/AppDependencies.swift`
- Modify: `Pecker/App/AppModel.swift`
- Modify: `Pecker/Features/Today/TodayView.swift`
- Create: `PeckerTests/TimelineManagerModelTests.swift`
- Modify: `Pecker.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing manager tests**

Use gateway and local-service fakes to verify:

- Initial load requests the current month.
- Today/Future/History never leak into each other.
- History is reverse chronological.
- A `.train` filter persists when switching from Today to Future.
- Local mutation refreshes items.
- EventKit items report read-only ownership.

```swift
model.selectedKind = .train
model.selectedScope = .future
await model.load()
XCTAssertEqual(model.visibleItems.map(\.kind), [.train])
model.selectedScope = .today
XCTAssertEqual(model.selectedKind, .train)
```

- [ ] **Step 2: Run the new tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/TimelineManagerModelTests
```

Expected: manager type is missing.

- [ ] **Step 3: Implement manager state and monthly loading**

Create an `@MainActor @Observable` model with:

```swift
var selectedScope: TimelineDateScope = .today
var selectedKind: TimelineKind?
private(set) var items: [TimelineItem] = []
private(set) var recordsByID: [String: StoredEventRecord] = [:]
private(set) var loadError: String?

var visibleItems: [TimelineItem] { /* scope + kind + stable sort */ }
func load(now: Date = .now) async
func loadAdjacentMonth(direction: Int, now: Date = .now) async
func save(_ editor: TimelineRecordEditor, now: Date = .now) async throws
func delete(itemID: String) async throws
func isEditable(_ item: TimelineItem) -> Bool
```

Deduplicate mapped items by id. Merge successful sources when another source
fails and retain the last successful content.

- [ ] **Step 4: Build the warm timeline manager UI**

Use `TimelineTheme.backgroundGradient`, `TimelineCard`, a warm glass segmented
scope control, a horizontally scrolling single-select kind chip row, and a
continuous timeline rail. Do not introduce a dark page background.

Rows show ownership, kind, title, date/time, status, and relevant template
details. Swipe/context edit and delete actions appear only for external/local
items. System items open read-only detail.

- [ ] **Step 5: Wire navigation and refresh**

The Today summary opens the manager at `.today`. Active-items navigation can
use the manager with an active-only presentation filter. `AppModel` owns one
manager so selection and loaded pages survive navigation. Saving/deleting calls
`todayViewModel.refresh()` and reconciles Live Activity through that refresh.

- [ ] **Step 6: Run manager and full app tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Pecker/Features/Timeline Pecker/Features/Today Pecker/App PeckerTests Pecker.xcodeproj/project.pbxproj
git commit -m "feat: add timeline management scopes and filters"
```

## Task 6: Local editor and destructive-action UI

**Files:**
- Modify: `Pecker/Features/Detail/ItemDetailView.swift`
- Modify: `Pecker/Features/Timeline/FullTimelineView.swift`
- Modify: `Pecker/Features/Today/TodayView.swift`
- Modify: `Pecker/Design/TimelineTheme.swift`
- Modify: `Pecker/Design/TimelineCard.swift`
- Modify: `PeckerTests/ItemDetailActionTests.swift`

- [ ] **Step 1: Write failing ownership/action tests**

Assert calendar/reminder items expose no edit/delete actions, while an external
record exposes both. Assert a successful delete clears a matching manual pin
before refreshing.

- [ ] **Step 2: Run targeted tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/ItemDetailActionTests
```

Expected: local ownership actions are unavailable.

- [ ] **Step 3: Add the editor view**

Present a warm-themed form in cards, with date pickers and kind selection plus
train-specific text fields. Disable Save when validation fails. Keep the
editor open and show an inline error on persistence failure.

- [ ] **Step 4: Add confirmed delete**

Show a destructive confirmation dialog naming the item. On success, dismiss
detail/editor, clear the matching pin, reload manager, refresh Today, and
reconcile Live Activity. On failure, leave the card and image visible.

- [ ] **Step 5: Verify visual tokens**

Add only reusable control-fill, selected-chip, destructive, and editor-section
tokens to `TimelineTheme`. Retain the current warm gradient, 30-point
continuous card radius, warm text colors, and green/blue/orange accents.

- [ ] **Step 6: Run full tests**

Run the full `xcodebuild test` command from Task 5.

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Pecker/Features Pecker/Design PeckerTests
git commit -m "feat: add warm local timeline editor"
```

## Task 7: Universal Live Activity presentation

**Files:**
- Modify: `Pecker/Activity/ActivityCoordinator.swift`
- Modify: `Shared/PeckerLiveActivityPresentation.swift`
- Modify: `PeckerLiveActivity/LockScreenLiveActivityView.swift`
- Modify: `PeckerLiveActivity/DynamicIslandLiveActivityView.swift`
- Modify: `PeckerTests/ActivityCoordinatorTests.swift`
- Modify: `PeckerTests/LiveActivityPresentationTests.swift`

- [ ] **Step 1: Write a failing eligibility matrix**

Loop over all kinds and assert each can become primary:

```swift
for kind in TimelineKind.allCases {
    let item = makeItem(kind: kind, start: now, end: now.addingTimeInterval(900))
    let decision = coordinatorDecision(for: item, now: now)
    XCTAssertEqual(decision.primaryKind, kind)
}
```

Add subtitle tests for train route/seat/gate, flight location, meeting
location, task notes, and unknown fallback. Add active-item deletion fallback
and no-candidate end tests.

- [ ] **Step 2: Run targeted tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/ActivityCoordinatorTests \
  -only-testing:PeckerTests/LiveActivityPresentationTests
```

Expected: kind-specific status inference and train details fail.

- [ ] **Step 3: Add a type-aware subtitle adapter**

Keep primary selection kind-agnostic. Format only the subtitle:

```swift
private func subtitle(for item: TimelineItem) -> String? {
    switch item.template {
    case let .trainTicket(ticket):
        return compact([
            route(ticket),
            compact([ticket.carriageNumber.map { "\($0)车" },
                     ticket.seatNumber,
                     ticket.checkInGate.map { "\($0)检票" }])
        ])
    case nil:
        return firstNonEmpty(item.location, item.notes)
    }
}
```

Do not infer pinned status from `kind == .travel` or source identifier text.
Add `primaryStatusRawValue` to shared content state and populate it explicitly
from the coordinator's selected role (`now`, `next`, or `pinned`).

- [ ] **Step 4: Update Live Activity views**

Render status from explicit state, not title equality. Preserve the existing
warm-brown Live Activity palette and compact information hierarchy. Ensure
long subtitles truncate safely in Lock Screen and Dynamic Island families.

- [ ] **Step 5: Run targeted and full tests**

Run the targeted command, then the full app test command.

Expected: all `TimelineKind` cases pass and existing Live Activity snapshots
remain valid.

- [ ] **Step 6: Commit**

```bash
git add Pecker/Activity Shared PeckerLiveActivity PeckerTests
git commit -m "feat: support every card in live activity"
```

## Task 8: Visual and end-to-end verification

**Files:**
- Modify only files required by failures found in this task.
- Add screenshots under `docs/verification/` when captures are available.

- [ ] **Step 1: Run core tests**

```bash
swift test
```

Expected: all PeckerCore tests pass.

- [ ] **Step 2: Run the complete iOS test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all app and Live Activity tests pass.

- [ ] **Step 3: Build for a generic simulator**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'generic/platform=iOS Simulator'
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Verify the supplied ticket flow**

At Asia/Shanghai time on 2026-06-28, recognize and save the supplied image.
Verify:

- C5770 is dated 2026-06-28 from 10:30 to 11:48.
- The route is 成都东 → 重庆西.
- The card shows 02车, 06D, and B3.
- It is in Today, not Future or History.
- Before departure it can be Next/Pinned.
- During the journey it is Now with progress.
- After deletion it disappears and Live Activity falls back or ends.

- [ ] **Step 5: Capture and compare visual states**

Capture Today, all three manager scopes, a filtered train view, the local
editor, C5770 detail, Lock Screen Live Activity, and Dynamic Island. Compare
against the original hierarchy references while enforcing the current warm
app palette:

- warm cream gradient remains visible;
- warm translucent cards and 30-point radius remain consistent;
- timeline rail and nodes remain continuous;
- Now/Next/Pinned retain green/blue/orange meaning;
- filters and editor look native to the same screen family.

- [ ] **Step 6: Run repository hygiene checks**

```bash
git diff --check
git status --short
```

Expected: no whitespace errors and only intentional changes.

- [ ] **Step 7: Commit verification artifacts or final fixes**

```bash
git add docs/verification Pecker Sources Shared PeckerLiveActivity PeckerTests Tests Pecker.xcodeproj/project.pbxproj
git commit -m "test: verify timeline management flow"
```

Skip this commit only when Step 8 produced no new artifacts or fixes.
