# Timeline Consistency, Data Integrity, and UI/UE Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make timeline presentation consistent, persistence operations truthful, configuration safe, and every audited UI state localized and accessible.

**Architecture:** Extend existing protocols with narrow read/cleanup operations instead of replacing repositories or view models. Keep domain decisions testable outside SwiftUI, then wire visible pin actions, range disclosure, localized copy, and contrast-safe semantic colors into the existing screens.

**Tech Stack:** Swift 6, SwiftUI, EventKit, Security, Foundation, XCTest, Swift Testing

---

## File Map

- Modify recognition repository/coordinator files for cached templates and bounded cleanup.
- Modify `TimelineManagerModel` to map cached templates consistently.
- Extend image storage with quarantine/restore operations.
- Refactor Keychain writes to update-or-add and reconcile displayed status.
- Create a recognition-host validator.
- Complete localization resources and remove audited hard-coded UI copy.
- Add contrast-safe text tokens and test their ratios.
- Restore Full Timeline pin controls and truthful accessibility.
- Add timeline-range disclosure and update README requirements.

### Task 1: Reuse cached system templates in Full Timeline

**Files:**
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `Pecker/Features/Timeline/TimelineManagerModel.swift`
- Modify: `PeckerTests/TimelineManagerModelTests.swift`
- Modify: `PeckerTests/TodayViewModelTests.swift`

- [ ] **Step 1: Write a failing Full Timeline consistency test**

Add to `TimelineManagerModelTests.swift`:

```swift
@MainActor
func testLoadUsesCachedSystemTemplateBeforeLocalClassification() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let template = TimelineEventTemplate.trainTicket(.init(
        trainNumber: "G123",
        departureStation: "Shanghai",
        arrivalStation: "Beijing",
        departureTimeText: nil,
        arrivalTimeText: nil,
        carriageNumber: nil,
        seatNumber: nil,
        checkInGate: nil,
        passengerName: nil,
        ticketNumber: nil
    ))
    let recognizer = TimelineManagerRecognizer(
        templates: ["calendar:event-1": template]
    )
    let gateway = TimelineManagerGateway(events: [
            EventRecord(
                identifier: "event-1",
                title: "Ordinary title",
                startDate: now,
                endDate: now.addingTimeInterval(3_600),
                isAllDay: false,
                location: nil,
                notes: nil
            )
        ])
    let suite = "TimelineTemplateTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    addTeardownBlock {
        UserDefaults(suiteName: suite)?
            .removePersistentDomain(forName: suite)
    }
    let model = TimelineManagerModel(
        gateway: gateway,
        mapper: EventKitMapper(),
        recognizer: recognizer,
        localCards: TimelineManagerTestLocalCards(
            records: [],
            loadError: nil
        ),
        settingsStore: SettingsStore(defaults: defaults),
        calendar: Calendar(identifier: .gregorian)
    )

    XCTAssertTrue(await model.load(now: now))

    let item = try XCTUnwrap(model.items.first)
    XCTAssertEqual(item.kind, .train)
    XCTAssertEqual(item.template, template)
}
```

Implement the test double:

```swift
private actor TimelineManagerRecognizer: SystemEventRecognizing {
    let templates: [String: TimelineEventTemplate]

    init(templates: [String: TimelineEventTemplate]) {
        self.templates = templates
    }

    func cachedSystemTemplates()
        async -> [String: TimelineEventTemplate] {
        templates
    }

    func synchronize(
        events: [EventRecord],
        reminders: [ReminderRecord],
        settings: TimelineSettings,
        now: Date
    ) async -> [String: TimelineEventTemplate] {
        templates
    }

    func recognizedImageItems(
        settings: TimelineSettings,
        now: Date
    ) async -> [TimelineItem] { [] }
}

private actor TimelineManagerGateway: EventKitGatewayProtocol {
    let events: [EventRecord]

    init(events: [EventRecord]) {
        self.events = events
    }

    func authorization() -> SourceAuthorization {
        .init(calendar: .fullAccess, reminders: .denied)
    }
    func requestCalendarAccess() async throws -> Bool { false }
    func requestReminderAccess() async throws -> Bool { false }
    func fetchToday(
        calendar: Calendar,
        now: Date
    ) async throws -> [EventRecord] { events }
    func fetchEvents(
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [EventRecord] { events }
    func fetchReminders(
        calendar: Calendar,
        now: Date
    ) async throws -> [ReminderRecord] { [] }
}
```

- [ ] **Step 2: Verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/TimelineManagerModelTests/testLoadUsesCachedSystemTemplateBeforeLocalClassification
```

Expected: compilation fails because `cachedSystemTemplates()` is not in the protocol.

- [ ] **Step 3: Add the cached-template read operation**

Add to `SystemEventRecognizing`:

```swift
func cachedSystemTemplates() async -> [String: TimelineEventTemplate]
```

Add a default:

```swift
extension SystemEventRecognizing {
    func cachedSystemTemplates()
        async -> [String: TimelineEventTemplate] {
        [:]
    }
}
```

Implement in `SystemEventRecognitionCoordinator`:

```swift
func cachedSystemTemplates()
    async -> [String: TimelineEventTemplate] {
    (try? await recognizedTemplates()) ?? [:]
}
```

- [ ] **Step 4: Map templates in `TimelineManagerModel.load`**

Add:

```swift
async let cachedTemplates = recognizer.cachedSystemTemplates()
```

Include it in the tuple and map system records with:

```swift
var merged = eventRecords.map { event in
    normalize(
        mapper.mapEvent(
            event,
            template: templates["calendar:\(event.identifier)"]
        )
    )
}
merged += reminderRecords.compactMap { reminder in
    mapper.mapReminder(
        reminder,
        template: templates["reminder:\(reminder.identifier)"]
    ).map(normalize)
}
```

Change `normalize` so a template wins:

```swift
let kind = item.template?.kind ?? classifier.classify(
    title: item.title,
    location: item.location,
    notes: item.notes,
    source: item.source
)
```

- [ ] **Step 5: Update all protocol test doubles**

Existing doubles may rely on the default implementation; only doubles that need templates implement the new method. Do not add empty boilerplate to every test actor.

- [ ] **Step 6: Run timeline and today tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/TimelineManagerModelTests \
-only-testing:PeckerTests/TodayViewModelTests
```

Expected: both suites pass.

- [ ] **Step 7: Commit**

```bash
git add Pecker/Recognition/SystemEventRecognitionCoordinator.swift Pecker/Features/Timeline/TimelineManagerModel.swift PeckerTests/TimelineManagerModelTests.swift PeckerTests/TodayViewModelTests.swift
git commit -m "fix: reuse recognition templates across timelines"
```

### Task 2: Remove stale synchronized system records within the authoritative interval

**Files:**
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `Sources/PeckerCore/Storage/EventRepository.swift`
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`
- Modify: `Tests/PeckerCoreTests/EventRepositoryTests.swift`

- [ ] **Step 1: Add repository deletion-by-ID-set test**

```swift
@Test func eventRepositoryDeletesOnlyRequestedIDs() async throws {
    let repository = EventRepository(directoryURL: temporaryDirectory())
    try await repository.upsert(record(id: "calendar:keep", source: .calendar))
    try await repository.upsert(record(id: "calendar:remove", source: .calendar))
    try await repository.upsert(record(id: "image:keep", source: .importedImage))

    try await repository.delete(ids: ["calendar:remove"])

    #expect(try await repository.loadAll().map(\.id).sorted() == [
        "calendar:keep",
        "image:keep"
    ])
}
```

- [ ] **Step 2: Add coordinator cleanup test**

```swift
@Test func synchronizeDeletesMissingCalendarRecordOnlyInsideFetchedDay() async throws {
    let repository = RecordingEventRepository(records: [
        storedCalendar(id: "calendar:present", start: dayStart),
        storedCalendar(id: "calendar:stale", start: dayStart.addingTimeInterval(60)),
        storedCalendar(id: "calendar:outside", start: dayStart.addingTimeInterval(-86_400)),
        storedImage(id: "image:keep", start: dayStart)
    ])
    let coordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: nil)
    )

    _ = await coordinator.synchronize(
        events: [event(identifier: "present", start: dayStart)],
        reminders: [],
        settings: .init(syncCalendarToStorage: true),
        now: dayStart.addingTimeInterval(3_600)
    )

    let ids = await repository.records().map(\.id).sorted()
    #expect(ids == [
        "calendar:outside",
        "calendar:present",
        "image:keep"
    ])
}
```

- [ ] **Step 3: Verify tests fail**

Run:

```bash
swift test --filter eventRepositoryDeletesOnlyRequestedIDs
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests
```

Expected: repository compilation fails because `delete(ids:)` is missing; coordinator cleanup assertion fails.

- [ ] **Step 4: Add batch deletion**

Add to `EventRepositoryStoring` and `EventRepository`:

```swift
func delete(ids: Set<String>) async throws
```

Add a protocol default so existing test repositories continue to compile:

```swift
extension EventRepositoryStoring {
    func delete(ids: Set<String>) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }
}
```

Repository implementation:

```swift
public func delete(ids: Set<String>) throws {
    guard !ids.isEmpty else { return }
    try save(loadAll().filter { !ids.contains($0.id) })
}
```

- [ ] **Step 5: Reconcile only the current local day**

Before recognition loops, compute:

```swift
let dayStart = calendar.startOfDay(for: now)
let dayEnd = calendar.date(
    byAdding: .day,
    value: 1,
    to: dayStart
) ?? dayStart.addingTimeInterval(86_400)
let interval = DateInterval(start: dayStart, end: dayEnd)
```

Add:

```swift
private func removeMissingRecords(
    source: RecognitionSource,
    presentIDs: Set<String>,
    interval: DateInterval
) async throws {
    let staleIDs = try await repository.loadAll().compactMap { record in
        guard record.source == source,
              let start = record.startDate,
              interval.contains(start),
              !presentIDs.contains(record.id)
        else {
            return nil
        }
        return record.id
    }
    try await repository.delete(ids: Set(staleIDs))
}
```

Invoke for enabled synchronized sources:

```swift
try await removeMissingRecords(
    source: .calendar,
    presentIDs: Set(events.map { "calendar:\($0.identifier)" }),
    interval: interval
)
```

Repeat for reminders. Never pass `.importedImage` or `.cameraImage`.

- [ ] **Step 6: Run repository and coordinator tests**

Expected: both commands from Step 3 pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/PeckerCore/Storage/EventRepository.swift Pecker/Recognition/SystemEventRecognitionCoordinator.swift Tests/PeckerCoreTests/EventRepositoryTests.swift PeckerTests/SystemEventRecognitionCoordinatorTests.swift
git commit -m "fix: prune stale synchronized system records"
```

### Task 3: Make image-record deletion reversible

**Files:**
- Modify: `Pecker/Recognition/ImageRecognitionStore.swift`
- Modify: `PeckerTests/TimelineRecordEditorTests.swift`

- [ ] **Step 1: Write rollback and cleanup-failure tests**

```swift
@Test func localDeleteRestoresImageWhenRecordDeletionFails() async throws {
    let repository = DeletionRepository(
        record: mutableImageRecord(),
        deleteError: TestPersistenceError.failed
    )
    let images = TransactionalImageStore()
    let service = LocalTimelineCardService(
        repository: repository,
        imageStore: images
    )

    await #expect(throws: TestPersistenceError.self) {
        try await service.delete(id: "image:1")
    }
    #expect(images.quarantined == ["Images/test.jpg"])
    #expect(images.restored == ["Images/test.jpg"])
}

@Test func cleanupFailureAfterRecordDeletionStillCountsAsDeleted() async throws {
    let repository = DeletionRepository(record: mutableImageRecord())
    let images = TransactionalImageStore(removeError: ImageError.failed)
    let service = LocalTimelineCardService(
        repository: repository,
        imageStore: images
    )

    try await service.delete(id: "image:1")

    #expect(await repository.record == nil)
    #expect(images.quarantined == ["Images/test.jpg"])
}
```

- [ ] **Step 2: Verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/TimelineRecordEditorTests
```

Expected: compilation fails because transactional image-store methods are absent.

- [ ] **Step 3: Extend `ImageFileStoring`**

```swift
struct QuarantinedImage: Sendable, Equatable {
    let originalPath: String
    let quarantinePath: String
}

protocol ImageFileStoring: Sendable {
    func saveImage(
        data: Data,
        filename: String?,
        source: RecognitionSource
    ) throws -> String
    func deleteImage(at relativePath: String) throws
    func quarantineImage(at relativePath: String) throws -> QuarantinedImage
    func restoreImage(_ image: QuarantinedImage) throws
    func removeQuarantinedImage(_ image: QuarantinedImage) throws
}
```

Implement:

```swift
func quarantineImage(
    at relativePath: String
) throws -> QuarantinedImage {
    let sourceURL = try validatedFileURL(for: relativePath)
    let quarantinePath =
        "Images/.Trash/\(UUID().uuidString)-\(sourceURL.lastPathComponent)"
    let quarantineURL = try validatedFileURL(for: quarantinePath)
    try FileManager.default.createDirectory(
        at: quarantineURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    if FileManager.default.fileExists(atPath: sourceURL.path) {
        try FileManager.default.moveItem(
            at: sourceURL,
            to: quarantineURL
        )
    }
    return .init(
        originalPath: relativePath,
        quarantinePath: quarantinePath
    )
}

func restoreImage(_ image: QuarantinedImage) throws {
    let sourceURL = try validatedFileURL(
        for: image.quarantinePath
    )
    let destinationURL = try validatedFileURL(
        for: image.originalPath
    )
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
        return
    }
    try FileManager.default.moveItem(
        at: sourceURL,
        to: destinationURL
    )
}

func removeQuarantinedImage(
    _ image: QuarantinedImage
) throws {
    let url = try validatedFileURL(for: image.quarantinePath)
    if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }
}

private func validatedFileURL(
    for relativePath: String
) throws -> URL {
    let root = directoryURL.standardizedFileURL
    let url = directoryURL
        .appendingPathComponent(relativePath)
        .standardizedFileURL
    guard url.path.hasPrefix(root.path + "/") else {
        throw ImageRecognitionStoreError.invalidImageReference
    }
    return url
}
```

Keep `deleteImage(at:)` for rollback of a newly saved image when repository
persistence fails. Update `RecordingImageFileStore` and `EditorImageStore`
with deterministic quarantine, restore, and removal arrays matching the two
tests above.

- [ ] **Step 4: Replace deletion ordering**

```swift
func delete(id: String) async throws {
    guard let record = try await repository.loadAll().first(
        where: { $0.id == id }
    ) else {
        throw LocalTimelineCardError.recordNotFound
    }
    guard Self.isMutable(record) else {
        throw LocalTimelineCardError.readOnlySource
    }

    let quarantined = try record.imageReference.map {
        try imageStore.quarantineImage(at: $0)
    }
    do {
        try await repository.delete(id: id)
    } catch {
        if let quarantined {
            try? imageStore.restoreImage(quarantined)
        }
        throw error
    }
    if let quarantined {
        try? imageStore.removeQuarantinedImage(quarantined)
    }
}
```

Remove `imageCleanupFailed`; cleanup debt after successful record deletion is not a user-visible deletion failure.

- [ ] **Step 5: Run tests and commit**

Run the Step 2 command.

Expected: `TimelineRecordEditorTests` passes.

```bash
git add Pecker/Recognition/ImageRecognitionStore.swift PeckerTests/TimelineRecordEditorTests.swift
git commit -m "fix: make local card deletion reversible"
```

### Task 4: Make Keychain replacement non-destructive and reconcile status

**Files:**
- Modify: `Pecker/Persistence/APIKeyStore.swift`
- Modify: `Pecker/Features/Settings/SettingsView.swift`
- Modify: `PeckerTests/SettingsViewModelTests.swift`
- Create: `PeckerTests/APIKeyStoreTests.swift`

- [ ] **Step 1: Write failing update-path tests**

```swift
func testExistingKeyUsesUpdateWithoutDelete() throws {
    let client = RecordingKeychainClient(copyStatus: errSecSuccess)
    let store = KeychainAPIKeyStore(client: client)

    try store.saveOpenAIAPIKey("new-key")

    XCTAssertEqual(client.updateCalls, 1)
    XCTAssertEqual(client.addCalls, 0)
    XCTAssertEqual(client.deleteCalls, 0)
}

func testFailedUpdateNeverDeletesExistingKey() {
    let client = RecordingKeychainClient(
        copyStatus: errSecSuccess,
        updateStatus: errSecInteractionNotAllowed
    )
    let store = KeychainAPIKeyStore(client: client)

    XCTAssertThrowsError(try store.saveOpenAIAPIKey("new-key"))
    XCTAssertEqual(client.deleteCalls, 0)
}
```

Add this recording client to `APIKeyStoreTests.swift`:

```swift
private final class RecordingKeychainClient:
    KeychainClient,
    @unchecked Sendable
{
    let copyStatus: OSStatus
    let updateStatus: OSStatus
    let addStatus: OSStatus
    var updateCalls = 0
    var addCalls = 0
    var deleteCalls = 0

    init(
        copyStatus: OSStatus,
        updateStatus: OSStatus = errSecSuccess,
        addStatus: OSStatus = errSecSuccess
    ) {
        self.copyStatus = copyStatus
        self.updateStatus = updateStatus
        self.addStatus = addStatus
    }

    func add(_ query: CFDictionary) -> OSStatus {
        addCalls += 1
        return addStatus
    }

    func update(
        _ query: CFDictionary,
        attributes: CFDictionary
    ) -> OSStatus {
        updateCalls += 1
        return updateStatus
    }

    func copy(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>
    ) -> OSStatus {
        if copyStatus == errSecSuccess {
            result.pointee = Data("old-key".utf8) as CFData
        }
        return copyStatus
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        deleteCalls += 1
        return errSecSuccess
    }
}
```

- [ ] **Step 2: Run the tests to verify the seam is missing**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/APIKeyStoreTests
```

Expected: compilation fails because `KeychainClient` and
`KeychainAPIKeyStore(client:)` do not exist.

- [ ] **Step 3: Extract the Security client and query helpers**

Add:

```swift
protocol KeychainClient: Sendable {
    func add(_ query: CFDictionary) -> OSStatus
    func update(
        _ query: CFDictionary,
        attributes: CFDictionary
    ) -> OSStatus
    func copy(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>
    ) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}

struct SystemKeychainClient: KeychainClient {
    func add(_ query: CFDictionary) -> OSStatus {
        SecItemAdd(query, nil)
    }
    func update(
        _ query: CFDictionary,
        attributes: CFDictionary
    ) -> OSStatus {
        SecItemUpdate(query, attributes)
    }
    func copy(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>
    ) -> OSStatus {
        SecItemCopyMatching(query, result)
    }
    func delete(_ query: CFDictionary) -> OSStatus {
        SecItemDelete(query)
    }
}
```

Inject it and add:

```swift
private let client: any KeychainClient

init(client: any KeychainClient = SystemKeychainClient()) {
    self.client = client
}

private func baseQuery() -> [String: Any] {
    [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account
    ]
}

private func loadQuery() -> [String: Any] {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    return query
}
```

- [ ] **Step 4: Implement update-or-add**

```swift
func saveOpenAIAPIKey(_ key: String) throws {
    let trimmed = key.trimmingCharacters(
        in: .whitespacesAndNewlines
    )
    guard !trimmed.isEmpty else {
        try clearOpenAIAPIKey()
        return
    }

    let identity = baseQuery()
    var item: CFTypeRef?
    let lookup = client.copy(
        loadQuery() as CFDictionary,
        result: &item
    )
    let data = Data(trimmed.utf8)
    let status: OSStatus
    if lookup == errSecSuccess {
        status = client.update(
            identity as CFDictionary,
            attributes: [kSecValueData as String: data] as CFDictionary
        )
    } else if lookup == errSecItemNotFound {
        var query = identity
        query[kSecValueData as String] = data
        status = client.add(query as CFDictionary)
    } else {
        throw APIKeyStoreError.unexpectedStatus(lookup)
    }
    guard status == errSecSuccess else {
        throw APIKeyStoreError.unexpectedStatus(status)
    }
}
```

- [ ] **Step 5: Run API-key store tests**

Run the Step 2 command.

Expected: `APIKeyStoreTests` passes.

- [ ] **Step 6: Write a failing configured-status reconciliation test**

```swift
@MainActor
func testReconcileAPIKeyStatusUsesActualKeychainContents() {
    let store = makeStore()
    store.update { $0.openAIAPIKeyConfigured = false }
    let keyStore = InMemoryAPIKeyStore()
    try! keyStore.saveOpenAIAPIKey("existing-key")
    let viewModel = SettingsViewModel(
        settingsStore: store,
        gateway: SettingsGateway(
            authorization: .init(
                calendar: .fullAccess,
                reminders: .fullAccess
            )
        ),
        authorization: .init(
            calendar: .fullAccess,
            reminders: .fullAccess
        ),
        apiKeyStore: keyStore,
        onSettingsChanged: {},
        openURL: { _ in }
    )

    viewModel.reconcileAPIKeyStatus()

    XCTAssertTrue(store.value.openAIAPIKeyConfigured)
}
```

- [ ] **Step 7: Verify the reconciliation test fails**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/SettingsViewModelTests/testReconcileAPIKeyStatusUsesActualKeychainContents
```

Expected: compilation fails because `reconcileAPIKeyStatus()` is absent.

- [ ] **Step 8: Reconcile configured status when Settings appears**

Add to `SettingsViewModel`:

```swift
func reconcileAPIKeyStatus() {
    let configured =
        (try? apiKeyStore.loadOpenAIAPIKey())?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .isEmpty == false
    if settingsStore.value.openAIAPIKeyConfigured != configured {
        settingsStore.update {
            $0.openAIAPIKeyConfigured = configured
        }
    }
}
```

Call it from the Settings `.task` before authorization refresh.

- [ ] **Step 9: Run and commit**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/APIKeyStoreTests \
-only-testing:PeckerTests/SettingsViewModelTests
```

Expected: both suites pass.

```bash
git add Pecker/Persistence/APIKeyStore.swift Pecker/Features/Settings/SettingsView.swift PeckerTests/APIKeyStoreTests.swift PeckerTests/SettingsViewModelTests.swift
git commit -m "fix: update api keys without destructive replacement"
```

### Task 5: Validate recognition hosts before persistence

**Files:**
- Create: `Pecker/Recognition/RecognitionHostValidator.swift`
- Modify: `Pecker/Features/Settings/SettingsView.swift`
- Create: `PeckerTests/RecognitionHostValidatorTests.swift`

- [ ] **Step 1: Write validator tests**

```swift
final class RecognitionHostValidatorTests: XCTestCase {
    func testAcceptsHTTPSBaseHostsAndProviderPaths() throws {
        XCTAssertEqual(
            try RecognitionHostValidator.validate(
                " https://api.openai.com "
            ),
            "https://api.openai.com"
        )
        XCTAssertEqual(
            try RecognitionHostValidator.validate(
                "https://example.com/openai"
            ),
            "https://example.com/openai"
        )
    }

    func testRejectsUnsafeOrEndpointURLs() {
        let rejected = [
            "http://example.com",
            "https://user:pass@example.com",
            "https://example.com/v1/chat/completions",
            "https://example.com?token=x",
            "https://example.com#fragment"
        ]
        for value in rejected {
            XCTAssertThrowsError(
                try RecognitionHostValidator.validate(value),
                value
            )
        }
    }
}
```

- [ ] **Step 2: Verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/RecognitionHostValidatorTests
```

Expected: compilation fails because the validator is missing.

- [ ] **Step 3: Implement validator**

```swift
import Foundation

enum RecognitionHostValidationError: Error, Equatable {
    case invalidURL
    case requiresHTTPS
    case containsCredentials
    case containsQueryOrFragment
    case includesCompletionEndpoint
}

enum RecognitionHostValidator {
    static func validate(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let components = URLComponents(string: trimmed),
              components.host?.isEmpty == false
        else {
            throw RecognitionHostValidationError.invalidURL
        }
        guard components.scheme?.lowercased() == "https" else {
            throw RecognitionHostValidationError.requiresHTTPS
        }
        guard components.user == nil, components.password == nil else {
            throw RecognitionHostValidationError.containsCredentials
        }
        guard components.query == nil, components.fragment == nil else {
            throw RecognitionHostValidationError.containsQueryOrFragment
        }
        let path = components.path.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.hasSuffix("chat/completions") else {
            throw RecognitionHostValidationError
                .includesCompletionEndpoint
        }
        return trimmed.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
    }
}
```

- [ ] **Step 4: Validate on submit, not every keystroke**

Keep an `@State private var hostDraft` in `SettingsView`. Add a localized Save button. On save:

```swift
do {
    let host = try RecognitionHostValidator.validate(hostDraft)
    viewModel.setOpenAIHost(host)
    hostErrorText = nil
} catch {
    hostErrorText = localizer.string("settings.host.invalid")
}
```

Do not persist invalid intermediate text through a live binding.

- [ ] **Step 5: Run and commit**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/RecognitionHostValidatorTests \
-only-testing:PeckerTests/SettingsViewModelTests
```

Expected: all pass.

```bash
git add Pecker/Recognition/RecognitionHostValidator.swift Pecker/Features/Settings/SettingsView.swift PeckerTests/RecognitionHostValidatorTests.swift PeckerTests/SettingsViewModelTests.swift
git commit -m "feat: validate recognition service hosts"
```

### Task 6: Complete localization and contrast tokens

**Files:**
- Modify: `Pecker/Localization/AppLocalizer.swift`
- Modify: `Pecker/Features/Onboarding/OnboardingModel.swift`
- Modify: `Pecker/Features/Settings/SettingsView.swift`
- Modify: `Pecker/Features/Today/TodayView.swift`
- Modify: `Pecker/App/PeckerApp.swift`
- Modify: `Sources/PeckerCore/Recognition/RecognitionPipelineModels.swift`
- Modify: `Pecker/Design/TimelineTheme.swift`
- Modify: both localization tables
- Modify: `PeckerTests/AppLocalizerTests.swift`
- Create: `PeckerTests/TimelineThemeContrastTests.swift`

- [ ] **Step 1: Add localization parity test**

```swift
func testEnglishAndChineseTablesHaveIdenticalKeys() throws {
    let english = try localizationKeys(resource: "en")
    let chinese = try localizationKeys(resource: "zh-Hans")
    XCTAssertEqual(english, chinese)
}

private func localizationKeys(resource: String) throws -> Set<String> {
    let url = try XCTUnwrap(
        Bundle.main.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: "\(resource).lproj"
        )
    )
    let text = try String(contentsOf: url, encoding: .utf8)
    let pattern = #"^\s*"([^"]+)"\s*="#
    let regex = try NSRegularExpression(
        pattern: pattern,
        options: [.anchorsMatchLines]
    )
    let range = NSRange(text.startIndex..., in: text)
    return Set(regex.matches(in: text, range: range).compactMap {
        Range($0.range(at: 1), in: text).map { String(text[$0]) }
    })
}
```

- [ ] **Step 2: Add contrast tests**

```swift
func testSemanticTextColorsMeetNormalTextContrast() {
    let card = TimelineRGB(red: 1.0, green: 0.985, blue: 0.955)
    let page = TimelineRGB(red: 0.965, green: 0.925, blue: 0.875)
    for color in [
        TimelineTheme.textTertiaryRGB,
        TimelineTheme.nowTextRGB,
        TimelineTheme.pinnedTextRGB
    ] {
        XCTAssertGreaterThanOrEqual(contrast(color, card), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(color, page), 4.5)
    }
}

private func contrast(
    _ left: TimelineRGB,
    _ right: TimelineRGB
) -> Double {
    let lighter = max(luminance(left), luminance(right))
    let darker = min(luminance(left), luminance(right))
    return (lighter + 0.05) / (darker + 0.05)
}

private func luminance(_ color: TimelineRGB) -> Double {
    func channel(_ value: Double) -> Double {
        value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(color.red)
        + 0.7152 * channel(color.green)
        + 0.0722 * channel(color.blue)
}
```

Define test RGB values alongside production `Color` tokens:

```swift
struct TimelineRGB: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
}

static let textTertiaryRGB = TimelineRGB(
    red: 0.36,
    green: 0.31,
    blue: 0.27
)
static let nowTextRGB = TimelineRGB(
    red: 0.68,
    green: 0.13,
    blue: 0.10
)
static let pinnedTextRGB = TimelineRGB(
    red: 0.56,
    green: 0.30,
    blue: 0.04
)
static let textTertiary = Color(
    red: textTertiaryRGB.red,
    green: textTertiaryRGB.green,
    blue: textTertiaryRGB.blue
)
static let nowText = Color(
    red: nowTextRGB.red,
    green: nowTextRGB.green,
    blue: nowTextRGB.blue
)
static let pinnedText = Color(
    red: pinnedTextRGB.red,
    green: pinnedTextRGB.green,
    blue: pinnedTextRGB.blue
)
```

- [ ] **Step 3: Verify both tests fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/AppLocalizerTests \
-only-testing:PeckerTests/TimelineThemeContrastTests
```

Expected: new audited keys are missing and current semantic colors fail contrast.

- [ ] **Step 4: Replace hard-coded user copy**

Add keys for:

```text
settings.ai.host
settings.ai.model
settings.apiKey.title
settings.liveActivity.title
onboarding.calendar.error
onboarding.reminders.error
recognition.accessibility.inProgress
progress.accessibility.format
configuration.error.title
configuration.error.appGroup
settings.host.invalid
timeline.range.explanation
```

Use `AppLocalizer` for app-layer errors. In core recognition failures, replace localized `reason: String` construction with stable reason codes, then map codes to localization keys in `TodayView.issuePresentation(for:)`. Keep `technicalSummary` unchanged.

Add to `RecognitionPipelineModels.swift`:

```swift
public enum RecognitionFailureCode: String, Sendable, Equatable {
    case validationMissingContent
    case imageUnsupported
    case functionCallingUnsupported
    case authenticationFailed
    case rateLimited
    case serviceFailed
    case timedOut
    case offline
    case hostUnreachable
    case networkFailed
    case malformedResponse
    case missingFunctionCall
    case multipleFunctionCalls
    case unexpectedFunctionCall
    case malformedFunctionArguments
}
```

Add `public let code: RecognitionFailureCode` to
`RecognitionPipelineFailure` and require it in the initializer. Assign the
code at every construction site according to this table:

| Existing branch | Code | Localization key |
|---|---|---|
| validator lacks content/time | `validationMissingContent` | `recognition.failure.validationMissingContent` |
| image unsupported response | `imageUnsupported` | `recognition.failure.imageUnsupported` |
| tools/functions unsupported | `functionCallingUnsupported` | `recognition.failure.functionCallingUnsupported` |
| HTTP 401/403 | `authenticationFailed` | `recognition.failure.authenticationFailed` |
| HTTP 429 | `rateLimited` | `recognition.failure.rateLimited` |
| other non-2xx | `serviceFailed` | `recognition.failure.serviceFailed` |
| `URLError.timedOut` | `timedOut` | `recognition.failure.timedOut` |
| `URLError.notConnectedToInternet` | `offline` | `recognition.failure.offline` |
| DNS/connect failures | `hostUnreachable` | `recognition.failure.hostUnreachable` |
| other network error | `networkFailed` | `recognition.failure.networkFailed` |
| undecodable envelope | `malformedResponse` | `recognition.failure.malformedResponse` |
| no tool call | `missingFunctionCall` | `recognition.failure.missingFunctionCall` |
| multiple tool calls | `multipleFunctionCalls` | `recognition.failure.multipleFunctionCalls` |
| disallowed tool call | `unexpectedFunctionCall` | `recognition.failure.unexpectedFunctionCall` |
| invalid arguments | `malformedFunctionArguments` | `recognition.failure.malformedFunctionArguments` |

Add this mapper in `TodayView`:

```swift
private func recognitionFailureKey(
    _ code: RecognitionFailureCode
) -> String {
    "recognition.failure.\(code.rawValue)"
}
```

Construct the presentation with:

```swift
return .init(
    reason: AppLocalizer(
        language: settingsStore.value.language
    ).string(recognitionFailureKey(failure.code)),
    technicalDetails: failure.technicalDetails
)
```

Add every key in the table to both localization files. English service
messages use neutral actionable language; Simplified Chinese entries convey
the same meaning and do not expose raw provider responses.

English values:

```text
"recognition.failure.validationMissingContent" = "The image does not contain enough event information.";
"recognition.failure.imageUnsupported" = "The selected model does not support image recognition.";
"recognition.failure.functionCallingUnsupported" = "The selected model does not support structured recognition.";
"recognition.failure.authenticationFailed" = "The recognition service rejected the API credentials.";
"recognition.failure.rateLimited" = "The recognition service is busy. Try again later.";
"recognition.failure.serviceFailed" = "The recognition service returned an error.";
"recognition.failure.timedOut" = "The recognition request timed out.";
"recognition.failure.offline" = "Connect to the internet and try again.";
"recognition.failure.hostUnreachable" = "The recognition service could not be reached.";
"recognition.failure.networkFailed" = "The recognition request failed.";
"recognition.failure.malformedResponse" = "The recognition service returned an unreadable response.";
"recognition.failure.missingFunctionCall" = "The model did not return structured event data.";
"recognition.failure.multipleFunctionCalls" = "The model returned more than one event result.";
"recognition.failure.unexpectedFunctionCall" = "The model returned an unexpected event format.";
"recognition.failure.malformedFunctionArguments" = "The model returned invalid event fields.";
```

Simplified Chinese values:

```text
"recognition.failure.validationMissingContent" = "图片中缺少足够的事件信息。";
"recognition.failure.imageUnsupported" = "所选模型不支持图片识别。";
"recognition.failure.functionCallingUnsupported" = "所选模型不支持结构化识别。";
"recognition.failure.authenticationFailed" = "识别服务拒绝了 API 凭据。";
"recognition.failure.rateLimited" = "识别服务繁忙，请稍后重试。";
"recognition.failure.serviceFailed" = "识别服务返回错误。";
"recognition.failure.timedOut" = "识别请求超时。";
"recognition.failure.offline" = "请连接网络后重试。";
"recognition.failure.hostUnreachable" = "无法连接识别服务。";
"recognition.failure.networkFailed" = "识别请求失败。";
"recognition.failure.malformedResponse" = "识别服务返回了无法读取的响应。";
"recognition.failure.missingFunctionCall" = "模型未返回结构化事件数据。";
"recognition.failure.multipleFunctionCalls" = "模型返回了多个事件结果。";
"recognition.failure.unexpectedFunctionCall" = "模型返回了非预期的事件格式。";
"recognition.failure.malformedFunctionArguments" = "模型返回了无效的事件字段。";
```

- [ ] **Step 5: Apply contrast-safe display colors**

Add:

```swift
static func textColor(for accent: TimelineAccent) -> Color {
    switch accent {
    case .now:
        nowText
    case .pinned:
        pinnedText
    case .next:
        next
    case .neutral:
        neutral
    }
}
```

In `TodayView`, `FullTimelineView`, `SettingsView`, and
`ItemDetailView`, replace `TimelineTheme.color(for:)` with
`TimelineTheme.textColor(for:)` only when the result is applied directly to
`Text` or `Label`. Keep `TimelineTheme.color(for:)` on fills, borders, rails,
progress segments, and icons.

- [ ] **Step 6: Run localization and contrast tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/AppLocalizerTests \
-only-testing:PeckerTests/TimelineThemeContrastTests
```

Expected: parity and contrast suites pass.

- [ ] **Step 7: Commit**

```bash
git add Pecker/Localization/AppLocalizer.swift Pecker/Features/Onboarding/OnboardingModel.swift Pecker/Features/Settings/SettingsView.swift Pecker/Features/Today/TodayView.swift Pecker/App/PeckerApp.swift Sources/PeckerCore/Recognition/RecognitionPipelineModels.swift Pecker/Design/TimelineTheme.swift Pecker/Resources/en.lproj/Localizable.strings Pecker/Resources/zh-Hans.lproj/Localizable.strings PeckerTests/AppLocalizerTests.swift PeckerTests/TimelineThemeContrastTests.swift
git commit -m "fix: localize audited copy and improve contrast"
```

### Task 7: Restore Full Timeline pin action and truthful accessibility

**Files:**
- Modify: `Pecker/Features/Timeline/FullTimelineView.swift`
- Modify: `Pecker/Design/TimelineCard.swift`
- Modify: `PeckerTests/ItemDetailActionTests.swift`
- Modify: `PeckerTests/SwipeDeleteActionTests.swift`

- [ ] **Step 1: Add pin presentation tests**

Extract:

```swift
struct TimelinePinPresentation: Equatable {
    let symbol: String
    let accessibilityLabel: String

    static func make(
        item: TimelineItem,
        settings: TimelineSettings,
        localizer: AppLocalizer
    ) -> Self {
        let pinned =
            settings.manualPinnedSourceIdentifier
                == item.sourceIdentifier
        return .init(
            symbol: pinned ? "pin.fill" : "pin",
            accessibilityLabel: localizer.string(
                pinned ? "pin.action.unpin" : "pin.action.pin"
            )
        )
    }
}
```

Test both states and verify card accessibility text excludes the pin action:

```swift
XCTAssertFalse(
    FullTimelineAccessibility.cardLabel(
        item: item,
        section: section,
        now: now,
        localizer: localizer
    ).contains(localizer.string("pin.action.pin"))
)
```

- [ ] **Step 2: Verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/ItemDetailActionTests \
-only-testing:PeckerTests/SwipeDeleteActionTests
```

Expected: compilation fails because extracted presentation helpers are absent.

- [ ] **Step 3: Add a visible independent pin button**

In the timeline card header:

```swift
let pin = TimelinePinPresentation.make(
    item: item,
    settings: settings,
    localizer: localizer
)

Button {
    onTogglePin(item)
} label: {
    Image(systemName: pin.symbol)
        .font(.system(size: 15, weight: .semibold))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
.foregroundStyle(pinTint(for: item))
.accessibilityLabel(pin.accessibilityLabel)
```

Remove pin text from the parent card accessibility label. Card activation remains `onSelectItem(item)`.

- [ ] **Step 4: Hide unrevealed delete actions from VoiceOver**

On the destructive button:

```swift
.accessibilityHidden(!swipeState.deleteActionReceivesHitTesting)
```

On card content:

```swift
.accessibilityAddTraits(.isButton)
.accessibilityAction {
    if swipeState.isOpen {
        close()
    } else {
        onTap()
    }
}
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/ItemDetailActionTests \
-only-testing:PeckerTests/SwipeDeleteActionTests
```

Expected: pin and swipe tests pass.

```bash
git add Pecker/Features/Timeline/FullTimelineView.swift Pecker/Design/TimelineCard.swift PeckerTests/ItemDetailActionTests.swift PeckerTests/SwipeDeleteActionTests.swift
git commit -m "fix: expose truthful timeline pin actions"
```

### Task 8: Disclose timeline range and align documentation

**Files:**
- Modify: `Pecker/Features/Timeline/FullTimelineView.swift`
- Modify: `Pecker/Resources/en.lproj/Localizable.strings`
- Modify: `Pecker/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `README.md`
- Modify: `README.zh.md`
- Modify: `PeckerTests/AppLocalizerTests.swift`

- [ ] **Step 1: Add range-copy localization assertion**

```swift
func testTimelineRangeExplanationIsLocalized() {
    XCTAssertEqual(
        AppLocalizer(language: .english)
            .string("timeline.range.explanation"),
        "History and future events are loaded up to one year from today."
    )
    XCTAssertEqual(
        AppLocalizer(language: .simplifiedChinese)
            .string("timeline.range.explanation"),
        "历史和未来日程最多加载今天前后一年。"
    )
}
```

- [ ] **Step 2: Add localized copy and render it**

English:

```text
"timeline.range.explanation" = "History and future events are loaded up to one year from today.";
```

Chinese:

```text
"timeline.range.explanation" = "历史和未来日程最多加载今天前后一年。";
```

Render below content for non-active Full Timeline:

```swift
if !activeOnly {
    Text(localizer.string("timeline.range.explanation"))
        .font(.caption)
        .foregroundStyle(TimelineTheme.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
}
```

- [ ] **Step 3: Update requirements in both READMEs**

Replace iOS 16+, Swift 5+, and Xcode 14+ with:

```text
iOS 26.0+
Swift 6.0+
Xcode 26.0+
```

Keep English and Chinese sections structurally aligned.

- [ ] **Step 4: Run repository-wide verification**

```bash
rg -n 'iOS 16|Swift 5|Xcode 14' README.md README.zh.md
```

Expected: no matches.

```bash
swift test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-configuration Debug -destination 'generic/platform=iOS Simulator' \
CODE_SIGNING_ALLOWED=NO build-for-testing
```

Expected: all package tests pass and `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 5: Perform simulator acceptance**

1. Verify Today and Full Timeline show the same AI-recognized type.
2. Delete an imported image event and confirm it does not reappear.
3. Replace an existing API key and confirm failure does not erase it.
4. Enter invalid Host values and confirm they are not persisted.
5. Switch between English and Chinese and inspect Settings, recognition failures, onboarding, Full Timeline, and configuration failure.
6. Test Accessibility Extra Extra Extra Large and VoiceOver.
7. Verify pin and card actions are separately focusable.
8. Verify semantic text remains legible on cards and page background.

- [ ] **Step 6: Commit**

```bash
git add Pecker/Features/Timeline/FullTimelineView.swift Pecker/Resources/en.lproj/Localizable.strings Pecker/Resources/zh-Hans.lproj/Localizable.strings README.md README.zh.md PeckerTests/AppLocalizerTests.swift
git commit -m "docs: disclose timeline range and platform baseline"
```
