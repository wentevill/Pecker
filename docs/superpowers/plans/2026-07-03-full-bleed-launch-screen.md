# Pecker Full-Bleed Launch Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the approved cosmic-flow launch artwork fill the entire iPhone screen, allowing slight edge cropping instead of showing wide black margins.

**Architecture:** Replace the limited `UILaunchScreen` image dictionary with a static `LaunchScreen.storyboard`. A single image view is pinned to all four root-view edges, uses Aspect Fill, and clips overflow; the existing asset catalog image and edge-matched background color remain unchanged.

**Tech Stack:** UIKit launch storyboard, Xcode asset catalogs, Info.plist, `ibtool`, `xcodebuild`, iOS Simulator

---

### Task 1: Add the full-bleed launch storyboard

**Files:**
- Create: `Pecker/Resources/LaunchScreen.storyboard`
- Modify: `Pecker.xcodeproj/project.pbxproj`

- [x] Add a launch-only storyboard whose root background is `PeckerLaunchBackground`.
- [x] Add an image view using `PeckerLaunchTimeline`, `scaleAspectFill`, and clipping.
- [x] Pin the image view to the root view's top, bottom, leading, and trailing edges rather than the safe area.
- [x] Add the storyboard to the Pecker target's Resources build phase without changing unrelated project upgrade settings.

### Task 2: Switch the app to storyboard launch configuration

**Files:**
- Modify: `Pecker/Resources/Info.plist`

- [x] Remove the `UILaunchScreen` dictionary.
- [x] Add `UILaunchStoryboardName` with value `LaunchScreen`.
- [x] Run `plutil -lint Pecker/Resources/Info.plist`.

### Task 3: Compile and visually verify

**Files:**
- Modify: `docs/verification/launch-screen-cosmic-flow-compact.png`
- Create: `docs/verification/launch-screen-cosmic-flow-large.png`

- [x] Validate the storyboard with `ibtool`.
- [x] Build the Pecker simulator app with `xcodebuild`.
- [x] Uninstall, reinstall, and cold-launch on compact and large iPhone simulators to avoid cached launch snapshots.
- [x] Capture and inspect both launch frames, confirming edge-to-edge coverage, acceptable slight cropping, and a centered focal bird/time node.
- [x] Run `swift test` and the Xcode test suite.

### Task 4: Review and commit

- [x] Review the focused diff and preserve pre-existing unrelated project-file changes.
- [x] Commit only the storyboard, its precise project references, plist switch, verification screenshots, and this plan.
