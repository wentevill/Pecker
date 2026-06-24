# Pecker Icon and Launch Screen Design

## Goal

Make the existing Pecker app icon concept real in the iOS project and show a matching branded launch screen before the app UI appears.

## Design

- Use `docs/visual-design/app-icon/pecker-app-icon-concept-v1.png` as the source artwork.
- Generate a complete iOS `AppIcon.appiconset` under `Pecker/Resources/Assets.xcassets`.
- Reuse the same mark for the launch screen through an image set named `PeckerLaunchMark`.
- Use a dark navy launch background color named `PeckerLaunchBackground`, matching the icon’s visual tone.
- Configure `UILaunchScreen` in `Pecker/Resources/Info.plist` with `UIImageName` and `UIColorName`, avoiding a storyboard unless the app later needs custom launch layout.

## Verification

- Regenerate the Xcode project with XcodeGen.
- Confirm generated project files do not drift unexpectedly.
- Build the Pecker app for the iOS simulator with code signing disabled.
