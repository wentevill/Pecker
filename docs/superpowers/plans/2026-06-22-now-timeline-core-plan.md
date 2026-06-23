# Now Timeline Core and Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> Historical note: this implementation plan predates the rename. The shipping
> app and project identity is now Pecker: Xcode project/scheme/app target
> `Pecker`, core module `PeckerCore`, bundle identifier `com.wenttang.pecker`,
> and App Group `group.com.wenttang.pecker`.

**Goal:** Build a platform-neutral Swift package that deterministically converts normalized calendar and reminder records into a versioned Today snapshot.

**Architecture:** `NowTimelineCore` contains value types and pure services with no SwiftUI, EventKit, ActivityKit, or iOS dependency. Classification, ranking, settings, snapshot construction, and file persistence are independently testable.

**Tech Stack:** Swift 6, Swift Package Manager, Foundation, Swift Testing.

---

## File map

```text
Package.swift
Sources/NowTimelineCore/
  Models/TimelineItem.swift
  Models/TimelineSettings.swift
  Models/TodaySnapshot.swift
  Classification/TimelineClassifier.swift
  Engine/TimelineEngine.swift
  Storage/SnapshotStore.swift
Tests/NowTimelineCoreTests/
  TimelineClassifierTests.swift
  TimelineEngineTests.swift
  SnapshotStoreTests.swift
```

### Task 1: Create the Swift package and domain models

**Files:**
- Create: `Package.swift`
- Create: `Sources/NowTimelineCore/Models/TimelineItem.swift`
- Create: `Sources/NowTimelineCore/Models/TimelineSettings.swift`
- Create: `Sources/NowTimelineCore/Models/TodaySnapshot.swift`
- Test: `Tests/NowTimelineCoreTests/ModelTests.swift`

- [ ] **Step 1: Write the model test**

```swift
import Foundation
import Testing
@testable import NowTimelineCore

@Test func snapshotRoundTrips() throws {
    let item = TimelineItem(
        id: "calendar:event-1",
        sourceIdentifier: "event-1",
        title: "Daily Standup",
        startDate: Date(timeIntervalSince1970: 100),
        endDate: Date(timeIntervalSince1970: 200),
        isAllDay: false,
        source: .calendar,
        kind: .meeting,
        location: nil,
        notes: nil
    )
    let value = TodaySnapshot(
        schemaVersion: 1,
        generatedAt: .init(timeIntervalSince1970: 50),
        staleAfter: .init(timeIntervalSince1970: 300),
        items: [item],
        nowItemID: item.id,
        concurrentNowCount: 0,
        nextItemID: nil,
        pinnedItemID: nil,
        pinOrigin: nil
    )

    let decoded = try JSONDecoder().decode(
        TodaySnapshot.self,
        from: JSONEncoder().encode(value)
    )
    #expect(decoded == value)
}
```

- [ ] **Step 2: Run the test and verify package setup is missing**

Run: `swift test`

Expected: FAIL because `Package.swift` or `NowTimelineCore` does not exist.

- [ ] **Step 3: Add package and models**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NowTimeline",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [
        .library(name: "NowTimelineCore", targets: ["NowTimelineCore"])
    ],
    targets: [
        .target(name: "NowTimelineCore"),
        .testTarget(
            name: "NowTimelineCoreTests",
            dependencies: ["NowTimelineCore"]
        )
    ]
)
```

Define the public enums and `TimelineItem` exactly as specified:

```swift
public enum TimelineSource: String, Codable, Sendable {
    case calendar, reminder
}

public enum TimelineKind: String, Codable, Sendable {
    case meeting, task, flight, train, travel, interview, deadline, unknown
}

public struct TimelineItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let sourceIdentifier: String
    public let title: String
    public let startDate: Date
    public let endDate: Date?
    public let isAllDay: Bool
    public let source: TimelineSource
    public let kind: TimelineKind
    public let location: String?
    public let notes: String?
}
```

Add:

```swift
public struct TimelineSettings: Codable, Equatable, Sendable {
    public var calendarEnabled = true
    public var remindersEnabled = true
    public var showTravelEvents = true
    public var reminderDurationMinutes = 30
    public var manualPinnedSourceIdentifier: String?
    public var liveActivityEnabled = false
}

public enum PinOrigin: String, Codable, Sendable {
    case automatic, manual
}

public struct TodaySnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int
    public let generatedAt: Date
    public let staleAfter: Date
    public let items: [TimelineItem]
    public let nowItemID: String?
    public let concurrentNowCount: Int
    public let nextItemID: String?
    public let pinnedItemID: String?
    public let pinOrigin: PinOrigin?
}
```

Provide explicit public initializers for all public structs.

- [ ] **Step 4: Run the model test**

Run: `swift test --filter snapshotRoundTrips`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests/NowTimelineCoreTests/ModelTests.swift
git commit -m "feat: add timeline core models"
```

### Task 2: Implement deterministic keyword classification

**Files:**
- Create: `Sources/NowTimelineCore/Classification/TimelineClassifier.swift`
- Test: `Tests/NowTimelineCoreTests/TimelineClassifierTests.swift`

- [ ] **Step 1: Write failing precedence tests**

```swift
import Testing
@testable import NowTimelineCore

@Test(arguments: [
    ("SQ833 Flight to Singapore", "T3 Gate B7", nil, TimelineKind.flight),
    ("高铁 G123", "上海虹桥站", nil, TimelineKind.train),
    ("Product Interview Meeting", nil, nil, TimelineKind.interview),
    ("Project Deadline", nil, "截止今天", TimelineKind.deadline),
    ("Daily Standup", nil, "Zoom", TimelineKind.meeting),
    ("Buy milk", nil, nil, TimelineKind.task)
])
func classifies(
    title: String,
    location: String?,
    notes: String?,
    expected: TimelineKind
) {
    #expect(
        TimelineClassifier().classify(
            title: title,
            location: location,
            notes: notes,
            source: .reminder
        ) == expected
    )
}
```

- [ ] **Step 2: Verify failure**

Run: `swift test --filter classifies`

Expected: FAIL because `TimelineClassifier` is missing.

- [ ] **Step 3: Add the classifier**

Implement a `public struct TimelineClassifier: Sendable` with:

```swift
public func classify(
    title: String,
    location: String?,
    notes: String?,
    source: TimelineSource
) -> TimelineKind
```

Normalize the joined fields using
`folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)`.
Check in this exact order:

1. flight keywords and flight-number regex `\b[A-Z]{2}\s?\d{2,4}\b`;
2. train keywords;
3. interview keywords;
4. deadline keywords;
5. meeting keywords;
6. `.task` for reminders;
7. `.unknown`.

When `showTravelEvents` is false, the engine will downgrade flight/train/travel;
the classifier itself remains deterministic.

- [ ] **Step 4: Run classifier tests**

Run: `swift test --filter TimelineClassifierTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NowTimelineCore/Classification Tests/NowTimelineCoreTests/TimelineClassifierTests.swift
git commit -m "feat: classify timeline items"
```

### Task 3: Implement Now and Next selection

**Files:**
- Create: `Sources/NowTimelineCore/Engine/TimelineEngine.swift`
- Test: `Tests/NowTimelineCoreTests/TimelineEngineTests.swift`

- [ ] **Step 1: Write boundary and conflict tests**

Create fixed dates and assert:

```swift
@Test func selectsHighestPriorityNowAndCountsConflicts() {
    let now = Date(timeIntervalSince1970: 1_000)
    let meeting = item("meeting", .meeting, 900, 1_100)
    let flight = item("flight", .flight, 950, 1_200)

    let snapshot = TimelineEngine().makeSnapshot(
        items: [meeting, flight],
        now: now,
        settings: .init(),
        staleInterval: 900
    )

    #expect(snapshot.nowItemID == flight.id)
    #expect(snapshot.concurrentNowCount == 1)
}

@Test func excludesItemAtExactEndAndSelectsEarliestNext() {
    let now = Date(timeIntervalSince1970: 1_000)
    let ended = item("ended", .meeting, 900, 1_000)
    let later = item("later", .meeting, 1_200, 1_300)
    let next = item("next", .task, 1_100, 1_200)

    let snapshot = TimelineEngine().makeSnapshot(
        items: [later, ended, next],
        now: now,
        settings: .init(),
        staleInterval: 900
    )

    #expect(snapshot.nowItemID == nil)
    #expect(snapshot.nextItemID == next.id)
}
```

Add a private test helper that constructs `TimelineItem` from epoch seconds.

- [ ] **Step 2: Verify failure**

Run: `swift test --filter TimelineEngineTests`

Expected: FAIL because `TimelineEngine` is missing.

- [ ] **Step 3: Implement sorting and selection**

Add:

```swift
public struct TimelineEngine: Sendable {
    public init(classifier: TimelineClassifier = .init()) {}

    public func makeSnapshot(
        items: [TimelineItem],
        now: Date,
        settings: TimelineSettings,
        staleInterval: TimeInterval
    ) -> TodaySnapshot
}
```

Filter disabled sources. If travel display is disabled, map travel kinds to
`.unknown`. Sort by `startDate`, then `endDate ?? .distantFuture`, then title.
Exclude all-day items from Now and Next. Apply the approved Now priority and
stable tie-breakers.

- [ ] **Step 4: Run engine tests**

Run: `swift test --filter TimelineEngineTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NowTimelineCore/Engine Tests/NowTimelineCoreTests/TimelineEngineTests.swift
git commit -m "feat: calculate now and next items"
```

### Task 4: Implement automatic and manual pinning

**Files:**
- Modify: `Sources/NowTimelineCore/Engine/TimelineEngine.swift`
- Modify: `Tests/NowTimelineCoreTests/TimelineEngineTests.swift`

- [ ] **Step 1: Add failing pin tests**

Cover:

```swift
@Test func manualPinOverridesAutomaticFlight() {
    let now = Date(timeIntervalSince1970: 1_000)
    let flight = item("flight", .flight, 1_200, 1_400)
    let interview = item("interview", .interview, 1_300, 1_500)
    var settings = TimelineSettings()
    settings.manualPinnedSourceIdentifier = interview.sourceIdentifier

    let snapshot = TimelineEngine().makeSnapshot(
        items: [flight, interview],
        now: now,
        settings: settings,
        staleInterval: 900
    )

    #expect(snapshot.pinnedItemID == interview.id)
    #expect(snapshot.pinOrigin == .manual)
}

@Test func missingManualPinFallsBackToAutomatic() {
    let now = Date(timeIntervalSince1970: 1_000)
    let flight = item("flight", .flight, 1_200, 1_400)
    var settings = TimelineSettings()
    settings.manualPinnedSourceIdentifier = "deleted-event"

    let snapshot = TimelineEngine().makeSnapshot(
        items: [flight],
        now: now,
        settings: settings,
        staleInterval: 900
    )

    #expect(snapshot.pinnedItemID == flight.id)
    #expect(snapshot.pinOrigin == .automatic)
}

@Test func completedItemsCannotBePinned() {
    let now = Date(timeIntervalSince1970: 1_000)
    let flight = item("flight", .flight, 800, 900)

    let snapshot = TimelineEngine().makeSnapshot(
        items: [flight],
        now: now,
        settings: TimelineSettings(),
        staleInterval: 900
    )

    #expect(snapshot.pinnedItemID == nil)
    #expect(snapshot.pinOrigin == nil)
}

@Test func automaticPriorityIsFlightTrainInterviewMeetingDeadline() {
    let now = Date(timeIntervalSince1970: 1_000)
    let deadline = item("deadline", .deadline, 1_050, 1_100)
    let meeting = item("meeting", .meeting, 1_060, 1_200)
    let interview = item("interview", .interview, 1_070, 1_300)
    let train = item("train", .train, 1_080, 1_400)
    let flight = item("flight", .flight, 1_090, 1_500)

    let snapshot = TimelineEngine().makeSnapshot(
        items: [deadline, meeting, interview, train, flight],
        now: now,
        settings: TimelineSettings(),
        staleInterval: 900
    )

    #expect(snapshot.pinnedItemID == flight.id)
}
```

Use exact fixed dates and identifiers; do not depend on the current clock.

- [ ] **Step 2: Verify failure**

Run: `swift test --filter "manualPinOverridesAutomaticFlight|missingManualPinFallsBackToAutomatic|completedItemsCannotBePinned|automaticPriority"`

Expected: at least the manual-pin test FAILS.

- [ ] **Step 3: Implement pin selection**

Select an unfinished item matching
`settings.manualPinnedSourceIdentifier` first. Otherwise choose the earliest
eligible item within the approved kind priority. Set `pinOrigin` consistently.

- [ ] **Step 4: Run all engine tests**

Run: `swift test --filter TimelineEngineTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NowTimelineCore/Engine/TimelineEngine.swift Tests/NowTimelineCoreTests/TimelineEngineTests.swift
git commit -m "feat: rank automatic and manual pins"
```

### Task 5: Add versioned atomic JSON persistence

**Files:**
- Create: `Sources/NowTimelineCore/Storage/SnapshotStore.swift`
- Test: `Tests/NowTimelineCoreTests/SnapshotStoreTests.swift`

- [ ] **Step 1: Write failing storage tests**

Test:

```swift
@Test func savesAndLoadsSnapshot() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    let store = SnapshotStore(directoryURL: directory)
    let snapshot = emptySnapshot(schemaVersion: 1)

    try await store.save(snapshot)

    guard case .value(let loaded) = await store.load() else {
        Issue.record("Expected a stored snapshot")
        return
    }
    #expect(loaded == snapshot)
}

@Test func reportsMissingSnapshot() async {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    let store = SnapshotStore(directoryURL: directory)

    guard case .missing = await store.load() else {
        Issue.record("Expected missing")
        return
    }
}

@Test func reportsCorruptSnapshot() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    try Data("not-json".utf8).write(
        to: directory.appending(path: "today_snapshot.json")
    )

    guard case .corrupt = await SnapshotStore(directoryURL: directory).load()
    else {
        Issue.record("Expected corrupt")
        return
    }
}

@Test func rejectsUnsupportedSchema() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    let store = SnapshotStore(directoryURL: directory)
    try await store.save(emptySnapshot(schemaVersion: 999))

    guard case .unsupportedSchema(let version) = await store.load() else {
        Issue.record("Expected unsupported schema")
        return
    }
    #expect(version == 999)
}
```

Add this test helper:

```swift
private func emptySnapshot(schemaVersion: Int) -> TodaySnapshot {
    TodaySnapshot(
        schemaVersion: schemaVersion,
        generatedAt: Date(timeIntervalSince1970: 100),
        staleAfter: Date(timeIntervalSince1970: 200),
        items: [],
        nowItemID: nil,
        concurrentNowCount: 0,
        nextItemID: nil,
        pinnedItemID: nil,
        pinOrigin: nil
    )
}
```

- [ ] **Step 2: Verify failure**

Run: `swift test --filter SnapshotStoreTests`

Expected: FAIL because storage types are missing.

- [ ] **Step 3: Implement actor-based storage**

```swift
public enum SnapshotLoadResult: Sendable {
    case value(TodaySnapshot)
    case missing
    case corrupt
    case unsupportedSchema(Int)
}

public actor SnapshotStore {
    public init(directoryURL: URL) {}
    public func load() -> SnapshotLoadResult
    public func save(_ snapshot: TodaySnapshot) throws
}
```

Write `today_snapshot.json` using `.atomic`. Decode dates with
`.millisecondsSince1970`. Treat schema mismatch separately from invalid JSON.

- [ ] **Step 4: Run the complete package test suite**

Run: `swift test`

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NowTimelineCore/Storage Tests/NowTimelineCoreTests/SnapshotStoreTests.swift
git commit -m "feat: persist versioned timeline snapshots"
```

### Task 6: Verify the core milestone

**Files:**
- Modify only if verification exposes an issue.

- [ ] **Step 1: Run clean package tests**

Run:

```bash
rm -rf .build
swift test
```

Expected: build succeeds and all tests pass from a clean state.

- [ ] **Step 2: Verify platform isolation**

Run:

```bash
rg -n 'SwiftUI|EventKit|ActivityKit|WidgetKit|UIKit' Sources/NowTimelineCore
```

Expected: no output.

- [ ] **Step 3: Verify repository state**

Run: `git status --short`

Expected: no uncommitted implementation files.
