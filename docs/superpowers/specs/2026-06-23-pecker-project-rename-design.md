# Pecker Project Rename Design

Date: 2026-06-23
Status: Ready for user review

## Goal

Rename the entire project identity from `NowTimeline` / `Now Timeline` to
`Pecker`, while retaining “Now Timeline” only as a product-feature description
where useful.

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
- Bundle identifier: `com.went.Pecker`
- Test bundle identifier: `com.went.PeckerTests`
- App Group: `group.com.went.pecker`
- Entitlements file: `Pecker/Resources/Pecker.entitlements`
- App entry type: `PeckerApp`

## Scope

The rename includes:

- XcodeGen configuration;
- generated Xcode project, targets, schemes, and package references;
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
`group.com.went.pecker`.

No migration from the old App Group is required because the app has not been
released. Existing local development settings and snapshots may be discarded.

## Generated Project

`project.yml` remains the source of truth.

The implementation must:

1. update `project.yml`;
2. generate `Pecker.xcodeproj`;
3. verify regeneration produces no diff;
4. remove `NowTimeline.xcodeproj`;
5. verify Xcode lists `Pecker`, `PeckerTests`, and `PeckerCore`;
6. ensure no generated project references the checkout directory name.

## Verification

The rename is complete when:

- a repository-wide scan finds no active code/config identity using
  `NowTimeline`, `Now Timeline`, `NowTimelineCore`, or
  `group.com.went.nowtimeline`;
- `swift test` passes for `PeckerCoreTests`;
- the `Pecker` simulator test suite passes;
- Debug and Release simulator builds succeed;
- XcodeGen regeneration is clean;
- `Pecker.xcodeproj` opens directly from the repository root;
- the simulator app displays `Pecker`;
- the Git worktree is clean.

