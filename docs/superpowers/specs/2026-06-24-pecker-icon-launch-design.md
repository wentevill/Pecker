# Pecker Icon and Launch Screen Design

## Goal

Make the existing Pecker app icon concept real in the iOS project and show a matching branded launch screen before the app UI appears.

## Design

- Use `docs/visual-design/app-icon/pecker-app-icon-concept-v1.png` as the source artwork for the app icon, but remove the white border by replacing the near-white outer pixels with the icon’s dark navy visual field.
- Generate a complete iOS `AppIcon.appiconset` under `Pecker/Resources/Assets.xcassets`.
- Use a launch-only image set named `PeckerLaunchTimeline`, showing only a vertical glowing timeline with nodes and subtle scroll/motion cues.
- Do not show the bird mark or full app icon on the launch screen.
- Use a dark navy launch background color named `PeckerLaunchBackground`, matching the timeline/icon visual tone.
- Configure `UILaunchScreen` in `Pecker/Resources/Info.plist` with `UIImageName` and `UIColorName`, avoiding a storyboard unless the app later needs custom launch layout.
- Note: iOS launch screens are static snapshots, so the “scrolling timeline” is represented as a static in-motion timeline visual.

## Verification

- Regenerate the Xcode project with XcodeGen.
- Confirm generated project files do not drift unexpectedly.
- Build the Pecker app for the iOS simulator with code signing disabled.
