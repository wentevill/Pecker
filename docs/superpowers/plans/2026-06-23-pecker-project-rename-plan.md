# Pecker Project Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atomically rename the app, Xcode project, Swift modules, source trees, tests, bundle identifiers, and App Group from NowTimeline to Pecker.

**Architecture:** `project.yml` is the authoritative XcodeGen definition, with `PeckerCore` modeled directly as an Xcode target. `Package.swift` remains for CLI SwiftPM tests. The filesystem and Swift module rename happened first, followed by identity/signing configuration and clean Xcode regeneration, then active documentation validation.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, XcodeGen, Xcode 26, XCTest.

---

## Existing user signing changes to preserve

Xcode has written local signing choices that must survive the rename:

```text
DEVELOPMENT_TEAM = LNQGSLWW24
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER = ""
```

The old generated `NowTimeline.xcodeproj` also contains Xcode-format upgrades.
It will be removed rather than hand-merged because `Pecker.xcodeproj` is
regenerated from `project.yml`.

The final canonical identifiers preserve installable signing configuration:

```text
com.wenttang.pecker
com.wenttang.PeckerTests
com.wenttang.PeckerCoreTests
group.com.wenttang.pecker
```

### Task 1: Rename the Swift package, source trees, modules, and tests

**Files:**
- Move: `NowTimeline/` → `Pecker/`
- Move: `NowTimelineTests/` → `PeckerTests/`
- Move: `Sources/NowTimelineCore/` → `Sources/PeckerCore/`
- Move: `Tests/NowTimelineCoreTests/` → `Tests/PeckerCoreTests/`
- Modify: `Package.swift`
- Modify: all Swift files importing or declaring old modules/types

- [ ] **Step 1: Record the pre-rename test baseline**

Run:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
xcodebuild test \
  -project NowTimeline.xcodeproj \
  -scheme NowTimeline \
  -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: 40 core tests and the complete app suite pass.

- [ ] **Step 2: Move the four source/test trees**

Use `git mv`:

```bash
git mv NowTimeline Pecker
git mv NowTimelineTests PeckerTests
git mv Sources/NowTimelineCore Sources/PeckerCore
git mv Tests/NowTimelineCoreTests Tests/PeckerCoreTests
git mv Pecker/Resources/NowTimeline.entitlements Pecker/Resources/Pecker.entitlements
```

- [ ] **Step 3: Rename the Swift package and module imports**

Update `Package.swift` to:

```swift
let package = Package(
    name: "Pecker",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [
        .library(name: "PeckerCore", targets: ["PeckerCore"])
    ],
    targets: [
        .target(name: "PeckerCore"),
        .testTarget(
            name: "PeckerCoreTests",
            dependencies: ["PeckerCore"]
        )
    ]
)
```

Replace active Swift module references:

```text
NowTimelineCore → PeckerCore
@testable import NowTimeline → @testable import Pecker
NowTimelineApp → PeckerApp
```

Keep feature-domain type names such as `TimelineItem`, `TimelineEngine`, and
`TodaySnapshot`; they describe behavior rather than project identity.

- [ ] **Step 4: Verify the core rename**

Run:

```bash
rm -rf .build
swift test
```

Expected: `PeckerCoreTests` pass with 40 tests and no
`NowTimelineCore` module.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Pecker PeckerTests Sources Tests
git commit -m "refactor: rename Swift modules to Pecker"
```

### Task 2: Rename and regenerate the Xcode project identity

**Files:**
- Modify: `project.yml`
- Modify: `Pecker/Resources/Info.plist`
- Modify: `Pecker/Resources/Pecker.entitlements`
- Modify: `Pecker/Persistence/AppGroup.swift`
- Modify: `Pecker/App/PeckerApp.swift`
- Delete: `NowTimeline.xcodeproj/`
- Create: `Pecker.xcodeproj/`

- [ ] **Step 1: Add a failing identity assertion**

Update `PeckerTests/SmokeTests.swift` before changing the implementation:

```swift
import XCTest
@testable import Pecker

final class SmokeTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertEqual(AppIdentity.displayName, "Pecker")
    }
}
```

Run:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild test \
  -project NowTimeline.xcodeproj \
  -scheme NowTimeline \
  -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL because the app identity still reports `Now Timeline`, or
because the old project no longer matches the renamed trees.

- [ ] **Step 2: Rewrite `project.yml` as the Pecker source of truth**

Final implementation:

```yaml
name: Pecker

targets:
  PeckerCore:
    type: library.static
    platform: iOS
    sources:
      - path: Sources/PeckerCore

  Pecker:
    type: application
    platform: iOS
    sources:
      - path: Pecker/App
      - path: Pecker/Design
      - path: Pecker/EventKit
      - path: Pecker/Features/Onboarding
      - path: Pecker/Features/Shared
      - path: Pecker/Features/Today
      - path: Pecker/Features/Detail
      - path: Pecker/Features/Settings
      - path: Pecker/Features/Timeline
      - path: Pecker/Persistence
      - path: Pecker/Resources
        buildPhase: resources
        excludes:
          - Info.plist
          - Pecker.entitlements
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.wenttang.pecker
        PRODUCT_NAME: Pecker
        GENERATE_INFOPLIST_FILE: NO
        INFOPLIST_FILE: Pecker/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: Pecker/Resources/Pecker.entitlements
        DEVELOPMENT_TEAM: LNQGSLWW24
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: Apple Development
        PROVISIONING_PROFILE_SPECIFIER: ""
    dependencies:
      - target: PeckerCore

  PeckerTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: PeckerTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.wenttang.PeckerTests
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: Pecker

  PeckerCoreTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: Tests/PeckerCoreTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.wenttang.PeckerCoreTests
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: PeckerCore

schemes:
  Pecker:
    shared: true
    build:
      targets:
        Pecker: all
        PeckerTests: [test]
        PeckerCoreTests: [test]
    test:
      targets:
        - PeckerTests
        - PeckerCoreTests
```

Retain the existing deployment target and Swift version settings.

- [ ] **Step 3: Update app and entitlement identity**

Set:

```swift
enum AppIdentity {
    static let displayName = "Pecker"
}

@main
struct PeckerApp: App {
    // Existing body and lifecycle behavior remain unchanged.
}

enum AppGroup {
    static let identifier = "group.com.wenttang.pecker"
}
```

Update `Info.plist`:

```text
CFBundleDisplayName = Pecker
Calendar permission copy begins with “Pecker”
Reminders permission copy begins with “Pecker”
```

Update `Pecker.entitlements`:

```xml
<string>group.com.wenttang.pecker</string>
```

Update configuration-error copy so it references the new App Group.

- [ ] **Step 4: Regenerate the project**

Run:

```bash
rm -rf NowTimeline.xcodeproj Pecker.xcodeproj
/opt/homebrew/bin/xcodegen generate --spec project.yml
test -d Pecker.xcodeproj
xcodebuild -list -project Pecker.xcodeproj
```

Expected:

```text
Targets: Pecker, PeckerCore, PeckerCoreTests, PeckerTests
Schemes: Pecker
```

- [ ] **Step 5: Run app tests and builds**

Run:

```bash
rm -rf /tmp/PeckerRenameDerived /tmp/PeckerRenameRelease
xcodebuild test \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' \
  -derivedDataPath /tmp/PeckerRenameDerived \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PeckerRenameRelease \
  CODE_SIGNING_ALLOWED=NO
```

Expected: the complete app and core Xcode test suite passes and Release build
succeeds. The final rename verification observed 125 tests in the `Pecker`
scheme.

- [ ] **Step 6: Commit**

```bash
git add project.yml Pecker PeckerTests Pecker.xcodeproj
git add -u NowTimeline.xcodeproj
git commit -m "refactor: rename Xcode app to Pecker"
```

### Task 3: Update active documentation and verify no mixed identity remains

**Files:**
- Modify: `docs/superpowers/plans/*.md`
- Modify: `docs/superpowers/specs/2026-06-23-pecker-project-rename-design.md`
- Modify: active README/index files that prescribe build commands

- [ ] **Step 1: Scan active code and configuration**

Run:

```bash
rg -n \
  'NowTimeline|Now Timeline|NowTimelineCore|NowTimelineTests|NowTimeline\.xcodeproj|group\.com\.went\.nowtimeline|group\.went\.com\.pecker|com\.went\.NowTimeline' \
  Package.swift project.yml Pecker PeckerTests Sources Tests Pecker.xcodeproj || true
```

Expected: no matches. Do not treat canonical current identifiers
`com.wenttang.pecker` or `group.com.wenttang.pecker` as forbidden.

- [ ] **Step 2: Update active technical documentation**

Update commands and canonical identifiers in plans/specs that engineers may
still execute. Keep historical product-design prose that intentionally calls
the feature “Now Timeline,” but add a note that the shipping app/project is
`Pecker`.

- [ ] **Step 3: Verify clean regeneration**

Run:

```bash
/opt/homebrew/bin/xcodegen generate --spec project.yml
git diff --exit-code -- Pecker.xcodeproj project.yml
```

Expected: no diff.

- [ ] **Step 4: Verify displayed app name**

Build and install the Debug simulator app, then inspect:

```bash
plutil -extract CFBundleDisplayName raw \
  /tmp/PeckerRenameDerived/Build/Products/Debug-iphonesimulator/Pecker.app/Info.plist
```

Expected:

```text
Pecker
```

- [ ] **Step 5: Run final verification**

Run:

```bash
swift test
xcodebuild test \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -destination 'platform=iOS Simulator,id=696A08C4-C7D3-4FBE-AEF8-B7EEE845BCB5' \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
git diff --check
git status --short
```

Expected: 40 CLI core tests pass, the full Xcode app and core suite passes
(125 tests observed in the final rename verification), Release build succeeds,
and only intentional in-flight work remains in the worktree.

- [ ] **Step 6: Commit**

```bash
git add docs
git commit -m "docs: update project identity to Pecker"
```
