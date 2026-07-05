# Recognition Image-Input Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Normalize photo and camera inputs into bounded, correctly identified JPEG data before any recognition request or persistence.

**Architecture:** A dedicated `RecognitionImagePreprocessor` converts arbitrary supported image data to canonical JPEG output. `RecognitionInput` carries explicit MIME type, and `ImageRecognitionDraft` retains the prepared data and filename so network input and saved content cannot diverge.

**Tech Stack:** Swift 6, UIKit, ImageIO, UniformTypeIdentifiers, SwiftUI PhotosPicker, XCTest, Swift Testing

---

## File Map

- Create `Pecker/Recognition/RecognitionImagePreprocessor.swift`: decode, orient, scale, compress, and validate images.
- Modify `Pecker/Features/Today/TodayView.swift`: preprocess both photo and camera inputs.
- Modify `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`: carry canonical MIME and filename through drafts.
- Modify `Sources/PeckerCore/Recognition/RecognitionModels.swift`: add explicit image MIME type to `RecognitionInput`.
- Modify `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`: use explicit MIME.
- Modify `Pecker/Recognition/ImageRecognitionStore.swift`: persist the canonical extension.
- Modify localization tables: typed preprocessing failures.
- Create `PeckerTests/RecognitionImagePreprocessorTests.swift`: image normalization tests.
- Modify provider and coordinator tests for MIME/data consistency.

### Task 1: Define canonical prepared-image output

**Files:**
- Create: `Pecker/Recognition/RecognitionImagePreprocessor.swift`
- Create: `PeckerTests/RecognitionImagePreprocessorTests.swift`

- [ ] **Step 1: Write failing decode and dimension tests**

Create `PeckerTests/RecognitionImagePreprocessorTests.swift`:

```swift
import ImageIO
import UIKit
import XCTest
@testable import Pecker

final class RecognitionImagePreprocessorTests: XCTestCase {
    func testPNGBecomesBoundedJPEG() throws {
        let input = try XCTUnwrap(
            solidImage(size: CGSize(width: 4_000, height: 2_000))
                .pngData()
        )
        let output = try RecognitionImagePreprocessor().prepare(input)

        XCTAssertEqual(output.filename, "recognition.jpg")
        XCTAssertEqual(output.mimeType, "image/jpeg")
        XCTAssertLessThanOrEqual(max(output.pixelWidth, output.pixelHeight), 2_048)
        XCTAssertLessThanOrEqual(output.data.count, 4 * 1_024 * 1_024)
        XCTAssertEqual(output.data.prefix(3), Data([0xFF, 0xD8, 0xFF]))
    }

    func testUnreadableDataThrowsDecodeFailure() {
        XCTAssertThrowsError(
            try RecognitionImagePreprocessor().prepare(Data([1, 2, 3]))
        ) { error in
            XCTAssertEqual(
                error as? RecognitionImagePreparationError,
                .decodeFailed
            )
        }
    }

    private func solidImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
```

- [ ] **Step 2: Run tests and verify compilation failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/RecognitionImagePreprocessorTests
```

Expected: compilation fails because the preprocessor types do not exist.

- [ ] **Step 3: Implement the prepared-image types and processor**

Create:

```swift
import Foundation
import UIKit

struct PreparedRecognitionImage: Sendable, Equatable {
    let data: Data
    let filename: String
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
}

enum RecognitionImagePreparationError: Error, Equatable {
    case decodeFailed
    case encodeFailed
    case exceedsSizeLimit
}

struct RecognitionImagePreprocessor: Sendable {
    let maximumDimension: CGFloat
    let maximumByteCount: Int
    let qualityAttempts: [CGFloat]

    init(
        maximumDimension: CGFloat = 2_048,
        maximumByteCount: Int = 4 * 1_024 * 1_024,
        qualityAttempts: [CGFloat] = [0.82, 0.72, 0.62]
    ) {
        self.maximumDimension = maximumDimension
        self.maximumByteCount = maximumByteCount
        self.qualityAttempts = qualityAttempts
    }

    func prepare(_ data: Data) throws -> PreparedRecognitionImage {
        guard let decoded = UIImage(data: data),
              decoded.size.width > 0,
              decoded.size.height > 0
        else {
            throw RecognitionImagePreparationError.decodeFailed
        }

        let normalized = normalizedImage(decoded)
        for quality in qualityAttempts {
            guard let encoded = normalized.jpegData(
                compressionQuality: quality
            ) else {
                throw RecognitionImagePreparationError.encodeFailed
            }
            if encoded.count <= maximumByteCount {
                return PreparedRecognitionImage(
                    data: encoded,
                    filename: "recognition.jpg",
                    mimeType: "image/jpeg",
                    pixelWidth: Int(normalized.size.width.rounded()),
                    pixelHeight: Int(normalized.size.height.rounded())
                )
            }
        }
        throw RecognitionImagePreparationError.exceedsSizeLimit
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        let longestEdge = max(image.size.width, image.size.height)
        let scale = min(1, maximumDimension / longestEdge)
        let target = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format)
            .image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: target))
                image.draw(in: CGRect(origin: .zero, size: target))
            }
    }
}
```

`UIImage.draw(in:)` applies the source orientation, and renderer scale `1` makes output pixel dimensions deterministic.

- [ ] **Step 4: Run the preprocessor tests**

Run the Step 2 command.

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add Pecker/Recognition/RecognitionImagePreprocessor.swift PeckerTests/RecognitionImagePreprocessorTests.swift
git commit -m "feat: normalize recognition images"
```

### Task 2: Cover orientation and hard size limits

**Files:**
- Modify: `PeckerTests/RecognitionImagePreprocessorTests.swift`
- Modify: `Pecker/Recognition/RecognitionImagePreprocessor.swift`

- [ ] **Step 1: Add orientation and size-limit tests**

```swift
func testRotatedImageProducesOrientedDimensions() throws {
    let base = solidImage(size: CGSize(width: 1_200, height: 600))
    let rotated = try XCTUnwrap(
        UIImage(cgImage: try XCTUnwrap(base.cgImage), scale: 1, orientation: .right)
            .pngData()
    )

    let output = try RecognitionImagePreprocessor().prepare(rotated)

    XCTAssertEqual(output.pixelWidth, 600)
    XCTAssertEqual(output.pixelHeight, 1_200)
}

func testOutputThatCannotMeetLimitThrowsSizeError() {
    let input = solidImage(size: CGSize(width: 200, height: 200))
        .pngData()!
    let processor = RecognitionImagePreprocessor(
        maximumDimension: 200,
        maximumByteCount: 8,
        qualityAttempts: [0.1]
    )

    XCTAssertThrowsError(try processor.prepare(input)) { error in
        XCTAssertEqual(
            error as? RecognitionImagePreparationError,
            .exceedsSizeLimit
        )
    }
}

func testHEICBecomesJPEGWhenSimulatorSupportsHEIC() throws {
    let type = "public.heic" as CFString
    guard CGImageDestinationCopyTypeIdentifiers()
        .contains(where: { ($0 as? String) == "public.heic" })
    else {
        throw XCTSkip("HEIC encoding is unavailable on this runtime")
    }
    let input = try encodedImage(
        solidImage(size: CGSize(width: 640, height: 480)),
        type: type
    )

    let output = try RecognitionImagePreprocessor().prepare(input)

    XCTAssertEqual(output.mimeType, "image/jpeg")
    XCTAssertEqual(output.data.prefix(3), Data([0xFF, 0xD8, 0xFF]))
}

private func encodedImage(
    _ image: UIImage,
    type: CFString
) throws -> Data {
    let data = NSMutableData()
    let destination = try XCTUnwrap(
        CGImageDestinationCreateWithData(data, type, 1, nil)
    )
    CGImageDestinationAddImage(
        destination,
        try XCTUnwrap(image.cgImage),
        nil
    )
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
}
```

- [ ] **Step 2: Run and verify the orientation test**

Run the Task 1 Step 2 command.

Expected: the size test passes; if the orientation test fails, the decoded pixel orientation is not being preserved by the PNG fixture.

- [ ] **Step 3: Make the orientation fixture deterministic**

Replace the rotated fixture creation with this helper and call it from the test:

```swift
private func orientedJPEG(
    image: UIImage,
    orientation: CGImagePropertyOrientation
) throws -> Data {
    let data = NSMutableData()
    let destination = try XCTUnwrap(
        CGImageDestinationCreateWithData(
            data,
            "public.jpeg" as CFString,
            1,
            nil
        )
    )
    CGImageDestinationAddImage(
        destination,
        try XCTUnwrap(image.cgImage),
        [
            kCGImagePropertyOrientation: orientation.rawValue
        ] as CFDictionary
    )
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
}
```

Use:

```swift
let rotated = try orientedJPEG(image: base, orientation: .right)
```

- [ ] **Step 4: Run tests**

Expected: four preprocessor tests pass.

- [ ] **Step 5: Commit**

```bash
git add Pecker/Recognition/RecognitionImagePreprocessor.swift PeckerTests/RecognitionImagePreprocessorTests.swift
git commit -m "test: bound recognition image orientation and size"
```

### Task 3: Carry explicit MIME type through PeckerCore

**Files:**
- Modify: `Sources/PeckerCore/Recognition/RecognitionModels.swift`
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Modify: `Tests/PeckerCoreTests/RecognitionModelTests.swift`
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Add failing explicit-MIME tests**

In `RecognitionModelTests.swift`:

```swift
@Test func imageRecognitionInputCarriesExplicitMIMEType() {
    let input = RecognitionInput.importedImage(
        id: "image-1",
        imageData: Data([0xFF, 0xD8, 0xFF]),
        filename: "recognition.jpg",
        mimeType: "image/jpeg"
    )
    #expect(input.imageMIMEType == "image/jpeg")
}
```

In `OpenAIRecognitionProviderTests.swift`:

```swift
@Test func openAIProviderUsesExplicitImageMIMEType() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://example.com",
            apiKey: "key",
            model: "vision"
        )
    )
    let request = try provider.makeRequest(
        for: .importedImage(
            id: "image-1",
            imageData: Data([0xFF, 0xD8, 0xFF]),
            filename: "misleading.png",
            mimeType: "image/jpeg"
        )
    )
    let body = String(data: request.httpBody!, encoding: .utf8)!
    #expect(body.contains("data:image/jpeg;base64,/9j/"))
    #expect(!body.contains("data:image/png"))
}
```

- [ ] **Step 2: Verify Swift Package tests fail**

Run:

```bash
swift test --filter imageRecognitionInputCarriesExplicitMIMEType
swift test --filter openAIProviderUsesExplicitImageMIMEType
```

Expected: compilation fails because `mimeType` and `imageMIMEType` are absent.

- [ ] **Step 3: Extend `RecognitionInput`**

Add:

```swift
public let imageMIMEType: String?
```

Add this initializer parameter after `filename`:

```swift
imageMIMEType: String? = nil,
```

and assign:

```swift
self.imageMIMEType = imageMIMEType
```

Change the image factories to:

```swift
public static func importedImage(
    id: String,
    imageData: Data,
    filename: String?,
    mimeType: String = "image/jpeg",
    referenceDate: Date? = nil,
    timeZoneIdentifier: String? = nil
) -> RecognitionInput {
    RecognitionInput(
        id: "image:\(id)",
        source: .importedImage,
        sourceIdentifier: id,
        title: filename,
        location: nil,
        notes: nil,
        startDate: nil,
        endDate: nil,
        isAllDay: false,
        imageData: imageData,
        filename: filename,
        imageMIMEType: mimeType,
        referenceDate: referenceDate,
        timeZoneIdentifier: timeZoneIdentifier
    )
}

public static func cameraImage(
    id: String,
    imageData: Data,
    filename: String = "recognition.jpg",
    mimeType: String = "image/jpeg",
    referenceDate: Date? = nil,
    timeZoneIdentifier: String? = nil
) -> RecognitionInput {
    RecognitionInput(
        id: "camera:\(id)",
        source: .cameraImage,
        sourceIdentifier: id,
        title: nil,
        location: nil,
        notes: nil,
        startDate: nil,
        endDate: nil,
        isAllDay: false,
        imageData: imageData,
        filename: filename,
        imageMIMEType: mimeType,
        referenceDate: referenceDate,
        timeZoneIdentifier: timeZoneIdentifier
    )
}
```

- [ ] **Step 4: Make provider MIME selection explicit**

Replace:

```swift
"url": "data:\(mimeType(for: input.filename));base64,\(imageData.base64EncodedString())"
```

with:

```swift
let mimeType = input.imageMIMEType ?? "image/jpeg"
guard ["image/jpeg", "image/png", "image/webp"].contains(mimeType) else {
    throw RecognitionError.invalidConfiguration
}
content.append([
    "type": "image_url",
    "image_url": [
        "url": "data:\(mimeType);base64,\(imageData.base64EncodedString())"
    ]
])
```

Delete the filename-derived `mimeType(for:)` helper.

- [ ] **Step 5: Run PeckerCore tests**

```bash
swift test
```

Expected: 101 or more tests pass, with zero failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/PeckerCore/Recognition/RecognitionModels.swift Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift Tests/PeckerCoreTests/RecognitionModelTests.swift Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift
git commit -m "feat: carry explicit recognition image mime type"
```

### Task 4: Use prepared data for recognition and persistence

**Files:**
- Modify: `Pecker/Features/Today/TodayView.swift:5-248`
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift:36-230`
- Modify: `Pecker/Recognition/ImageRecognitionStore.swift:20-61`
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`
- Modify: `PeckerTests/TodayPresentationTests.swift`

- [ ] **Step 1: Add MIME and canonical-filename draft assertions**

Extend the existing image draft test:

```swift
#expect(draft.filename == "recognition.jpg")
#expect(draft.mimeType == "image/jpeg")
```

Construct it through:

```swift
let prepared = PreparedRecognitionImage(
    data: imageData,
    filename: "recognition.jpg",
    mimeType: "image/jpeg",
    pixelWidth: 1200,
    pixelHeight: 800
)
let draft = try await coordinator.recognizeImage(
    prepared,
    source: .importedImage,
    settings: settings,
    now: now
)
```

- [ ] **Step 2: Verify coordinator tests fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests
```

Expected: compilation fails because the prepared-image overload and draft MIME are absent.

- [ ] **Step 3: Change image-recognition APIs to prepared images**

Change `ImageRecognitionDraft`:

```swift
let mimeType: String
```

Change `ImageRecognizing`:

```swift
func recognizeImage(
    _ image: PreparedRecognitionImage,
    source: RecognitionSource,
    settings: TimelineSettings,
    now: Date
) async throws -> ImageRecognitionDraft
```

In `SystemEventRecognitionCoordinator`, accept the same arguments and create input with:

```swift
let input: RecognitionInput = source == .cameraImage
    ? .cameraImage(
        id: sourceIdentifier,
        imageData: image.data,
        filename: image.filename,
        mimeType: image.mimeType,
        referenceDate: now,
        timeZoneIdentifier: calendar.timeZone.identifier
    )
    : .importedImage(
        id: sourceIdentifier,
        imageData: image.data,
        filename: image.filename,
        mimeType: image.mimeType,
        referenceDate: now,
        timeZoneIdentifier: calendar.timeZone.identifier
    )
```

Populate the draft with:

```swift
filename: image.filename,
imageData: image.data,
mimeType: image.mimeType,
```

- [ ] **Step 4: Inject and use the preprocessor in `TodayView`**

Add:

```swift
let imagePreprocessor: RecognitionImagePreprocessor
```

Provide a default in the initializer:

```swift
imagePreprocessor: RecognitionImagePreprocessor = .init()
```

Change photo handling:

```swift
let prepared = try imagePreprocessor.prepare(data)
let draft = try await imageRecognizer.recognizeImage(
    prepared,
    source: .importedImage,
    settings: settingsStore.value,
    now: .now
)
```

Change camera handling:

```swift
guard let rawData = image.pngData() else {
    throw RecognitionImagePreparationError.encodeFailed
}
let prepared = try imagePreprocessor.prepare(rawData)
let draft = try await imageRecognizer.recognizeImage(
    prepared,
    source: .cameraImage,
    settings: settingsStore.value,
    now: .now
)
```

Remove use of `PhotosPickerItem.itemIdentifier` as a filename and remove the direct `jpegData(compressionQuality:)` path.

- [ ] **Step 5: Make persisted extension canonical**

Replace filename inference in `ImageRecognitionStore` with:

```swift
guard filename?.lowercased().hasSuffix(".jpg") == true else {
    throw ImageRecognitionStoreError.invalidImageReference
}
let relativePath =
    "Images/\(source.rawValue)-\(UUID().uuidString).jpg"
```

Delete `fileExtension(from:)`.

- [ ] **Step 6: Run coordinator and UI tests**

Run the Step 2 command and:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' \
-only-testing:PeckerTests/TodayPresentationTests
```

Expected: both suites pass.

- [ ] **Step 7: Commit**

```bash
git add Pecker/Features/Today/TodayView.swift Pecker/Recognition/SystemEventRecognitionCoordinator.swift Pecker/Recognition/ImageRecognitionStore.swift PeckerTests/SystemEventRecognitionCoordinatorTests.swift PeckerTests/TodayPresentationTests.swift
git commit -m "feat: share prepared recognition image data"
```

### Task 5: Localize preprocessing failures and verify

**Files:**
- Modify: `Pecker/Features/Today/TodayView.swift:296-330`
- Modify: `Pecker/Resources/en.lproj/Localizable.strings`
- Modify: `Pecker/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `PeckerTests/AppLocalizerTests.swift`

- [ ] **Step 1: Add failure mapping**

At the top of `issuePresentation(for:)`, add:

```swift
if let error = error as? RecognitionImagePreparationError {
    let key: String
    switch error {
    case .decodeFailed:
        key = "recognition.image.decodeFailed"
    case .encodeFailed:
        key = "recognition.image.encodeFailed"
    case .exceedsSizeLimit:
        key = "recognition.image.tooLarge"
    }
    return .init(
        reason: AppLocalizer(
            language: settingsStore.value.language
        ).string(key),
        technicalDetails: nil
    )
}
```

- [ ] **Step 2: Add English strings**

```text
"recognition.image.decodeFailed" = "This image could not be read.";
"recognition.image.encodeFailed" = "This image could not be prepared for recognition.";
"recognition.image.tooLarge" = "This image is too large to recognize.";
```

- [ ] **Step 3: Add Simplified Chinese strings**

```text
"recognition.image.decodeFailed" = "无法读取这张图片。";
"recognition.image.encodeFailed" = "无法处理这张图片用于识别。";
"recognition.image.tooLarge" = "图片过大，无法识别。";
```

- [ ] **Step 4: Add key-presence assertions**

Add:

```swift
func testRecognitionImageFailureCopyExistsInBothLanguages() {
    let english = AppLocalizer(language: .english)
    let chinese = AppLocalizer(language: .simplifiedChinese)
    let keys = [
        "recognition.image.decodeFailed",
        "recognition.image.encodeFailed",
        "recognition.image.tooLarge"
    ]

    for key in keys {
        XCTAssertNotEqual(english.string(key), key)
        XCTAssertNotEqual(chinese.string(key), key)
    }
}
```

- [ ] **Step 5: Run full verification**

```bash
swift test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
-configuration Debug -destination 'generic/platform=iOS Simulator' \
CODE_SIGNING_ALLOWED=NO build-for-testing
```

Expected: all PeckerCore tests pass and Xcode reports `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 6: Perform simulator acceptance**

1. Import a portrait HEIC photo and verify the preview/recognized record is upright.
2. Import a 12-megapixel PNG and verify recognition starts without a 413 response.
3. Capture a camera image and verify the same confirmation flow.
4. Test corrupted image data through the unit test and confirm no provider call.
5. Save an imported item and inspect the App Group file: extension and bytes are JPEG.

- [ ] **Step 7: Commit**

```bash
git add Pecker/Features/Today/TodayView.swift Pecker/Resources/en.lproj/Localizable.strings Pecker/Resources/zh-Hans.lproj/Localizable.strings PeckerTests/AppLocalizerTests.swift
git commit -m "fix: report recognition image preparation failures"
```
