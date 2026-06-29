# Tolerant Recognition Scalars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent valid recognition payloads from failing when a model returns scalar field values as JSON numbers or booleans.

**Architecture:** Keep the public payload model string-based and add tolerant scalar normalization only in its custom `Decodable` boundary. Unsupported nested JSON remains a decoding error.

**Tech Stack:** Swift 6, Foundation Codable, Swift Testing, XCTest.

---

### Task 1: Reproduce Scalar Field Responses

**Files:**
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`
- Modify: `Tests/PeckerCoreTests/EventTemplateFactoryTests.swift`

- [ ] **Step 1: Add the failing payload tests**

Decode the reported train response and assert:

```swift
#expect(result.payload.fields["price"] == "96")
#expect(result.payload.fields["trainNumber"] == "C5788")
```

Add direct payload decoding coverage:

```swift
let payload = try JSONDecoder().decode(
    ExternalEventTemplatePayload.self,
    from: Data(#"{"kind":"task","fields":{"title":"巡检","count":2,"ratio":1.5,"urgent":true,"empty":null}}"#.utf8)
)
#expect(payload.fields["count"] == "2")
#expect(payload.fields["ratio"] == "1.5")
#expect(payload.fields["urgent"] == "true")
#expect(payload.fields["empty"] == nil)
```

- [ ] **Step 2: Verify RED**

Run:

```bash
swift test --filter 'OpenAIRecognitionProviderTests|EventTemplateFactoryTests'
```

Expected: decoding fails because `price`, `count`, `ratio`, and `urgent` are not
JSON strings.

### Task 2: Normalize JSON Scalars to Strings

**Files:**
- Modify: `Sources/PeckerCore/Classification/EventTemplateFactory.swift`
- Modify: `Tests/PeckerCoreTests/EventTemplateFactoryTests.swift`

- [ ] **Step 1: Add a private scalar decoder**

Use a private `RecognitionFieldScalar`:

```swift
private enum RecognitionFieldScalar: Decodable {
    case string(String)
    case integer(Int64)
    case decimal(Double)
    case boolean(Bool)
    case null
}
```

Its decoder tries `String`, `Bool`, `Int64`, and `Double` in that order after
checking `decodeNil()`. Its `stringValue` returns canonical lowercase booleans
and compact decimal text.

- [ ] **Step 2: Add custom payload decoding**

Decode `fields` as `[String: RecognitionFieldScalar]`, omit `.null`, and map
every remaining scalar to `String`. Keep the existing public initializer and
synthesized string-only encoding behavior.

- [ ] **Step 3: Verify GREEN**

Run:

```bash
swift test --filter 'OpenAIRecognitionProviderTests|EventTemplateFactoryTests'
```

Expected: all scalar and provider tests pass; nested arrays and objects still
throw `DecodingError`.

- [ ] **Step 4: Commit**

```bash
git add Sources/PeckerCore/Classification/EventTemplateFactory.swift Tests/PeckerCoreTests/EventTemplateFactoryTests.swift Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift
git commit -m "fix: tolerate scalar recognition fields"
```

### Task 3: Full Verification

**Files:** No production changes expected.

- [ ] **Step 1: Run core tests**

```bash
swift test
```

Expected: zero failures.

- [ ] **Step 2: Run iOS tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: zero failures.

- [ ] **Step 3: Build and check repository state**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build -project Pecker.xcodeproj -scheme Pecker \
-destination 'generic/platform=iOS Simulator' -quiet
git diff --check
git status --short
```

Expected: build succeeds; only the pre-existing untracked `releases/`
directory remains.
