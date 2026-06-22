# Now Timeline Live Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit Live Activity activation, deterministic lifecycle coordination, and approved Lock Screen and Dynamic Island presentations.

**Architecture:** App and Widget Extension share a small ActivityKit attributes file. A protocol-wrapped activity client lets `ActivityCoordinator` decisions be unit tested without creating real activities. The extension only renders supplied state and never accesses EventKit.

**Tech Stack:** ActivityKit, WidgetKit, SwiftUI, XCTest, XcodeGen, iOS 26.

---

## File map

```text
Shared/NowTimelineActivityAttributes.swift
NowTimeline/Activity/ActivityClient.swift
NowTimeline/Activity/ActivityCoordinator.swift
NowTimelineLiveActivity/NowTimelineLiveActivityBundle.swift
NowTimelineLiveActivity/NowTimelineLiveActivityWidget.swift
NowTimelineLiveActivity/LockScreenLiveActivityView.swift
NowTimelineLiveActivity/DynamicIslandLiveActivityView.swift
NowTimelineLiveActivity/Info.plist
NowTimelineLiveActivity/NowTimelineLiveActivity.entitlements
NowTimelineTests/ActivityCoordinatorTests.swift
```

### Task 1: Add the shared ActivityKit state and extension target

**Files:**
- Modify: `project.yml`
- Create: `Shared/NowTimelineActivityAttributes.swift`
- Create: `NowTimelineLiveActivity/NowTimelineLiveActivityBundle.swift`
- Create: `NowTimelineLiveActivity/Info.plist`
- Create: `NowTimelineLiveActivity/NowTimelineLiveActivity.entitlements`

- [ ] **Step 1: Add a compile reference before the type exists**

Reference `NowTimelineActivityAttributes.self` from an empty widget bundle and
add the Widget Extension target to `project.yml`.

- [ ] **Step 2: Generate and verify failure**

Run:

```bash
xcodegen generate
xcodebuild build -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: FAIL because the shared attributes type is missing.

- [ ] **Step 3: Define date-driven content state**

```swift
import ActivityKit
import Foundation

struct NowTimelineActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let nowTitle: String?
        let nowStartDate: Date?
        let nowEndDate: Date?
        let nextTitle: String?
        let nextStartDate: Date?
        let pinnedTitle: String?
        let pinnedStartDate: Date?
        let pinnedSubtitle: String?
        let generatedAt: Date
    }

    let localDayIdentifier: String
}
```

Add the shared file to both targets. Enable `NSSupportsLiveActivities` and the
same App Group entitlement.

- [ ] **Step 4: Build and commit**

Expected: BUILD SUCCEEDED.

```bash
git add project.yml Shared NowTimelineLiveActivity
git commit -m "build: add Live Activity extension"
```

### Task 2: Implement and test lifecycle decisions

**Files:**
- Create: `NowTimeline/Activity/ActivityClient.swift`
- Create: `NowTimeline/Activity/ActivityCoordinator.swift`
- Test: `NowTimelineTests/ActivityCoordinatorTests.swift`

- [ ] **Step 1: Write failing coordinator tests**

Use a fake client and test:

- disabled setting produces `.end`;
- explicit first activation produces `.start`;
- changed content produces `.update`;
- equal content produces `.none`;
- empty snapshot produces `.end`;
- Now, Next, and Pinned-only state mapping;
- stale date equals the next meaningful boundary or snapshot stale date,
  whichever comes first.

- [ ] **Step 2: Verify failure**

Run only `ActivityCoordinatorTests`; expected FAIL.

- [ ] **Step 3: Implement protocol and coordinator**

```swift
enum ActivityDecision: Equatable {
    case none
    case start(NowTimelineActivityAttributes.ContentState, Date)
    case update(NowTimelineActivityAttributes.ContentState, Date)
    case end
}

protocol ActivityClient: Sendable {
    func currentState() async -> NowTimelineActivityAttributes.ContentState?
    func apply(_ decision: ActivityDecision) async throws
}
```

`ActivityCoordinator.reconcile(snapshot:settings:now:)` maps identifiers back
to items, creates date-driven content, and delegates the decision to the
client. The real client uses `Activity.request`, `update`, and `end`.

- [ ] **Step 4: Run tests and commit**

```bash
git add NowTimeline/Activity NowTimelineTests/ActivityCoordinatorTests.swift
git commit -m "feat: coordinate Live Activity lifecycle"
```

### Task 3: Connect explicit activation and app refresh

**Files:**
- Modify: `NowTimeline/Features/Onboarding/OnboardingView.swift`
- Modify: `NowTimeline/Features/Settings/SettingsView.swift`
- Modify: `NowTimeline/Features/Today/TodayViewModel.swift`
- Modify: `NowTimeline/App/AppDependencies.swift`
- Test: `NowTimelineTests/TodayViewModelTests.swift`

- [ ] **Step 1: Add failing integration tests**

Verify:

- onboarding enable action sets `liveActivityEnabled` and reconciles;
- refresh reconciles after a new snapshot is saved;
- pause ends the current activity;
- resume starts when relevant content exists;
- authorization unavailable is shown without crashing.

- [ ] **Step 2: Verify failure**

Run the affected app tests; expected FAIL.

- [ ] **Step 3: Wire the coordinator**

Call reconciliation only after snapshot persistence succeeds. Expose status
`active`, `paused`, `unavailable`, or `needsActivation` to Settings. Keep
activation user-initiated; do not silently start before consent.

- [ ] **Step 4: Run tests and commit**

```bash
git add NowTimeline/Features NowTimeline/App NowTimelineTests
git commit -m "feat: manage Live Activity from app flow"
```

### Task 4: Build the Lock Screen presentation

**Files:**
- Create: `NowTimelineLiveActivity/LockScreenLiveActivityView.swift`
- Create: `NowTimelineLiveActivity/NowTimelineLiveActivityWidget.swift`

- [ ] **Step 1: Add previews for four fallback states**

Preview:

- Now + Next + Pinned;
- Now + Next;
- Next only;
- Pinned only.

- [ ] **Step 2: Verify build failure**

Run the extension build; expected FAIL because the Lock Screen view is missing.

- [ ] **Step 3: Implement the approved hierarchy**

Match `docs/visual-design/previews/05-live-activity.jpg`. Use:

- green Now label/title;
- `Text(timerInterval:pauseTime:countsDown:showsHours:)` for remaining time;
- progress based on start/end dates;
- blue Next row;
- one orange Pinned line when space permits;
- fallback promotion when Now is absent.

Use `activityBackgroundTint` and `activitySystemActionForegroundColor` with
accessible contrast.

- [ ] **Step 4: Build and commit**

```bash
git add NowTimelineLiveActivity
git commit -m "feat: render Lock Screen Live Activity"
```

### Task 5: Build Dynamic Island presentations

**Files:**
- Create: `NowTimelineLiveActivity/DynamicIslandLiveActivityView.swift`
- Modify: `NowTimelineLiveActivity/NowTimelineLiveActivityWidget.swift`

- [ ] **Step 1: Add compact, expanded, and minimal previews**

Include long titles and Next-only state.

- [ ] **Step 2: Verify build failure**

Expected: FAIL because Dynamic Island regions are missing.

- [ ] **Step 3: Implement regions**

Use:

- compact leading: semantic status dot + shortened Now title;
- compact trailing: timer minutes;
- expanded leading: Now;
- expanded trailing: remaining timer;
- expanded bottom: Next and progress;
- minimal: status dot or remaining timer.

When no meaningful title fits, retain status and countdown rather than opaque
abbreviations.

- [ ] **Step 4: Build all targets and commit**

```bash
xcodebuild build -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'generic/platform=iOS'
git add NowTimelineLiveActivity
git commit -m "feat: render Dynamic Island states"
```

### Task 6: Verify Live Activity on a physical device

- [ ] **Step 1: Run automated verification**

```bash
xcodebuild test -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild build -project NowTimeline.xcodeproj -scheme NowTimeline \
  -destination 'generic/platform=iOS'
```

Expected: all tests PASS and build succeeds.

- [ ] **Step 2: Exercise device scenarios**

On a Dynamic Island-capable iPhone running iOS 26, verify:

- first activation requires a user action;
- Lock Screen state appears;
- compact, expanded, and minimal states render;
- countdown advances without reopening the app;
- foreground refresh changes Now/Next;
- pause ends the activity;
- empty day ends the activity;
- stale content is visibly treated as stale by the system.

- [ ] **Step 3: Save evidence**

Create `docs/verification/live-activity-device-check.md` with OS/device,
scenario results, and screenshots.

- [ ] **Step 4: Commit**

```bash
git add docs/verification/live-activity-device-check.md
git commit -m "test: verify Live Activity on device"
```
