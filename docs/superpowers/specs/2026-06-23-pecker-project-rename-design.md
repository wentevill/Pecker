# Pecker Project Rename Design

Date: 2026-06-23
Status: Implemented

## Goal

Rename the entire project identity from `NowTimeline` / `Now Timeline` to
`Pecker`, while retaining “Now Timeline” only as a product-feature description
where useful.

This design now reflects the final checked-in implementation.

## Canonical Names

- App display name: `Pecker`
- Xcode project: `Pecker.xcodeproj`
- App target and scheme: `Pecker`
- App Swift module: `Pecker`
- App source directory: `Pecker/`
- App test target and module: `PeckerTests`
- App test directory: `PeckerTests/`
- Swift package: `Pecker`
- Core library product and target: `PeckerCore`
- Core test target: `PeckerCoreTests`
- Core source directory: `Sources/PeckerCore/`
- Core test directory: `Tests/PeckerCoreTests/`
- Bundle identifier: `com.wenttang.pecker`
- App test bundle identifier: `com.wenttang.PeckerTests`
- Core test bundle identifier: `com.wenttang.PeckerCoreTests`
- App Group: `group.com.wenttang.pecker`
- Entitlements file: `Pecker/Resources/Pecker.entitlements`
- App entry type: `PeckerApp`
- Development team: `LNQGSLWW24`

## Scope

The rename includes:

- XcodeGen configuration;
- generated Xcode project, targets, and scheme;
- source and test directories;
- Swift package products and targets;
- Swift imports and `@testable import` statements;
- bundle identifiers and App Group constants/entitlements;
- Info.plist display name and permission copy;
- user-visible configuration-error copy;
- implementation plans and active technical references that prescribe the old
  identifiers.

The product design documents may continue to describe the core feature as
“Now Timeline.” Historical screenshots and prior Git commit messages are not
rewritten.

## Data Compatibility

The App Group changes from `group.com.went.nowtimeline` to
`group.com.wenttang.pecker`.

No migration from the old App Group is required because the app has not been
released. Existing local development settings and snapshots may be discarded.

## Generated Project

`project.yml` remains the source of truth for XcodeGen.

The implementation must:

1. update `project.yml`;
2. generate `Pecker.xcodeproj`;
3. verify regeneration produces no diff;
4. remove `NowTimeline.xcodeproj`;
5. model `PeckerCore` and `PeckerCoreTests` as native Xcode targets rather
   than as a local package dependency at path `.`;
6. retain `Package.swift` for CLI SwiftPM tests;
7. verify Xcode lists targets `Pecker`, `PeckerCore`, `PeckerCoreTests`, and
   `PeckerTests`, plus scheme `Pecker`;
8. ensure no generated project references the checkout directory name.

## Verification

The rename is complete when:

- an active code/config scan finds no old or mistyped identity using
  `NowTimeline`, `Now Timeline`, `NowTimelineCore`, `NowTimelineTests`,
  `NowTimeline.xcodeproj`, `group.com.went.nowtimeline`,
  `group.went.com.pecker`, or `com.went.NowTimeline`;
- verification scans do not treat canonical identifiers
  `com.wenttang.pecker` or `group.com.wenttang.pecker` as forbidden;
- `swift test` passes for `PeckerCoreTests`;
- the full `Pecker` Xcode test suite passes, including app and core tests
  (125 tests observed in the final rename verification);
- Debug and Release simulator builds succeed;
- XcodeGen regeneration is clean;
- `Pecker.xcodeproj` opens directly from the repository root;
- the simulator app displays `Pecker`;
- the Git worktree is clean.
