# Modern Type-Aware Event Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the local-record `Form` editor with an Apple-style type-aware sheet whose ordered custom name/value fields work for every event type.

**Architecture:** Persist custom fields at the `StoredEventRecord` and `TimelineItem` level so generic, flight, and train records share one ordered representation. Keep the existing `TimelineRecordEditor` draft as the single mutation boundary, add explicit validation and legacy migration there, then compose the editor UI from private SwiftUI sections in the existing editor source file to avoid colliding with the currently modified Xcode project.

**Tech Stack:** Swift 6, SwiftUI, Foundation Codable, XCTest, Xcode 26 iOS Simulator.

---

## File Map

- `Sources/PeckerCore/Storage/EventRepository.swift`: define the persisted ordered custom-field model and backward-compatible record decoding.
- `Sources/PeckerCore/Models/TimelineItem.swift`: expose custom fields to app presentation with backward-compatible decoding.
- `Pecker/Features/Timeline/TimelineManagerModel.swift`: map persisted custom fields into timeline items.
- `Pecker/Features/Timeline/TimelineRecordEditor.swift`: migrate, validate, and save custom fields; replace the `Form` with the approved sheet UI and type-specific sections.
- `Pecker/Features/Detail/ItemDetailView.swift`: present the large editor sheet and show saved custom fields.
- `Pecker/Resources/en.lproj/Localizable.strings`: English editor, validation, accessibility, and discard copy.
- `Pecker/Resources/zh-Hans.lproj/Localizable.strings`: Simplified Chinese equivalents.
- `Tests/PeckerCoreTests/EventRepositoryTests.swift`: persistence compatibility and ordering coverage.
- `PeckerTests/TimelineRecordEditorTests.swift`: migration, validation, kind-switch, and save behavior.
- `PeckerTests/TimelineManagerModelTests.swift`: mapping coverage.
- `PeckerTests/ItemDetailActionTests.swift`: detail presentation helper coverage.

### Task 1: Persist Ordered Custom Fields

**Files:**
- Modify: `Sources/PeckerCore/Storage/EventRepository.swift`
- Modify: `Sources/PeckerCore/Models/TimelineItem.swift`
- Test: `Tests/PeckerCoreTests/EventRepositoryTests.swift`

- [ ] **Step 1: Write failing compatibility and order tests**

Add tests that construct, encode, and decode a record containing ordered
fields, and decode legacy JSON without the new key:

```swift
func testStoredRecordRoundTripsOrderedCustomFields() throws {
    let fields = [
        EventCustomField(id: "booking", name: "Booking", value: "K8X2PL"),
        EventCustomField(id: "loyalty", name: "Loyalty", value: "KF 882019")
    ]
    let record = makeRecord(customFields: fields)

    let data = try JSONEncoder().encode(record)
    let decoded = try JSONDecoder().decode(StoredEventRecord.self, from: data)

    XCTAssertEqual(decoded.customFields, fields)
}

func testStoredRecordDecodesLegacyJSONWithEmptyCustomFields() throws {
    let original = makeRecord(customFields: [])
    let data = try JSONEncoder().encode(original)
    var object = try XCTUnwrap(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    object.removeValue(forKey: "customFields")

    let legacyData = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(
        StoredEventRecord.self,
        from: legacyData
    )

    XCTAssertEqual(decoded.customFields, [])
}
```

Update the local `makeRecord` helper to accept
`customFields: [EventCustomField] = []`.

- [ ] **Step 2: Run the focused core tests and verify failure**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerCoreTests/EventRepositoryTests
```

Expected: compilation fails because `EventCustomField` and
`StoredEventRecord.customFields` do not exist.

- [ ] **Step 3: Add the persisted model and defaults**

Add above `StoredEventRecord`:

```swift
public struct EventCustomField:
    Codable, Sendable, Equatable, Hashable, Identifiable
{
    public let id: String
    public var name: String
    public var value: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        value: String
    ) {
        self.id = id
        self.name = name
        self.value = value
    }

    public static func legacy(name: String, value: String) -> Self {
        .init(id: "legacy:\(name)", name: name, value: value)
    }
}
```

Add `customFields: [EventCustomField]` to `StoredEventRecord`, give its
initializer a trailing `customFields: [EventCustomField] = []` parameter, add
the coding key, and decode it with:

```swift
customFields = try container.decodeIfPresent(
    [EventCustomField].self,
    forKey: .customFields
) ?? []
```

Add `customFields: [EventCustomField]` to `TimelineItem`, give the public
initializer a trailing default-empty argument, add the coding key, and use the
same default-empty decoding pattern.

- [ ] **Step 4: Run the focused tests and verify success**

Run the Task 1 command again.

Expected: `EventRepositoryTests` pass.

- [ ] **Step 5: Commit the persistence slice**

```bash
git add Sources/PeckerCore/Storage/EventRepository.swift \
  Sources/PeckerCore/Models/TimelineItem.swift \
  Tests/PeckerCoreTests/EventRepositoryTests.swift
git commit -m "feat: persist ordered event custom fields"
```

### Task 2: Normalize and Validate Editor Custom Fields

**Files:**
- Modify: `Pecker/Features/Timeline/TimelineRecordEditor.swift`
- Test: `PeckerTests/TimelineRecordEditorTests.swift`

- [ ] **Step 1: Write failing editor-model tests**

Add these behaviors with concrete assertions:

```swift
func testEditorMigratesLegacyGenericFieldsInNameOrder() throws {
    let record = makeGenericRecord(fields: ["Zone": "A", "Booking": "K8X2"])
    let editor = try TimelineRecordEditor(record: record)

    XCTAssertEqual(editor.customFields.map(\.name), ["Booking", "Zone"])
    XCTAssertEqual(editor.customFields.map(\.value), ["K8X2", "A"])
}

func testEditorPrefersRecordLevelFieldsForFlight() throws {
    let fields = [
        EventCustomField(id: "meal", name: "Meal", value: "Vegetarian")
    ]
    let editor = try TimelineRecordEditor(
        record: makeFlightRecord(customFields: fields)
    )

    XCTAssertEqual(editor.customFields, fields)
}

func testHalfCompleteCustomFieldFailsValidation() throws {
    var editor = try TimelineRecordEditor(record: makeRecord())
    editor.customFields = [
        .init(id: "broken", name: "Booking", value: " ")
    ]

    XCTAssertEqual(
        editor.validationError,
        .incompleteCustomField(id: "broken")
    )
}

func testDuplicateCustomFieldNamesIgnoreCaseAndWhitespace() throws {
    var editor = try TimelineRecordEditor(record: makeRecord())
    editor.customFields = [
        .init(id: "one", name: " Booking ", value: "A"),
        .init(id: "two", name: "booking", value: "B")
    ]

    XCTAssertEqual(
        editor.validationError,
        .duplicateCustomField(ids: ["one", "two"])
    )
}

func testSaveTrimsAndPreservesCustomFieldOrder() throws {
    var editor = try TimelineRecordEditor(record: makeRecord())
    editor.customFields = [
        .init(id: "second", name: " Seat note ", value: " Window "),
        .init(id: "blank", name: " ", value: " ")
    ]

    let record = try editor.makeRecord(updatedAt: .now)

    XCTAssertEqual(record.customFields, [
        .init(id: "second", name: "Seat note", value: "Window")
    ])
}

func testTravelReservedFieldsStayInTypeSpecificModule() throws {
    let record = makeGenericRecord(
        kind: .travel,
        fields: [
            "origin": "Shanghai",
            "destination": "Suzhou",
            "booking": "K8X2"
        ]
    )
    let editor = try TimelineRecordEditor(record: record)

    XCTAssertEqual(editor.travelOrigin, "Shanghai")
    XCTAssertEqual(editor.travelDestination, "Suzhou")
    XCTAssertEqual(editor.customFields.map(\.name), ["booking"])
}
```

- [ ] **Step 2: Run focused editor tests and verify failure**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/TimelineRecordEditorTests
```

Expected: compilation fails because editor custom fields still use
`TimelineRecordEditorField` and validation has no row-specific cases.

- [ ] **Step 3: Implement migration and validation**

Replace `TimelineRecordEditorField` with editable `EventCustomField` values.
Extend the error enum:

```swift
case incompleteCustomField(id: String)
case duplicateCustomField(ids: [String])
```

Initialize fields using:

```swift
private static func initialCustomFields(
    record: StoredEventRecord
) -> [EventCustomField] {
    if !record.customFields.isEmpty {
        return record.customFields
    }
    guard case let .generic(event) = record.template else {
        return []
    }
    return event.fields
        .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        .map { .legacy(name: $0.key, value: $0.value) }
}
```

Validate trimmed half-complete rows first, then group non-empty names by
`folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)`.
Write trimmed, non-empty fields to the new record-level property in original
array order.

Add editable `travelOrigin`, `travelDestination`, `departureTimeText`, and
`arrivalTimeText` properties. For `.travel`, extract the reserved
case-sensitive keys `origin`, `destination`, `departureTime`, and
`arrivalTime` from legacy generic-template fields; remaining pairs migrate to
record-level custom fields. New generic saves use:

```swift
private var structuredGenericFields: [String: String] {
    guard kind == .travel else { return [:] }
    return [
        "origin": travelOrigin,
        "destination": travelDestination,
        "departureTime": departureTimeText,
        "arrivalTime": arrivalTimeText
    ].compactMapValues(\.nilIfBlank)
}
```

Pass `structuredGenericFields` to `GenericEventTemplate`; the record-level
array remains canonical for user-defined fields and values are not duplicated.

- [ ] **Step 4: Add kind-transition preservation tests and implementation**

Add a test that starts with a flight draft, changes to `.task`, saves, and
asserts that non-empty specialized values not representable by the generic
template are appended once as custom fields. Add the inverse train-to-flight
case.

Implement a `customFieldsForSave()` helper that starts with explicit custom
fields and appends non-empty specialized values using stable reserved IDs such
as `preserved:flightNumber`, skipping a preserved name already present
case-insensitively.

- [ ] **Step 5: Run focused editor tests**

Run the Task 2 command again.

Expected: `TimelineRecordEditorTests` pass.

- [ ] **Step 6: Commit editor-model behavior**

```bash
git add Pecker/Features/Timeline/TimelineRecordEditor.swift \
  PeckerTests/TimelineRecordEditorTests.swift
git commit -m "feat: validate editor custom fields"
```

### Task 3: Map and Display Custom Fields

**Files:**
- Modify: `Pecker/Features/Timeline/TimelineManagerModel.swift`
- Modify: `Pecker/Features/Detail/ItemDetailView.swift`
- Test: `PeckerTests/TimelineManagerModelTests.swift`
- Test: `PeckerTests/ItemDetailActionTests.swift`

- [ ] **Step 1: Write failing mapping and visibility tests**

Add a manager test:

```swift
func testTimelineItemCarriesRecordCustomFields() {
    let fields = [
        EventCustomField(id: "booking", name: "Booking", value: "K8X2")
    ]
    let item = TimelineManagerModel.timelineItem(
        from: makeRecord(customFields: fields),
        now: .now
    )

    XCTAssertEqual(item?.customFields, fields)
}
```

Extract a small pure helper in `ItemDetailAction` and test it:

```swift
func testVisibleCustomFieldsDropsBlankRowsWithoutReordering() {
    let fields = [
        EventCustomField(id: "one", name: "Booking", value: "K8X2"),
        EventCustomField(id: "blank", name: " ", value: " ")
    ]

    XCTAssertEqual(ItemDetailAction.visibleCustomFields(fields), [fields[0]])
}
```

- [ ] **Step 2: Run the two focused suites and verify failure**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/TimelineManagerModelTests \
  -only-testing:PeckerTests/ItemDetailActionTests
```

Expected: the manager drops the fields and the visibility helper is missing.

- [ ] **Step 3: Pass fields through local mapping paths**

Add `customFields: item.customFields` in `normalize(_:)` and
`customFields: record.customFields` in `timelineItem(from:now:)`. Search every
`TimelineItem(` call and rely on the default-empty argument only for sources
that cannot own custom fields.

- [ ] **Step 4: Render the saved fields in detail**

Add:

```swift
static func visibleCustomFields(
    _ fields: [EventCustomField]
) -> [EventCustomField] {
    fields.filter {
        !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

In the existing neutral detail card, append one `detailRow` per visible field
after notes, preserving array order.

- [ ] **Step 5: Run tests and commit**

Run the Task 3 command. Expected: both suites pass.

```bash
git add Pecker/Features/Timeline/TimelineManagerModel.swift \
  Pecker/Features/Detail/ItemDetailView.swift \
  PeckerTests/TimelineManagerModelTests.swift \
  PeckerTests/ItemDetailActionTests.swift
git commit -m "feat: surface custom fields across timeline"
```

### Task 4: Build the Apple-Style Type-Aware Editor

**Files:**
- Modify: `Pecker/Features/Timeline/TimelineRecordEditor.swift`
- Modify: `Pecker/Features/Detail/ItemDetailView.swift`
- Modify: `Pecker/Resources/en.lproj/Localizable.strings`
- Modify: `Pecker/Resources/zh-Hans.lproj/Localizable.strings`
- Test: `PeckerTests/TimelineRecordEditorTests.swift`

- [ ] **Step 1: Add pure presentation tests**

Introduce and test an `EditorSectionKind` list:

```swift
func testFlightEditorSectionsAreCommonFlightAndCustom() {
    XCTAssertEqual(
        TimelineRecordEditor.sections(for: .flight),
        [.common, .flight, .custom]
    )
}

func testTrainEditorSectionsAreCommonTrainAndCustom() {
    XCTAssertEqual(
        TimelineRecordEditor.sections(for: .train),
        [.common, .train, .custom]
    )
}

func testGenericEditorSectionsAlwaysEndWithCustom() {
    for kind in TimelineKind.allCases where kind != .flight && kind != .train {
        XCTAssertEqual(
            TimelineRecordEditor.sections(for: kind).last,
            .custom
        )
    }
}
```

- [ ] **Step 2: Run focused tests and verify failure**

Run the Task 2 test command.

Expected: compilation fails because `EditorSectionKind` and `sections(for:)`
are missing.

- [ ] **Step 3: Replace the `Form` shell**

Keep `TimelineRecordEditorView` in the existing file, but replace its body with
a `NavigationStack` containing:

```swift
ScrollView {
    LazyVStack(alignment: .leading, spacing: 18) {
        editorHero
        kindPicker
        commonSection
        typeSpecificSection
        customFieldsSection
        if let errorText { editorError(errorText) }
        if !keyboardIsVisible { saveButton }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 28)
}
.background(Color(uiColor: .systemGroupedBackground))
```

Use `.navigationTitle`, inline display mode, Cancel and Done toolbar items, and
`ProgressView` in the Done label while saving. Use `.sensoryFeedback` only for
save success and destructive custom-field deletion.

- [ ] **Step 4: Implement the common and type-specific sections**

Create private view builders in the same source file:

- `editorHero`: prominent title field plus localized date/route summary.
- `kindPicker`: horizontal `ScrollView` with capsule chips and selected
  foreground/background semantics.
- `commonSection`: title, all-day, start, optional end, location, and notes.
- `flightSection`: all existing flight bindings.
- `trainSection`: all existing train bindings.
- `travelSection`: origin, destination, departure text, and arrival text.
- Meeting, interview, task, deadline, and unknown have no empty secondary
  module; their selected type chip, common-field ordering, section title, and
  custom fields provide the tailored presentation.

Wrap each group in a reusable private `EditorSectionCard` using
`Color(uiColor: .secondarySystemGroupedBackground)`, a 16-point continuous
corner radius, and half-point semantic separators. Keep row hit targets at
least 44 points. Read `accessibilityReduceMotion`; when enabled, update the
type-specific section without a transition, otherwise use a short opacity
transition.

- [ ] **Step 5: Implement inline custom-field editing**

Use a `ForEach($editor.customFields)` with name and value fields, a destructive
delete button, and `.onMove` ordering. The Add action appends:

```swift
let field = EventCustomField(name: "", value: "")
editor.customFields.append(field)
focusedCustomField = .name(field.id)
```

`EventCustomField.id` remains immutable while `name` and `value` are mutable,
so SwiftUI can bind directly to each row. Name uses `.submitLabel(.next)` and
advances focus to value. Expose localized VoiceOver labels for delete and
reorder actions.

- [ ] **Step 6: Add dirty-cancel and validation presentation**

Store the initial draft. Cancel dismisses directly when `editor == initial`.
Otherwise present a confirmation dialog with Continue Editing and Discard
Changes. Map `validationError` to localized row-level copy; persistence errors
remain at the bottom and preserve the draft.

- [ ] **Step 7: Add localization**

Add exact English and Simplified Chinese keys for:

```text
editor.section.common
editor.section.custom
editor.section.meeting
editor.section.task
editor.section.interview
editor.section.deadline
editor.section.travel
editor.discard.title
editor.discard.message
editor.discard.action
editor.continueEditing
editor.customField.incomplete
editor.customField.duplicate
editor.customField.delete.accessibility
editor.customField.reorder.accessibility
editor.save.progress
```

Use native concise translations and keep all visible source text behind
`AppLocalizer`.

- [ ] **Step 8: Present the large sheet**

On the editor sheet in `ItemDetailView`, add:

```swift
.presentationDetents([.large])
.presentationDragIndicator(.visible)
.presentationCornerRadius(30)
.interactiveDismissDisabled(editingRecord != nil)
```

Let Cancel own discard confirmation rather than allowing a drag to lose
changes.

- [ ] **Step 9: Run focused tests and commit**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PeckerTests/TimelineRecordEditorTests \
  -only-testing:PeckerTests/ItemDetailActionTests
```

Expected: all focused tests pass.

```bash
git add Pecker/Features/Timeline/TimelineRecordEditor.swift \
  Pecker/Features/Detail/ItemDetailView.swift \
  Pecker/Resources/en.lproj/Localizable.strings \
  Pecker/Resources/zh-Hans.lproj/Localizable.strings \
  PeckerTests/TimelineRecordEditorTests.swift
git commit -m "feat: redesign type-aware event editor"
```

### Task 5: Full Regression and Simulator Verification

**Files:**
- Verify: files changed in Tasks 1–4
- Create: `docs/verification/modern-editor-flight.png`
- Create: `docs/verification/modern-editor-custom-fields.png`

- [ ] **Step 1: Run source-language guard**

Run:

```bash
./scripts/check-no-han-source.sh
```

Expected: exit 0 with no disallowed Han characters in Swift sources.

- [ ] **Step 2: Run all tests**

Run:

```bash
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Build the app**

Run:

```bash
xcodebuild build -project Pecker.xcodeproj -scheme Pecker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify the approved interaction on Simulator**

Launch a local editable flight record and verify:

1. Editor opens as a large rounded sheet.
2. Flight chips and the flight module are visible.
3. Add Field focuses the name.
4. Return advances to value.
5. Two rows can be reordered and the order persists after Save.
6. A duplicate name blocks Save with localized inline copy.
7. Cancel after a change asks before discarding.
8. Keyboard does not cover the focused field.

Capture the flight form and reordered custom-field state at:

```text
docs/verification/modern-editor-flight.png
docs/verification/modern-editor-custom-fields.png
```

- [ ] **Step 5: Verify appearance and accessibility**

Repeat the editor check in dark appearance and at an accessibility Dynamic
Type size. Verify no clipped labels, 44-point controls, visible focus, and
usable VoiceOver labels for delete and reorder.

- [ ] **Step 6: Review the final diff**

Run:

```bash
git diff --check
git status --short
git diff --stat
```

Expected: no whitespace errors; only the intended implementation,
localization, tests, and verification images are new changes beyond the
user's pre-existing worktree changes.

- [ ] **Step 7: Commit verification adjustments**

If Task 5 required code changes:

```bash
git add Pecker Sources PeckerTests Tests docs/verification
git commit -m "test: verify modern event editor"
```

If no code adjustment was required, add only the two screenshots and commit:

```bash
git add docs/verification/modern-editor-flight.png \
  docs/verification/modern-editor-custom-fields.png
git commit -m "docs: capture modern editor verification"
```
