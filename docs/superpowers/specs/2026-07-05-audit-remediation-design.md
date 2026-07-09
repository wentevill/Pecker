# Pecker Audit Remediation Design

**Date:** 2026-07-05

**Status:** Approved

## Goal

Resolve audit item P1-2 (permission recovery), P1-4 (image-input reliability), all identified P2 defects, and the UI/UE issues without introducing an unrelated architectural rewrite.

## Delivery Strategy

The work is split into three independently buildable, testable, and revertible projects:

1. Permission recovery and settings state
2. Recognition image-input pipeline
3. Timeline consistency, data integrity, and UI/UE completion

They should be implemented in that order. Each project receives its own implementation plan and commit sequence.

## Project 1: Permission Recovery and Settings State

### Scope

- Allow users who skipped Calendar or Reminders permission during onboarding to request it later.
- Treat `.writeOnly` as unreadable and provide a route to system Settings.
- Refresh authorization state when Settings appears and when the app returns to the foreground.
- Prevent stale authorization badges while the Settings sheet remains open.
- Make source rows usable at accessibility Dynamic Type sizes.

### Architecture

`SettingsViewModel` owns mutable authorization state rather than an immutable constructor snapshot. It receives the existing `EventKitGatewayProtocol`, uses it both to read current authorization and request access, and exposes one source action derived from authorization:

- `.notDetermined`: request full access in app.
- `.denied`, `.restricted`, `.writeOnly`: open system Settings.
- `.fullAccess`: no permission action.

Source enablement remains a separate preference. Granting or denying permission never silently changes the Calendar or Reminders toggle.

### Data Flow

1. Settings appears or app becomes active.
2. `SettingsViewModel.refreshAuthorization()` reads EventKit authorization.
3. The source row renders status and the correct action.
4. For `.notDetermined`, the user selects “Allow Access.”
5. The model requests the appropriate permission, reads authorization again, and notifies the app to refresh its timeline.
6. For unreadable non-requestable states, the user selects “Open Settings.”

### Error Handling

Permission request failures retain the previous source preference and authorization state. The row presents a localized error and remains actionable. Opening system Settings is unavailable only if the system URL cannot be constructed.

### UI/UE

At regular sizes, source rows may remain horizontal. At accessibility Dynamic Type sizes, the descriptive content and controls stack vertically. Status text can wrap and is not encoded only through color.

### Testing

- `.notDetermined` invokes the correct EventKit request exactly once.
- Calendar and Reminders requests update authorization after completion.
- `.denied`, `.restricted`, and `.writeOnly` open system Settings.
- `.fullAccess` exposes no permission action.
- Returning active refreshes the status.
- Request failure is localized and does not mutate source enablement.
- Accessibility-size previews verify the stacked row layout.

## Project 2: Recognition Image-Input Pipeline

### Scope

- Stop inferring image format from `PhotosPickerItem.itemIdentifier`.
- Normalize imported and camera images before recognition.
- Correct orientation and bound pixel dimensions and encoded byte size.
- Send a MIME type that matches the encoded bytes.
- Reuse the normalized bytes for confirmation and persistence.
- Fail before network access when input is unreadable or remains oversized.

### Architecture

Add a focused `RecognitionImagePreprocessor` at the app boundary. It accepts raw `Data`, decodes it through ImageIO/UIKit, applies orientation, scales the longest edge to a fixed maximum, and emits `PreparedRecognitionImage`:

```swift
struct PreparedRecognitionImage: Sendable, Equatable {
    let data: Data
    let filename: String
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
}
```

The canonical output is JPEG with filename `recognition.jpg` and MIME type `image/jpeg`. A deterministic quality ladder reduces JPEG quality until the byte limit is met. The initial limits are:

- Longest edge: 2,048 pixels
- Maximum encoded size: 4 MiB
- JPEG quality attempts: 0.82, 0.72, 0.62

`RecognitionInput` carries explicit MIME type rather than deriving it from the filename. The recognized draft stores the prepared bytes and canonical filename, so the exact data sent to the provider is later persisted.

### Data Flow

1. Photo picker or camera supplies raw image content.
2. `RecognitionImagePreprocessor` decodes, orients, scales, and encodes it.
3. The provider receives prepared data plus explicit `image/jpeg`.
4. The three recognition stages reuse the same prepared data.
5. The confirmation draft retains that data.
6. Saving writes the prepared JPEG and its matching extension.

### Error Handling

The preprocessor returns typed errors for decode failure, encoding failure, and size-limit failure. These errors map to localized user-facing messages. Raw data and Base64 request bodies are never included in technical error details.

### Testing

- PNG, HEIC-compatible, and rotated fixture inputs become JPEG.
- Output dimensions never exceed 2,048 pixels.
- Output bytes stay at or below 4 MiB or return the size-limit error.
- MIME and filename always match encoded output.
- The provider uses explicit MIME type.
- Recognition and persistence receive identical prepared bytes.
- Invalid input fails without calling the provider.
- Camera and photo paths share the same preprocessing path.

## Project 3: Timeline Consistency, Data Integrity, and UI/UE Completion

### Scope

- Apply cached AI templates consistently in Today and Full Timeline.
- Define cleanup behavior for stale synchronized Calendar and Reminder records.
- Make local image-record deletion atomic from the user’s perspective.
- Make API-key replacement non-destructive and derive configured status from Keychain.
- Validate custom recognition hosts before persistence.
- Complete user-visible localization.
- Correct text contrast.
- Restore an explicit Full Timeline pin action and accurate accessibility semantics.
- Explain the one-year history/future query boundary.
- Align README requirements with the project configuration.

### Timeline Template Consistency

Expose cached recognized templates through `SystemEventRecognizing` as a read operation. `TimelineManagerModel.load` obtains cached templates concurrently with EventKit data and passes them through `EventKitMapper`, matching Today’s behavior. Local keyword classification is only a fallback when no cached template exists.

System synchronization tracks the identifiers observed for each enabled source. Successfully synchronized records absent from the source’s current authoritative interval are deleted only within that interval. Imported and camera image records are never affected by system-source cleanup.

### Atomic Local Deletion

Image deletion uses a reversible quarantine operation:

1. Move the image to an app-owned temporary trash path.
2. Delete the repository record.
3. Permanently remove the quarantined image.
4. If record deletion fails, restore the image.

Failure after both user-visible resources are gone is logged as cleanup debt rather than reported as “event deletion failed.”

### Keychain and Host Validation

Keychain replacement checks for an existing item and uses `SecItemUpdate`; it calls `SecItemAdd` only when no item exists. Settings derives configured state from an actual Keychain read when it appears, repairing the persisted display flag.

The host validator accepts an HTTPS base URL with a host and optional provider base path. It rejects embedded credentials, query, fragment, and paths ending in `/chat/completions`. Validation occurs before the setting is persisted and produces a localized inline error.

### Localization

Move all user-visible hard-coded strings into both localization tables, including:

- Host, Model, API Key, and Live Activity labels
- Permission and onboarding errors
- Recognition progress accessibility text
- Recognition pipeline user-facing failures
- Configuration failure text
- Timeline range explanation

Technical diagnostic summaries remain nonlocalized and are never used as the primary UI message.

### Contrast and Accessibility

Replace low-opacity semantic text colors with opaque colors that meet a 4.5:1 contrast ratio against both the card and page backgrounds at normal text sizes. `now` and `pinned` receive separate display-text colors where their decorative accent colors do not pass.

Full Timeline cards expose a visible pin/unpin button. Card activation opens details; pin activation only changes pin state. VoiceOver labels and traits describe those distinct actions. Hidden swipe-delete controls are excluded from accessibility until revealed, and cards expose a standard accessibility activation action.

### Timeline Range

Keep the existing one-year history and one-year future query limits to avoid unbounded EventKit work. Add localized explanatory copy to the Full Timeline empty state or footer so absence outside that window is not interpreted as data loss.

### Documentation

Update both README files to state the actual baseline:

- iOS 26+
- Swift 6+
- Xcode 26+

### Testing

- Today and Full Timeline render the same kind and template for a cached system event.
- Missing cached templates fall back to local classification.
- Cleanup never deletes image records or records outside the authoritative interval.
- Image-record deletion restores the image when repository deletion fails.
- Cleanup failure after successful deletion does not report the event as present.
- Keychain update failure preserves the previous key.
- Configured status reconciles with actual Keychain contents.
- Host validation covers accepted base paths and every rejected component.
- English and Simplified Chinese localization tables have identical key sets.
- No audited user-facing hard-coded strings remain.
- Semantic text colors meet 4.5:1 contrast in automated tests.
- Full Timeline pin action invokes the callback once and card activation remains independent.
- VoiceOver labels do not advertise unavailable actions.
- Timeline range copy is localized.

## Verification

Every implementation plan follows test-driven development and ends with:

```bash
swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Pecker.xcodeproj -scheme Pecker \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

When a simulator is already booted, manual acceptance covers:

- Permission recovery for Calendar and Reminders
- Return-from-Settings authorization refresh
- Photo and camera recognition
- English and Simplified Chinese
- Accessibility Dynamic Type
- VoiceOver card and pin actions
- Visual contrast on Today, Full Timeline, Detail, and Settings

## Non-Goals

- Redesigning the app’s visual direction
- Replacing EventKit or ActivityKit
- Changing the three-stage recognition contract
- Adding cloud synchronization
- Expanding the timeline beyond the documented one-year bounds
- Refactoring unrelated large SwiftUI files
