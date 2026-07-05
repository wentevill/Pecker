# Permission Recovery and Settings State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users recover Calendar and Reminders access after onboarding while keeping Settings authorization state current and accessible.

**Architecture:** `SettingsViewModel` becomes the single mutable owner of Settings authorization state and derives a permission action for each source. It requests first-time access through `EventKitGatewayProtocol`, redirects unreadable established states to system Settings, and refreshes state on appearance and foreground transitions.

**Tech Stack:** Swift 6, SwiftUI, Observation, EventKit, XCTest, Xcode 26

---

## File Map

- Modify `Pecker/Features/Settings/SettingsView.swift`: mutable authorization model, permission actions, lifecycle refresh, adaptive source rows.
- Modify `Pecker/App/PeckerApp.swift`: pass the EventKit gateway into the Settings model.
- Modify `Pecker/Resources/en.lproj/Localizable.strings`: English permission action and error copy.
- Modify `Pecker/Resources/zh-Hans.lproj/Localizable.strings`: Simplified Chinese equivalents.
- Modify `PeckerTests/SettingsViewModelTests.swift`: model behavior and regression coverage.
- Modify `PeckerTests/AppLocalizerTests.swift`: new-key coverage.

### Task 1: Derive permission actions from authorization

**Files:**
- Modify: `Pecker/Features/Settings/SettingsView.swift:5-108`
- Test: `PeckerTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write the failing action-mapping test**

Add inside `SettingsViewModelTests`:

```swift
@MainActor
func testPermissionActionMatchesEveryAuthorizationState() {
    let notDetermined = SettingsViewModel(
        settingsStore: makeStore(),
        gateway: SettingsGateway(
            authorization: .init(
                calendar: .notDetermined,
                reminders: .writeOnly
            )
        ),
        authorization: .init(
            calendar: .notDetermined,
            reminders: .writeOnly
        ),
        onSettingsChanged: {},
        openURL: { _ in }
    )
    XCTAssertEqual(
        notDetermined.permissionAction(for: .calendar),
        .requestAccess
    )
    XCTAssertEqual(
        notDetermined.permissionAction(for: .reminder),
        .openSettings
    )

    let authorized = SettingsViewModel(
        settingsStore: makeStore(),
        gateway: SettingsGateway(
            authorization: .init(
                calendar: .fullAccess,
                reminders: .denied
            )
        ),
        authorization: .init(
            calendar: .fullAccess,
            reminders: .denied
        ),
        onSettingsChanged: {},
        openURL: { _ in }
    )
    XCTAssertNil(authorized.permissionAction(for: .calendar))
    XCTAssertEqual(
        authorized.permissionAction(for: .reminder),
        .openSettings
    )

    let restricted = SettingsViewModel(
        settingsStore: makeStore(),
        gateway: SettingsGateway(
            authorization: .init(
                calendar: .restricted,
                reminders: .fullAccess
            )
        ),
        authorization: .init(
            calendar: .restricted,
            reminders: .fullAccess
        ),
        onSettingsChanged: {},
        openURL: { _ in }
    )
    XCTAssertEqual(
        restricted.permissionAction(for: .calendar),
        .openSettings
    )
    XCTAssertNil(restricted.permissionAction(for: .reminder))
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/SettingsViewModelTests/testPermissionActionMatchesEveryAuthorizationState
```

Expected: compilation fails because `gateway`, `SourcePermissionAction`, and `permissionAction(for:)` do not exist.

- [ ] **Step 3: Add the model API**

In `SettingsView.swift`, add:

```swift
enum SourcePermissionAction: Equatable {
    case requestAccess
    case openSettings
}
```

Change the model fields and initializer to:

```swift
@MainActor
@Observable
final class SettingsViewModel {
    let settingsStore: SettingsStore
    private(set) var authorization: SourceAuthorization
    private(set) var permissionErrorText: String?
    private(set) var isRequestingPermission = false

    private let gateway: any EventKitGatewayProtocol
    private let apiKeyStore: any APIKeyStoring
    private let liveActivityStatusProvider: @MainActor () -> String
    private let onSettingsChanged: @MainActor () -> Void
    private let openURL: (URL) -> Void

    init(
        settingsStore: SettingsStore,
        gateway: any EventKitGatewayProtocol,
        authorization: SourceAuthorization,
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        liveActivityStatusText: @escaping @MainActor () -> String = {
            "waiting"
        },
        onSettingsChanged: @escaping @MainActor () -> Void,
        openURL: @escaping (URL) -> Void
    ) {
        self.settingsStore = settingsStore
        self.gateway = gateway
        self.authorization = authorization
        self.apiKeyStore = apiKeyStore
        liveActivityStatusProvider = liveActivityStatusText
        self.onSettingsChanged = onSettingsChanged
        self.openURL = openURL
    }

    func permissionAction(
        for source: TimelineSource
    ) -> SourcePermissionAction? {
        switch sourceStatus(for: source) {
        case .notDetermined:
            .requestAccess
        case .denied, .restricted, .writeOnly:
            .openSettings
        case .fullAccess:
            nil
        }
    }
}
```

Update every `SettingsViewModel` construction in app code, previews, and tests to pass a gateway. Tests may use `SettingsGateway`.

- [ ] **Step 4: Add the reusable test gateway**

Append to `SettingsViewModelTests.swift`:

```swift
private actor SettingsGateway: EventKitGatewayProtocol {
    enum RequestError: Error { case failed }

    private var currentAuthorization: SourceAuthorization
    private let calendarResult: Result<Bool, Error>
    private let reminderResult: Result<Bool, Error>
    private var calendarRequests = 0
    private var reminderRequests = 0

    init(
        authorization: SourceAuthorization,
        calendarResult: Result<Bool, Error> = .success(true),
        reminderResult: Result<Bool, Error> = .success(true)
    ) {
        currentAuthorization = authorization
        self.calendarResult = calendarResult
        self.reminderResult = reminderResult
    }

    func authorization() -> SourceAuthorization { currentAuthorization }

    func requestCalendarAccess() async throws -> Bool {
        calendarRequests += 1
        let granted = try calendarResult.get()
        currentAuthorization = .init(
            calendar: granted ? .fullAccess : .denied,
            reminders: currentAuthorization.reminders
        )
        return granted
    }

    func requestReminderAccess() async throws -> Bool {
        reminderRequests += 1
        let granted = try reminderResult.get()
        currentAuthorization = .init(
            calendar: currentAuthorization.calendar,
            reminders: granted ? .fullAccess : .denied
        )
        return granted
    }

    func fetchToday(
        calendar: Calendar,
        now: Date
    ) async throws -> [EventRecord] { [] }

    func fetchReminders(
        calendar: Calendar,
        now: Date
    ) async throws -> [ReminderRecord] { [] }

    func requestCounts() -> (calendar: Int, reminders: Int) {
        (calendarRequests, reminderRequests)
    }
}
```

- [ ] **Step 5: Run the action-mapping test**

Run the Step 2 command.

Expected: `testPermissionActionMatchesEveryAuthorizationState` passes.

- [ ] **Step 6: Commit**

```bash
git add Pecker/Features/Settings/SettingsView.swift PeckerTests/SettingsViewModelTests.swift Pecker/App/PeckerApp.swift
git commit -m "refactor: model settings permission actions"
```

### Task 2: Request access and refresh authorization

**Files:**
- Modify: `Pecker/Features/Settings/SettingsView.swift:65-190`
- Test: `PeckerTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write failing request and refresh tests**

Add:

```swift
@MainActor
func testRequestCalendarAccessRefreshesAuthorizationAndNotifies() async {
    let gateway = SettingsGateway(
        authorization: .init(
            calendar: .notDetermined,
            reminders: .fullAccess
        )
    )
    var notifications = 0
    let viewModel = SettingsViewModel(
        settingsStore: makeStore(),
        gateway: gateway,
        authorization: .init(
            calendar: .notDetermined,
            reminders: .fullAccess
        ),
        onSettingsChanged: { notifications += 1 },
        openURL: { _ in }
    )

    await viewModel.performPermissionAction(
        for: .calendar,
        localizer: AppLocalizer(language: .english)
    )

    XCTAssertEqual(viewModel.authorization.calendar, .fullAccess)
    XCTAssertNil(viewModel.permissionErrorText)
    XCTAssertEqual(notifications, 1)
    let counts = await gateway.requestCounts()
    XCTAssertEqual(counts.calendar, 1)
}

@MainActor
func testPermissionFailureKeepsPreferenceAndShowsLocalizedError() async {
    let store = makeStore()
    let gateway = SettingsGateway(
        authorization: .init(
            calendar: .notDetermined,
            reminders: .fullAccess
        ),
        calendarResult: .failure(SettingsGateway.RequestError.failed)
    )
    let viewModel = SettingsViewModel(
        settingsStore: store,
        gateway: gateway,
        authorization: await gateway.authorization(),
        onSettingsChanged: {},
        openURL: { _ in }
    )

    await viewModel.performPermissionAction(
        for: .calendar,
        localizer: AppLocalizer(language: .english)
    )

    XCTAssertTrue(store.value.calendarEnabled)
    XCTAssertEqual(
        viewModel.permissionErrorText,
        "Unable to request Calendar access. Try again."
    )
}

@MainActor
func testRefreshAuthorizationReadsGatewayAgain() async {
    let gateway = SettingsGateway(
        authorization: .init(
            calendar: .writeOnly,
            reminders: .fullAccess
        )
    )
    let viewModel = SettingsViewModel(
        settingsStore: makeStore(),
        gateway: gateway,
        authorization: .init(
            calendar: .notDetermined,
            reminders: .notDetermined
        ),
        onSettingsChanged: {},
        openURL: { _ in }
    )

    await viewModel.refreshAuthorization()

    XCTAssertEqual(
        viewModel.authorization,
        .init(calendar: .writeOnly, reminders: .fullAccess)
    )
}
```

- [ ] **Step 2: Run the three tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/SettingsViewModelTests
```

Expected: compilation fails because `performPermissionAction` and `refreshAuthorization` are missing.

- [ ] **Step 3: Implement refresh, request, and redirect behavior**

Add to `SettingsViewModel`:

```swift
func refreshAuthorization() async {
    authorization = await gateway.authorization()
}

func performPermissionAction(
    for source: TimelineSource,
    localizer: AppLocalizer
) async {
    guard !isRequestingPermission else { return }
    permissionErrorText = nil

    switch permissionAction(for: source) {
    case .requestAccess:
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        do {
            switch source {
            case .calendar:
                _ = try await gateway.requestCalendarAccess()
            case .reminder:
                _ = try await gateway.requestReminderAccess()
            case .external:
                return
            }
            authorization = await gateway.authorization()
            onSettingsChanged()
        } catch {
            permissionErrorText = localizer.string(
                source == .calendar
                    ? "settings.permission.calendar.error"
                    : "settings.permission.reminders.error"
            )
        }
    case .openSettings:
        guard let url = URL(
            string: UIApplication.openSettingsURLString
        ) else {
            permissionErrorText = localizer.string(
                "settings.permission.openSettings.error"
            )
            return
        }
        openURL(url)
    case nil:
        return
    }
}
```

Delete `openSourceSettings(for:)`; its behavior is now covered by `performPermissionAction`.

- [ ] **Step 4: Run Settings model tests**

Run the Step 2 command.

Expected: all `SettingsViewModelTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Pecker/Features/Settings/SettingsView.swift PeckerTests/SettingsViewModelTests.swift
git commit -m "feat: recover skipped event permissions"
```

### Task 3: Wire lifecycle refresh and adaptive source rows

**Files:**
- Modify: `Pecker/Features/Settings/SettingsView.swift:190-590`
- Modify: `Pecker/App/PeckerApp.swift:115-145`
- Test: `PeckerTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Add an action-title test**

```swift
@MainActor
func testPermissionActionTitlesAreLocalized() {
    let viewModel = SettingsViewModel(
        settingsStore: makeStore(),
        gateway: SettingsGateway(
            authorization: .init(
                calendar: .notDetermined,
                reminders: .writeOnly
            )
        ),
        authorization: .init(
            calendar: .notDetermined,
            reminders: .writeOnly
        ),
        onSettingsChanged: {},
        openURL: { _ in }
    )
    let localizer = AppLocalizer(language: .english)

    XCTAssertEqual(
        viewModel.permissionActionTitle(
            for: .calendar,
            localizer: localizer
        ),
        "Allow Access"
    )
    XCTAssertEqual(
        viewModel.permissionActionTitle(
            for: .reminder,
            localizer: localizer
        ),
        "Open Settings"
    )
}
```

- [ ] **Step 2: Verify the title test fails**

Run the Task 2 Step 2 command.

Expected: compilation fails because `permissionActionTitle` is missing.

- [ ] **Step 3: Add localized title mapping**

```swift
func permissionActionTitle(
    for source: TimelineSource,
    localizer: AppLocalizer
) -> String? {
    switch permissionAction(for: source) {
    case .requestAccess:
        localizer.string("settings.permission.allow")
    case .openSettings:
        localizer.string("settings.permission.openSettings")
    case nil:
        nil
    }
}
```

- [ ] **Step 4: Refresh permission state from SwiftUI lifecycle**

Add to `SettingsView`:

```swift
@Environment(\.scenePhase) private var scenePhase
```

Attach to the root `NavigationStack`:

```swift
.task {
    await viewModel.refreshAuthorization()
}
.onChange(of: scenePhase) { _, phase in
    guard phase == .active else { return }
    Task { await viewModel.refreshAuthorization() }
}
.alert(
    localizer.string("operation.failed"),
    isPresented: Binding(
        get: { viewModel.permissionErrorText != nil },
        set: { if !$0 { viewModel.clearPermissionError() } }
    )
) {
    Button(localizer.string("common.ok")) {
        viewModel.clearPermissionError()
    }
} message: {
    Text(viewModel.permissionErrorText ?? "")
}
```

Add:

```swift
func clearPermissionError() {
    permissionErrorText = nil
}
```

- [ ] **Step 5: Replace `sourceRow` with an adaptive layout**

Add:

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize
```

Replace the returned row content with:

```swift
let controls = HStack(spacing: 10) {
    if let actionTitle = viewModel.permissionActionTitle(
        for: source,
        localizer: localizer
    ) {
        Button(actionTitle) {
            Task {
                await viewModel.performPermissionAction(
                    for: source,
                    localizer: localizer
                )
            }
        }
        .buttonStyle(
            SettingsPillButtonStyle(
                accent: TimelineTheme.color(for: accent),
                filled: false
            )
        )
        .disabled(viewModel.isRequestingPermission)
    } else {
        statusBadge(status)
    }

    Toggle(title, isOn: isEnabledBinding)
        .labelsHidden()
}

return Group {
    if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(
                        viewModel.sourceStatusDescription(
                            for: source,
                            localizer: localizer
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(TimelineTheme.textTertiary)
                }
            } icon: {
                rowIcon(systemImage, accent: accent)
            }
            controls.frame(maxWidth: .infinity, alignment: .leading)
        }
    } else {
        HStack(alignment: .center, spacing: 12) {
            rowIcon(systemImage, accent: accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(
                    viewModel.sourceStatusDescription(
                        for: source,
                        localizer: localizer
                    )
                )
                .font(.caption)
                .foregroundStyle(TimelineTheme.textTertiary)
            }
            Spacer(minLength: 8)
            controls
        }
    }
}
.padding(.horizontal, 12)
.padding(.vertical, 10)
```

- [ ] **Step 6: Pass the production gateway**

Change `TodayView.makeSettingsViewModel` to accept `gateway`, and pass `model.dependencies.gateway` from the sheet construction. Construct the model with:

```swift
SettingsViewModel(
    settingsStore: settingsStore,
    gateway: gateway,
    authorization: authorization,
    liveActivityStatusText: liveActivityStatusText,
    onSettingsChanged: onSettingsChanged,
    openURL: openURL
)
```

Update preview hosts to pass `NoopSettingsGateway`, defined under `#if DEBUG`:

```swift
private actor NoopSettingsGateway: EventKitGatewayProtocol {
    func authorization() -> SourceAuthorization {
        .init(calendar: .denied, reminders: .fullAccess)
    }
    func requestCalendarAccess() async throws -> Bool { false }
    func requestReminderAccess() async throws -> Bool { false }
    func fetchToday(
        calendar: Calendar,
        now: Date
    ) async throws -> [EventRecord] { [] }
    func fetchReminders(
        calendar: Calendar,
        now: Date
    ) async throws -> [ReminderRecord] { [] }
}
```

- [ ] **Step 7: Build the app**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-configuration Debug -destination 'generic/platform=iOS Simulator' \
CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add Pecker/Features/Settings/SettingsView.swift Pecker/Features/Today/TodayView.swift Pecker/App/PeckerApp.swift
git commit -m "feat: refresh permissions in settings"
```

### Task 4: Localize permission recovery and verify

**Files:**
- Modify: `Pecker/Resources/en.lproj/Localizable.strings`
- Modify: `Pecker/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `PeckerTests/AppLocalizerTests.swift`

- [ ] **Step 1: Add failing localization assertions**

```swift
func testPermissionRecoveryCopyExistsInBothLanguages() {
    let english = AppLocalizer(language: .english)
    let chinese = AppLocalizer(language: .simplifiedChinese)
    let keys = [
        "settings.permission.allow",
        "settings.permission.openSettings",
        "settings.permission.calendar.error",
        "settings.permission.reminders.error",
        "settings.permission.openSettings.error"
    ]

    for key in keys {
        XCTAssertNotEqual(english.string(key), key)
        XCTAssertNotEqual(chinese.string(key), key)
    }
}
```

- [ ] **Step 2: Verify the localization test fails**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/AppLocalizerTests/testPermissionRecoveryCopyExistsInBothLanguages
```

Expected: failure because the new keys resolve to themselves.

- [ ] **Step 3: Add English strings**

```text
"settings.permission.allow" = "Allow Access";
"settings.permission.openSettings" = "Open Settings";
"settings.permission.calendar.error" = "Unable to request Calendar access. Try again.";
"settings.permission.reminders.error" = "Unable to request Reminders access. Try again.";
"settings.permission.openSettings.error" = "Unable to open system Settings.";
```

- [ ] **Step 4: Add Simplified Chinese strings**

```text
"settings.permission.allow" = "允许访问";
"settings.permission.openSettings" = "打开系统设置";
"settings.permission.calendar.error" = "无法请求日历访问权限，请重试。";
"settings.permission.reminders.error" = "无法请求提醒事项访问权限，请重试。";
"settings.permission.openSettings.error" = "无法打开系统设置。";
```

- [ ] **Step 5: Run focused and full verification**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/SettingsViewModelTests \
-only-testing:PeckerTests/AppLocalizerTests

swift test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-configuration Debug -destination 'generic/platform=iOS Simulator' \
CODE_SIGNING_ALLOWED=NO build-for-testing
```

Expected: focused tests pass, Swift Package reports 99 tests passed, and Xcode reports `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 6: Perform simulator acceptance**

On a booted simulator:

1. Reset Calendar and Reminders privacy permissions.
2. Skip both permissions during onboarding.
3. Open Settings and verify both rows display “Allow Access.”
4. Grant Calendar; verify the row becomes “Authorized” without closing Settings.
5. Deny Reminders; verify the row offers “Open Settings.”
6. Change permission in system Settings and return; verify the badge refreshes.
7. Set Accessibility Extra Extra Extra Large; verify controls remain visible and do not overlap.

- [ ] **Step 7: Commit**

```bash
git add Pecker/Resources/en.lproj/Localizable.strings Pecker/Resources/zh-Hans.lproj/Localizable.strings PeckerTests/AppLocalizerTests.swift
git commit -m "test: cover permission recovery experience"
```
