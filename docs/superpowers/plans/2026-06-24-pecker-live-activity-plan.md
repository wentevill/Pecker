# Pecker Live Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Pecker’s native Live Activity and Dynamic Island support so the app can show the current most important timeline item on the Lock Screen after explicit user activation.

**Architecture:** The app owns EventKit refresh, snapshot persistence, and ActivityKit lifecycle reconciliation. A Widget Extension renders only supplied ActivityKit state, sharing a small `PeckerActivityAttributes` type with the app. The lifecycle coordinator is protocol-driven so start/update/end decisions are testable without creating real system activities.

**Tech Stack:** Swift 6, SwiftUI, ActivityKit, WidgetKit, XcodeGen, XCTest, iOS 26.

---

## Current identity and naming

Use the current Pecker project identity everywhere:

- Xcode project and app target: `Pecker`
- Core target: `PeckerCore`
- App tests: `PeckerTests`
- Live Activity extension target: `PeckerLiveActivity`
- App bundle identifier: `com.wenttang.pecker`
- Extension bundle identifier: `com.wenttang.pecker.liveactivity`
- App Group: `group.com.wenttang.pecker`
- Development team: `LNQGSLWW24`

Do not introduce `NowTimeline`, `NowTimelineCore`, `NowTimelineLiveActivity`, or `com.went.NowTimeline` identifiers in active source/config.

## File map

```text
project.yml
Shared/PeckerActivityAttributes.swift
Pecker/Activity/ActivityClient.swift
Pecker/Activity/ActivityCoordinator.swift
Pecker/App/AppDependencies.swift
Pecker/App/AppModel.swift
Pecker/Features/Onboarding/OnboardingModel.swift
Pecker/Features/Onboarding/OnboardingView.swift
Pecker/Features/Settings/SettingsView.swift
Pecker/Features/Today/TodayViewModel.swift
PeckerLiveActivity/PeckerLiveActivityBundle.swift
PeckerLiveActivity/PeckerLiveActivityWidget.swift
PeckerLiveActivity/LockScreenLiveActivityView.swift
PeckerLiveActivity/DynamicIslandLiveActivityView.swift
PeckerLiveActivity/Info.plist
PeckerLiveActivity/PeckerLiveActivity.entitlements
PeckerTests/ActivityCoordinatorTests.swift
PeckerTests/TodayViewModelTests.swift
```

## Task 1: Add shared ActivityKit state and Widget Extension target

**Files:**

- Modify: `project.yml`
- Create: `Shared/PeckerActivityAttributes.swift`
- Create: `PeckerLiveActivity/PeckerLiveActivityBundle.swift`
- Create: `PeckerLiveActivity/Info.plist`
- Create: `PeckerLiveActivity/PeckerLiveActivity.entitlements`

- [ ] **Step 1: Add a compile reference before the shared type exists**

Add `PeckerLiveActivity` to `project.yml` as a Widget Extension target with sources from `PeckerLiveActivity` and `Shared`.

Use these settings:

```yaml
  PeckerLiveActivity:
    type: app-extension
    platform: iOS
    sources:
      - path: PeckerLiveActivity
      - path: Shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.wenttang.pecker.liveactivity
        PRODUCT_NAME: PeckerLiveActivity
        GENERATE_INFOPLIST_FILE: NO
        INFOPLIST_FILE: PeckerLiveActivity/Info.plist
        CODE_SIGN_ENTITLEMENTS: PeckerLiveActivity/PeckerLiveActivity.entitlements
        DEVELOPMENT_TEAM: LNQGSLWW24
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: Apple Development
        PROVISIONING_PROFILE_SPECIFIER: ""
        SKIP_INSTALL: YES
    dependencies:
      - target: PeckerCore
```

Add it to the `Pecker` scheme build targets and make the app depend on it with `embed: true`.

Create `PeckerLiveActivity/PeckerLiveActivityBundle.swift` with a deliberate reference to the not-yet-created type:

```swift
import SwiftUI
import WidgetKit

@main
struct PeckerLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        _ = PeckerActivityAttributes.self
        PeckerLiveActivityWidget()
    }
}
```

- [ ] **Step 2: Generate and verify RED build failure**

Run:

```bash
xcodegen generate --spec project.yml
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PeckerLiveActivityRed \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `PeckerActivityAttributes` and `PeckerLiveActivityWidget` do not exist yet.

- [ ] **Step 3: Define the shared ActivityKit attributes**

Create `Shared/PeckerActivityAttributes.swift`:

```swift
import ActivityKit
import Foundation

public struct PeckerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public let primaryTitle: String
        public let primarySubtitle: String?
        public let primaryStartDate: Date?
        public let primaryEndDate: Date?
        public let primaryKindRawValue: String
        public let primarySourceIdentifier: String?
        public let nextTitle: String?
        public let nextStartDate: Date?
        public let pinnedTitle: String?
        public let pinnedSubtitle: String?
        public let additionalActiveCount: Int
        public let generatedAt: Date

        public init(
            primaryTitle: String,
            primarySubtitle: String?,
            primaryStartDate: Date?,
            primaryEndDate: Date?,
            primaryKindRawValue: String,
            primarySourceIdentifier: String?,
            nextTitle: String?,
            nextStartDate: Date?,
            pinnedTitle: String?,
            pinnedSubtitle: String?,
            additionalActiveCount: Int,
            generatedAt: Date
        ) {
            self.primaryTitle = primaryTitle
            self.primarySubtitle = primarySubtitle
            self.primaryStartDate = primaryStartDate
            self.primaryEndDate = primaryEndDate
            self.primaryKindRawValue = primaryKindRawValue
            self.primarySourceIdentifier = primarySourceIdentifier
            self.nextTitle = nextTitle
            self.nextStartDate = nextStartDate
            self.pinnedTitle = pinnedTitle
            self.pinnedSubtitle = pinnedSubtitle
            self.additionalActiveCount = additionalActiveCount
            self.generatedAt = generatedAt
        }
    }

    public let localDayIdentifier: String

    public init(localDayIdentifier: String) {
        self.localDayIdentifier = localDayIdentifier
    }
}
```

Create `PeckerLiveActivity/Info.plist` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
    <key>NSSupportsLiveActivities</key>
    <true/>
</dict>
</plist>
```

Create `PeckerLiveActivity/PeckerLiveActivity.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.wenttang.pecker</string>
    </array>
</dict>
</plist>
```

Add `NSSupportsLiveActivities = true` to `Pecker/Resources/Info.plist`.

- [ ] **Step 4: Add a minimal widget shell and verify GREEN build**

Create `PeckerLiveActivity/PeckerLiveActivityWidget.swift`:

```swift
import ActivityKit
import SwiftUI
import WidgetKit

struct PeckerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PeckerActivityAttributes.self) { context in
            Text(context.state.primaryTitle)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.primaryTitle)
                }
            } compactLeading: {
                Circle().fill(.green).frame(width: 8, height: 8)
            } compactTrailing: {
                Text("Now")
            } minimal: {
                Circle().fill(.green).frame(width: 8, height: 8)
            }
        }
    }
}
```

Run the same build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add project.yml Shared PeckerLiveActivity Pecker/Resources/Info.plist Pecker.xcodeproj
git commit -m "build: add Pecker Live Activity extension"
```

## Task 2: Implement and test ActivityCoordinator decisions

**Files:**

- Create: `Pecker/Activity/ActivityClient.swift`
- Create: `Pecker/Activity/ActivityCoordinator.swift`
- Test: `PeckerTests/ActivityCoordinatorTests.swift`

- [ ] **Step 1: Write failing coordinator tests**

Create tests that use a fake client and deterministic snapshots. Cover:

- disabled setting produces `.end`;
- explicit first activation produces `.start`;
- changed content produces `.update`;
- equal content produces `.none`;
- empty snapshot produces `.end`;
- Now, Next, Pinned-only, and additional active count mapping;
- stale date equals the next meaningful boundary or snapshot stale date, whichever comes first.

Use this expected decision model in tests:

```swift
enum ActivityDecision: Equatable {
    case none
    case start(PeckerActivityAttributes.ContentState, Date)
    case update(PeckerActivityAttributes.ContentState, Date)
    case end
}
```

- [ ] **Step 2: Verify RED test failure**

Run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' \
  -only-testing:PeckerTests/ActivityCoordinatorTests \
  -derivedDataPath /tmp/PeckerLiveActivityCoordinatorRed \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `ActivityCoordinator`, `ActivityClient`, and `ActivityDecision` do not exist.

- [ ] **Step 3: Implement protocol, decisions, coordinator, and real client**

Create `Pecker/Activity/ActivityClient.swift`:

```swift
import ActivityKit
import Foundation

enum ActivityDecision: Equatable, Sendable {
    case none
    case start(PeckerActivityAttributes.ContentState, Date)
    case update(PeckerActivityAttributes.ContentState, Date)
    case end
}

protocol ActivityClient: Sendable {
    func currentState() async -> PeckerActivityAttributes.ContentState?
    func apply(_ decision: ActivityDecision, attributes: PeckerActivityAttributes) async throws
}

struct LiveActivityClient: ActivityClient {
    func currentState() async -> PeckerActivityAttributes.ContentState? {
        Activity<PeckerActivityAttributes>.activities.first?.content.state
    }

    func apply(_ decision: ActivityDecision, attributes: PeckerActivityAttributes) async throws {
        switch decision {
        case .none:
            return
        case let .start(state, staleDate):
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleDate),
                pushType: nil
            )
        case let .update(state, staleDate):
            for activity in Activity<PeckerActivityAttributes>.activities {
                await activity.update(ActivityContent(state: state, staleDate: staleDate))
            }
        case .end:
            for activity in Activity<PeckerActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
```

Create `Pecker/Activity/ActivityCoordinator.swift` to map `TodaySnapshot` and `TimelineSettings` into state. The coordinator must:

- use `snapshot.now` as primary when present;
- fall back to `snapshot.next`;
- fall back to the manual pinned item when present and unfinished;
- end when there is no primary item;
- set `additionalActiveCount` to active items beyond the visible primary;
- compare with `client.currentState()` and return `.none` for equal state;
- compute stale date from the earliest of primary end, next start, pinned start/end if future, and `snapshot.staleAfter`.

- [ ] **Step 4: Verify GREEN tests and commit**

Run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' \
  -only-testing:PeckerTests/ActivityCoordinatorTests \
  -derivedDataPath /tmp/PeckerLiveActivityCoordinatorGreen \
  CODE_SIGNING_ALLOWED=NO
```

Expected: ActivityCoordinatorTests PASS.

```bash
git add Pecker/Activity PeckerTests/ActivityCoordinatorTests.swift
git commit -m "feat: coordinate Pecker Live Activity lifecycle"
```

## Task 3: Connect explicit activation and app refresh

**Files:**

- Modify: `Pecker/App/AppDependencies.swift`
- Modify: `Pecker/App/AppModel.swift`
- Modify: `Pecker/Features/Onboarding/OnboardingModel.swift`
- Modify: `Pecker/Features/Onboarding/OnboardingView.swift`
- Modify: `Pecker/Features/Settings/SettingsView.swift`
- Modify: `Pecker/Features/Today/TodayViewModel.swift`
- Test: `PeckerTests/TodayViewModelTests.swift`
- Test: `PeckerTests/OnboardingStateTests.swift`

- [ ] **Step 1: Add failing integration tests**

Add tests for:

- onboarding enable action sets `liveActivityEnabled`;
- refresh reconciles after a new snapshot is saved;
- disabled setting ends the current activity;
- resume starts when relevant content exists;
- ActivityKit unavailable status is surfaced without crashing.

- [ ] **Step 2: Verify RED failures**

Run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' \
  -only-testing:PeckerTests/TodayViewModelTests \
  -only-testing:PeckerTests/OnboardingStateTests \
  -derivedDataPath /tmp/PeckerLiveActivityFlowRed \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because app flow does not reconcile real Live Activities yet.

- [ ] **Step 3: Wire the coordinator**

Add the coordinator/client to `AppDependencies`. Reconcile:

- after onboarding explicit enable;
- after successful snapshot persistence in `TodayViewModel`;
- after settings toggles pause/resume;
- when app returns foreground and refresh completes.

Replace placeholder copy:

- onboarding should say it enables Live Activity on the Lock Screen and Dynamic Island;
- settings should show `active`, `paused`, `unavailable`, or `needs activation` instead of “尚未接入 ActivityKit”.

Keep activation user-initiated; never start before `settings.liveActivityEnabled == true`.

- [ ] **Step 4: Verify GREEN tests and commit**

Run the same focused test command. Expected: PASS.

```bash
git add Pecker/App Pecker/Features PeckerTests
git commit -m "feat: manage Live Activity from Pecker app flow"
```

## Task 4: Render Lock Screen Live Activity

**Files:**

- Create: `PeckerLiveActivity/LockScreenLiveActivityView.swift`
- Modify: `PeckerLiveActivity/PeckerLiveActivityWidget.swift`

- [ ] **Step 1: Add previews for fallback states**

Add previews for:

- Now + Next + Pinned;
- Now + Next;
- Next only;
- Pinned only;
- Now with `additionalActiveCount > 0`.

- [ ] **Step 2: Verify RED build failure**

Reference `LockScreenLiveActivityView` from the widget before creating it, then run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PeckerLiveActivityLockScreenRed \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because `LockScreenLiveActivityView` does not exist.

- [ ] **Step 3: Implement the approved Lock Screen hierarchy**

Create a compact SwiftUI view that follows `docs/visual-design/previews/05-live-activity.jpg`:

- green Now/primary label and title;
- system timer text when `primaryEndDate` exists;
- progress based on `primaryStartDate` and `primaryEndDate`;
- text `另有 N 项进行中` when `additionalActiveCount > 0`;
- blue Next row when available;
- orange pinned row when available and space permits;
- fallback title labels when primary is Next or Pinned.

Use `activityBackgroundTint` and `activitySystemActionForegroundColor` with high contrast.

- [ ] **Step 4: Build and commit**

Run the same build command. Expected: BUILD SUCCEEDED.

```bash
git add PeckerLiveActivity
git commit -m "feat: render Pecker Lock Screen Live Activity"
```

## Task 5: Render Dynamic Island states

**Files:**

- Create: `PeckerLiveActivity/DynamicIslandLiveActivityView.swift`
- Modify: `PeckerLiveActivity/PeckerLiveActivityWidget.swift`

- [ ] **Step 1: Add compact, expanded, and minimal previews**

Include long-title and Next-only states.

- [ ] **Step 2: Verify RED build failure**

Reference `DynamicIslandLiveActivityView` from the widget before creating it, then run the extension/app build.

Expected: FAIL because `DynamicIslandLiveActivityView` does not exist.

- [ ] **Step 3: Implement Dynamic Island regions**

Use:

- compact leading: semantic status dot or short primary title;
- compact trailing: remaining minutes when available;
- expanded leading: primary item;
- expanded trailing: countdown;
- expanded bottom: Next row, progress, and active-count text;
- minimal: status dot or remaining timer.

When no meaningful title fits, prioritize status and countdown rather than opaque abbreviations.

- [ ] **Step 4: Build and commit**

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PeckerLiveActivityDynamicIslandGreen \
  CODE_SIGNING_ALLOWED=NO
git add PeckerLiveActivity
git commit -m "feat: render Pecker Dynamic Island states"
```

## Task 6: Final verification and device-check notes

**Files:**

- Create: `docs/verification/live-activity-device-check.md`

- [ ] **Step 1: Run automated verification**

```bash
swift test
xcodegen generate --spec project.yml
git diff --exit-code -- Pecker.xcodeproj project.yml
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' \
  -derivedDataPath /tmp/PeckerLiveActivityFinalTests \
  CODE_SIGNING_ALLOWED=NO
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PeckerLiveActivityFinalRelease \
  CODE_SIGNING_ALLOWED=NO
rg -n 'NowTimeline|NowTimelineCore|NowTimelineTests|NowTimelineLiveActivity|NowTimeline\\.xcodeproj|group\\.com\\.went\\.nowtimeline|group\\.went\\.com\\.pecker|com\\.went\\.NowTimeline' Package.swift project.yml Pecker PeckerTests Sources Tests Shared PeckerLiveActivity Pecker.xcodeproj || true
```

Expected: tests/builds succeed, generated project is clean, active old-identity scan has no matches.

- [ ] **Step 2: Create physical-device checklist note**

Create `docs/verification/live-activity-device-check.md`:

```markdown
# Pecker Live Activity Device Check

Date: 2026-06-24

Automated simulator verification has passed. Physical-device verification is
still required because ActivityKit presentation and Dynamic Island behavior
cannot be fully proven in simulator-only CI.

## Device scenarios to verify

- First activation requires a user action.
- Lock Screen state appears.
- Compact, expanded, and minimal Dynamic Island states render.
- Countdown advances without reopening the app.
- Foreground refresh changes primary/next content.
- Pause ends the activity.
- Empty day ends the activity.
- Stale content is treated as stale by the system.

## Result

Pending physical-device verification.
```

- [ ] **Step 3: Commit final verification note**

```bash
git add docs/verification/live-activity-device-check.md
git commit -m "test: document Pecker Live Activity device check"
```

