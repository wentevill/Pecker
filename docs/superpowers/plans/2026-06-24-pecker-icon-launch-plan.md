# Pecker Icon and Launch Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the approved Pecker app icon and a matching lightweight launch screen into the iOS project.

**Architecture:** The app will use a single asset catalog under `Pecker/Resources/Assets.xcassets`. `AppIcon.appiconset` provides all iOS app icon renditions, while `PeckerLaunchMark.imageset` and `PeckerLaunchBackground.colorset` are referenced by `UILaunchScreen` in the app plist.

**Tech Stack:** Xcode asset catalogs, iOS `UILaunchScreen` plist configuration, XcodeGen.

---

### Task 1: Add asset catalog resources

**Files:**
- Create: `Pecker/Resources/Assets.xcassets/Contents.json`
- Create: `Pecker/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: generated PNG files in `Pecker/Resources/Assets.xcassets/AppIcon.appiconset`
- Create: `Pecker/Resources/Assets.xcassets/PeckerLaunchMark.imageset/Contents.json`
- Create: generated PNG files in `Pecker/Resources/Assets.xcassets/PeckerLaunchMark.imageset`
- Create: `Pecker/Resources/Assets.xcassets/PeckerLaunchBackground.colorset/Contents.json`

- [ ] Generate icon PNG renditions from `docs/visual-design/app-icon/pecker-app-icon-concept-v1.png`.
- [ ] Add asset catalog metadata for `AppIcon`, `PeckerLaunchMark`, and `PeckerLaunchBackground`.
- [ ] Verify the asset catalog is picked up through the existing `Pecker/Resources` resource build phase.

### Task 2: Configure launch screen

**Files:**
- Modify: `Pecker/Resources/Info.plist`

- [ ] Replace the empty `UILaunchScreen` dictionary with `UIImageName = PeckerLaunchMark`, `UIColorName = PeckerLaunchBackground`, and `UIImageRespectsSafeAreaInsets = true`.
- [ ] Keep the existing app icon compiler setting `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

### Task 3: Verify project and build

**Files:**
- Modify if regenerated: `Pecker.xcodeproj/project.pbxproj`

- [ ] Run `xcodegen generate --spec project.yml`.
- [ ] Check the generated project diff.
- [ ] Run a simulator build with `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -project Pecker.xcodeproj -scheme Pecker -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`.
- [ ] Commit the completed asset and launch screen changes.
