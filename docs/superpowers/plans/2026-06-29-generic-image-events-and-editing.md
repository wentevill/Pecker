# Generic Image Events and Local Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recognize ordinary events from images and let users edit or delete every Pecker-owned card.

**Architecture:** Add a generic event template that shares canonical timing with specialized train tickets. Extend the existing repository/image-store composition into a local card service used by `TimelineManagerModel`, then present one warm editor for generic fields with train-specific fields when applicable.

**Tech Stack:** Swift 6, SwiftUI, Observation, EventKit, ActivityKit, JSON persistence, Swift Testing, XCTest.

---

## Task 1: Generic event template

**Files:**
- Modify: `Sources/PeckerCore/Classification/EventTemplateFactory.swift`
- Modify: `Tests/PeckerCoreTests/EventTemplateFactoryTests.swift`
- Modify: `Sources/PeckerCore/Models/TimelineItem.swift`

- [ ] **Step 1: Write the failing factory test**

```swift
@Test func factoryCreatesGenericTaskFromExternalPayload() {
    let payload = ExternalEventTemplatePayload(
        kind: .task,
        fields: [
            "title": "巡逻",
            "location": "",
            "notes": "巡查楼梯口、仓库、围栏"
        ]
    )

    #expect(EventTemplateFactory().makeTemplate(from: payload) == .generic(
        .init(
            kind: .task,
            title: "巡逻",
            location: nil,
            notes: "巡查楼梯口、仓库、围栏"
        )
    ))
}
```

- [ ] **Step 2: Verify the test fails**

Run `swift test --filter factoryCreatesGenericTaskFromExternalPayload`.
Expected: compilation fails because `TimelineEventTemplate.generic` is absent.

- [ ] **Step 3: Add `GenericEventTemplate`**

Add a Codable/Hashable/Sendable value with `kind`, `title`, `location`, and
`notes`. Add `.generic(GenericEventTemplate)` to `TimelineEventTemplate`.
Its presentation title is the generic title, subtitle is the first non-empty
location or notes, and fields contain non-empty location and notes rows.

For every non-train kind, `makeTemplate(from:)` returns `.generic` when title
is non-empty. A train payload continues through `TrainTicketTemplate`.

- [ ] **Step 4: Run core tests**

Run `swift test`. Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PeckerCore Tests/PeckerCoreTests
git commit -m "feat: add generic recognized event cards"
```

## Task 2: Relative date recognition and patrol acceptance

**Files:**
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`
- Modify: `Pecker/Features/Today/TodayScreenContent.swift`

- [ ] **Step 1: Write the failing patrol test**

Inject an Asia/Shanghai calendar and a provider result:

```swift
ExternalEventTemplatePayload(
    kind: .task,
    fields: [
        "title": "巡逻",
        "eventDate": "2026-06-28",
        "startTime": "23:00",
        "endTime": "23:30",
        "notes": "巡查楼梯口、仓库、围栏"
    ]
)
```

Assert draft/saved title `巡逻`, kind `.task`, start
`2026-06-28T15:00:00Z`, end `2026-06-28T15:30:00Z`, and the exact notes.

- [ ] **Step 2: Verify the test fails**

Run the targeted `SystemEventRecognitionCoordinatorTests` with `xcodebuild`.
Expected: generic payload currently throws `unsupportedInput`.

- [ ] **Step 3: Update the provider contract**

Require `title`, canonical start/end values, location, and notes for ordinary
events. Tell the model that Chinese relative terms such as 今天/今晚 are resolved
against the `recognitionNow` value included in the user description. Add
`recognitionNow` and local time-zone identifier to image input descriptions.

- [ ] **Step 4: Complete timing aliases**

Make the timing parser accept `startTime`/`endTime` as well as
departure/arrival aliases. Continue to reject missing title or start, and roll
an implicit end date to tomorrow only when its local clock is earlier.

- [ ] **Step 5: Surface generic confirmation content**

The existing confirmation card renders the generic title, time range,
location, notes, and kind before Save. It keeps the typing-only recognition
state and never displays reasoning.

- [ ] **Step 6: Run tests and commit**

Run `swift test` and the full iOS test suite. Commit:

```bash
git add Sources/PeckerCore Pecker/Recognition Pecker/Features/Today PeckerTests Tests
git commit -m "feat: recognize ordinary events from images"
```

## Task 3: Local card service and editable draft

**Files:**
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `Pecker/Recognition/ImageRecognitionStore.swift`
- Modify: `Pecker/App/AppDependencies.swift`
- Create: `Pecker/Features/Timeline/TimelineRecordEditor.swift`
- Create: `PeckerTests/TimelineRecordEditorTests.swift`
- Modify: `Pecker.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing editor/service tests**

Test:

```swift
var editor = TimelineRecordEditor(record: record)
editor.title = "夜间巡逻"
editor.startDate = start
editor.endDate = end
let updated = try editor.makeRecord(updatedAt: now)
XCTAssertEqual(updated.rawTitle, "夜间巡逻")
```

Also assert empty title and `end <= start` fail, delete-by-ID removes the
record and attached image, and system records are rejected.

- [ ] **Step 2: Verify failure**

Run `TimelineRecordEditorTests`. Expected: editor/service types are missing.

- [ ] **Step 3: Implement `TimelineRecordEditor`**

Expose title, kind, start, optional end, location, notes, and optional train
fields. `makeRecord(updatedAt:)` preserves identity/source/image reference,
validates title and dates, then rebuilds either `.generic` or `.trainTicket`.

- [ ] **Step 4: Implement `LocalTimelineCardService`**

The service wraps the shared `EventRepository` and `ImageRecognitionStore`:

```swift
func loadAll() async throws -> [StoredEventRecord]
func update(_ record: StoredEventRecord) async throws
func delete(id: String) async throws
```

Only imported/camera image sources are mutable. Delete the record first and
then its image. Report cleanup failure without restoring the record.

- [ ] **Step 5: Inject the same production instances**

`AppDependencies.production` creates one repository and one image store, then
passes them to recognition and local-card services. Test dependencies use a
no-op service by default.

- [ ] **Step 6: Run tests and commit**

Run core and full iOS tests. Commit:

```bash
git add Pecker/Recognition Pecker/App Pecker/Features/Timeline PeckerTests Pecker.xcodeproj/project.pbxproj
git commit -m "feat: add local card editing service"
```

## Task 4: Warm editor and delete flow

**Files:**
- Modify: `Pecker/Features/Timeline/TimelineManagerModel.swift`
- Modify: `Pecker/Features/Timeline/FullTimelineView.swift`
- Modify: `Pecker/Features/Today/TodayView.swift`
- Modify: `Pecker/Features/Detail/ItemDetailView.swift`
- Modify: `Pecker/Design/TimelineTheme.swift`
- Modify: `PeckerTests/TimelineManagerModelTests.swift`
- Modify: `PeckerTests/ItemDetailActionTests.swift`

- [ ] **Step 1: Write failing ownership and mutation tests**

Assert external cards expose edit/delete, calendar/reminder cards do not,
successful edits reclassify scopes, and deletion clears a matching manual pin.

- [ ] **Step 2: Verify failure**

Run the two targeted app test classes. Expected: mutation APIs/actions absent.

- [ ] **Step 3: Add manager mutation APIs**

Add:

```swift
func editor(for item: TimelineItem) async throws -> TimelineRecordEditor
func save(_ editor: TimelineRecordEditor, now: Date = .now) async throws
func delete(_ item: TimelineItem) async throws
```

Each success reloads manager data and triggers the supplied Today/Live Activity
refresh closure. Delete clears the matching manual pin.

- [ ] **Step 4: Add warm edit UI**

Present a sheet using the existing warm gradient and glass cards. Include title,
kind, dates, location, notes, and conditional train fields. Disable Save while
invalid and retain the sheet with inline error text after failure.

- [ ] **Step 5: Add confirmed delete**

External rows/details show Edit and Delete. Delete requires a destructive
confirmation. System rows/details show neither action.

- [ ] **Step 6: Run tests and commit**

Run full tests and commit:

```bash
git add Pecker/Features Pecker/Design PeckerTests
git commit -m "feat: edit and delete Pecker timeline cards"
```

## Task 5: End-to-end verification

**Files:**
- Modify only files required by verification failures.

- [ ] **Step 1: Run `swift test`**

Expected: all PeckerCore tests pass.

- [ ] **Step 2: Run full iOS tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -quiet \
  -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all app, widget, and Live Activity tests pass.

- [ ] **Step 3: Build generic simulator**

Run `xcodebuild build` for `generic/platform=iOS Simulator`.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Verify patrol image flow**

Recognize the sample sentence on 2026-06-28 Asia/Shanghai, confirm 23:00–23:30,
save, edit its title/time/notes, observe Today/Live Activity refresh, then
delete it and verify the image and Live Activity are cleaned up.

- [ ] **Step 5: Verify visual continuity**

Compare confirmation, editor, delete dialog, Today, and manager against the
warm design: warm gradient, warm glass cards, existing radius/spacing, and
semantic accents.

- [ ] **Step 6: Check repository state**

Run `git diff --check` and `git status --short`. Commit only intentional final
fixes or verification artifacts.
