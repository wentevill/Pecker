# Three-Stage Recognition Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recognize every supported event type through classification, tolerant extraction, and LLM verification, then show precise user-facing and technical failure reasons.

**Architecture:** `OpenAIRecognitionProvider` will orchestrate three typed model requests using a shared per-kind schema and immutable device-time context. A deterministic validator in the app layer will normalize timing, enforce only each kind's minimum fields, and preserve all-day semantics; the Today recognition card will render structured failures with expandable redacted diagnostics.

**Tech Stack:** Swift 6, Foundation networking and Codable, Swift Testing, XCTest, SwiftUI, Swift Package Manager, Xcode 26.

---

## File Structure

- Create `Sources/PeckerCore/Recognition/RecognitionPipelineModels.swift` for pipeline stages, structured failures, type schemas, prompt context, and redaction-safe diagnostic formatting.
- Modify `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift` to perform classification, extraction, and verification requests and preserve transport/service/decoding errors.
- Modify `Sources/PeckerCore/Recognition/RecognitionModels.swift` only for compatibility between the existing coarse error enum and the new structured failures.
- Modify `Sources/PeckerCore/Classification/EventTemplateFactory.swift` to accept verified generic/unknown payloads without weakening dedicated ticket templates.
- Create `Pecker/Recognition/RecognizedEventValidator.swift` for deterministic minimum-field and time validation.
- Modify `Pecker/Recognition/SystemEventRecognitionCoordinator.swift` to use the validator and carry all-day state into drafts and records.
- Modify `Sources/PeckerCore/Storage/EventRepository.swift` to persist all-day state with backward-compatible decoding.
- Modify `Pecker/Features/Today/TodayScreenContent.swift` to model concise and technical recognition errors.
- Modify `Pecker/Features/Today/TodayView.swift` to map errors and render expandable technical details.
- Modify provider, factory, repository, coordinator, and presentation tests to exercise each boundary.

### Task 1: Define Pipeline Stages, Schemas, and Structured Failures

**Files:**
- Create: `Sources/PeckerCore/Recognition/RecognitionPipelineModels.swift`
- Test: `Tests/PeckerCoreTests/RecognitionPipelineModelsTests.swift`

- [ ] **Step 1: Write failing schema and diagnostic tests**

Add tests that establish the public behavior:

```swift
@Test func trainSchemaRequiresOnlyMinimumUsableFields() {
    let schema = RecognitionKindSchema.schema(for: .train)
    let fields = [
        "trainNumber": "G123",
        "departureStation": "上海虹桥站",
        "arrivalStation": "北京南站",
        "startDateTime": "2026-07-03T08:00:00+08:00"
    ]

    #expect(schema.missingFields(in: fields).isEmpty)
}

@Test func unknownSchemaAcceptsGenericContentAndDate() {
    let schema = RecognitionKindSchema.schema(for: .unknown)
    #expect(schema.missingFields(in: [
        "title": "社区活动",
        "eventDate": "2026-07-03"
    ]).isEmpty)
}

@Test func failureTechnicalDetailsNeverExposeSecrets() {
    let failure = RecognitionPipelineFailure(
        stage: .verification,
        reason: "服务返回错误",
        technicalSummary: "Authorization: Bearer sk-secret image=data:image/jpeg;base64,AAAA",
        httpStatus: 401,
        serviceCode: "invalid_api_key",
        serviceMessage: "bad key",
        missingFields: [],
        responseExcerpt: nil
    )

    #expect(!failure.technicalDetails.contains("sk-secret"))
    #expect(!failure.technicalDetails.contains("base64,AAAA"))
    #expect(failure.technicalDetails.contains("HTTP 401"))
}
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
swift test --filter RecognitionPipelineModelsTests
```

Expected: compilation fails because the pipeline model types do not exist.

- [ ] **Step 3: Implement minimal pipeline models**

Define:

```swift
public enum RecognitionPipelineStage: String, Codable, Sendable, Equatable {
    case classification
    case extraction
    case verification
    case validation
}

public struct RecognitionPipelineFailure: Error, Sendable, Equatable {
    public let stage: RecognitionPipelineStage
    public let reason: String
    public let technicalSummary: String?
    public let httpStatus: Int?
    public let serviceCode: String?
    public let serviceMessage: String?
    public let missingFields: [String]
    public let responseExcerpt: String?

    public var technicalDetails: String {
        var lines = ["阶段：\(stage.rawValue)"]
        if let httpStatus { lines.append("HTTP \(httpStatus)") }
        if let serviceCode { lines.append("错误码：\(serviceCode)") }
        if let serviceMessage { lines.append("服务信息：\(serviceMessage)") }
        if let technicalSummary { lines.append("详情：\(technicalSummary)") }
        if !missingFields.isEmpty {
            lines.append("缺少字段：\(missingFields.joined(separator: "、"))")
        }
        if let responseExcerpt { lines.append("响应：\(responseExcerpt)") }
        return Self.redact(lines.joined(separator: "\n"))
    }
}

public struct RecognitionKindSchema: Sendable, Equatable {
    public let kind: TimelineKind
    public let requiredFieldGroups: [[String]]
    public let optionalFields: [String]
    public let extractionGuidance: String

    public static func schema(for kind: TimelineKind) -> Self
    public func missingFields(in fields: [String: String]) -> [String]
}
```

Use alias groups for equivalent fields, for example flight departure may be
`departureAirport` or `departureAirportCode`. Define all eight schemas in one
switch. Train requires train number, both stations, and canonical start time.
Task, deadline, travel, and unknown accept `eventDate` when precise time is not
available. Optional lists include all fields approved in the design.

Redaction replaces bearer tokens, `sk-` tokens, and data-URL image payloads,
limits response excerpts to 800 characters, and never stores full requests.

- [ ] **Step 4: Run model tests and verify GREEN**

Run:

```bash
swift test --filter RecognitionPipelineModelsTests
```

Expected: all pipeline model tests pass.

- [ ] **Step 5: Commit the pipeline contract**

```bash
git add Sources/PeckerCore/Recognition/RecognitionPipelineModels.swift Tests/PeckerCoreTests/RecognitionPipelineModelsTests.swift
git commit -m "feat: define recognition pipeline contract"
```

### Task 2: Orchestrate Three LLM Requests with Device Time Context

**Files:**
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Write failing three-stage and time-context tests**

Replace the single-response stub with a queued client that records every
request. Add a successful test with:

1. `{"kind":"train"}`;
2. an incomplete train payload;
3. a corrected train payload containing the minimum fields.

Assert:

```swift
#expect(await client.recordedRequests.count == 3)
#expect(result.payload.fields["trainNumber"] == "G123")
#expect(result.payload.fields["seatNumber"] == nil)

let bodies = try await client.requestBodies()
#expect(bodies[0].contains("classification"))
#expect(bodies[1].contains("上海虹桥站"))
#expect(bodies[2].contains("verification"))
#expect(bodies.allSatisfy { $0.contains("Asia/Shanghai") })
#expect(bodies.allSatisfy { $0.contains("+08:00") })
#expect(bodies.allSatisfy { $0.contains("2026-07-03T09:30:00+08:00") })
```

Also assert Stage 1 `unknown` proceeds through extraction and verification and
returns a generic payload with title and date.

- [ ] **Step 2: Run provider tests and verify RED**

Run:

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: request count is one and stage-specific prompt assertions fail.

- [ ] **Step 3: Implement stage-specific requests**

Refactor the provider into focused private methods:

```swift
private func classify(_ input: RecognitionInput,
                      context: RecognitionPromptContext) async throws -> TimelineKind

private func extract(_ input: RecognitionInput,
                     kind: TimelineKind,
                     context: RecognitionPromptContext) async throws -> ExternalEventTemplatePayload

private func verify(_ input: RecognitionInput,
                    candidate: ExternalEventTemplatePayload,
                    context: RecognitionPromptContext) async throws -> ExternalEventTemplatePayload
```

`recognize(_:)` captures one `RecognitionPromptContext` from
`input.referenceDate` and `input.timeZoneIdentifier`, then calls all three in
order. Serialize prompts as explicit checklists:

```text
Tasks:
- [ ] Inspect the image and choose exactly one supported kind.
- [ ] Return only the required JSON object.
```

Extraction uses the selected schema and says to omit absent optional values,
not invent them, and keep notes compact. Verification receives the candidate
JSON, checks image agreement, chronology and time zone, may correct the kind,
and returns only the final payload.

Format `deviceNow` in the supplied IANA time zone with an explicit UTC offset,
and include `deviceTimeZone` and `deviceUTCOffset` in every user prompt.

- [ ] **Step 4: Run provider tests and verify GREEN**

Run:

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: the existing envelope variants and all three-stage tests pass.

- [ ] **Step 5: Commit orchestration**

```bash
git add Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift
git commit -m "feat: add three-stage recognition requests"
```

### Task 3: Preserve Real Transport, Service, and Decoding Failures

**Files:**
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Modify: `Sources/PeckerCore/Recognition/RecognitionModels.swift`
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Write failing error-preservation tests**

Add tests for:

- `URLError(.timedOut)` at extraction;
- HTTP 401 with `{"error":{"message":"Incorrect API key","code":"invalid_api_key"}}`;
- HTTP 429 with a top-level message and code;
- unsupported image input;
- malformed Stage 3 JSON with a bounded response excerpt.

Assert exact structured properties:

```swift
do {
    _ = try await provider.recognize(input)
    Issue.record("Expected structured failure")
} catch let failure as RecognitionPipelineFailure {
    #expect(failure.stage == .verification)
    #expect(failure.httpStatus == 429)
    #expect(failure.serviceMessage == "Too many requests")
    #expect(failure.technicalDetails.contains("HTTP 429"))
}
```

- [ ] **Step 2: Run error tests and verify RED**

Run:

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: failures are still collapsed into `requestFailed`,
`invalidResponse`, or raw `URLError`.

- [ ] **Step 3: Implement one error mapper at the HTTP boundary**

Introduce a private service envelope decoder that accepts both:

```json
{"error":{"message":"Incorrect API key","code":"invalid_api_key"}}
```

and:

```json
{"message":"Too many requests","code":"rate_limit"}
```

Wrap each HTTP call with its pipeline stage. Map network errors to concise
Chinese reasons using `URLError.Code`, preserve the localized technical
description, and preserve HTTP status/code/message. Continue mapping the known
image incompatibility response to the dedicated user reason.

Change payload decoders to throw `RecognitionPipelineFailure` with the current
stage and a redacted, bounded response excerpt. Keep `RecognitionError` cases
for source compatibility outside this provider, but do not use them to erase
provider diagnostics.

- [ ] **Step 4: Run provider error tests and verify GREEN**

Run:

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: all service, network, image-support, and decoding details survive.

- [ ] **Step 5: Commit error preservation**

```bash
git add Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift Sources/PeckerCore/Recognition/RecognitionModels.swift Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift
git commit -m "feat: preserve recognition failure details"
```

### Task 4: Validate Minimum Fields and Normalize Device-Zone Timing

**Files:**
- Create: `Pecker/Recognition/RecognizedEventValidator.swift`
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`

- [ ] **Step 1: Write failing validation tests for every kind**

Test a table of minimum valid payloads:

```swift
let fixtures: [ExternalEventTemplatePayload] = [
    .init(kind: .train, fields: [
        "trainNumber": "G123",
        "departureStation": "上海虹桥站",
        "arrivalStation": "北京南站",
        "startDateTime": "2026-07-03T08:00:00+08:00"
    ]),
    .init(kind: .flight, fields: [
        "flightNumber": "MU5101",
        "departureAirportCode": "SHA",
        "arrivalAirportCode": "PEK",
        "startDateTime": "2026-07-03T09:00:00+08:00"
    ]),
    .init(kind: .meeting, fields: [
        "title": "设计评审",
        "startDateTime": "2026-07-03T10:00:00+08:00"
    ]),
    .init(kind: .interview, fields: [
        "title": "产品面试",
        "startDateTime": "2026-07-03T11:00:00+08:00"
    ]),
    .init(kind: .task, fields: ["title": "提交材料", "eventDate": "2026-07-03"]),
    .init(kind: .deadline, fields: ["title": "报名截止", "eventDate": "2026-07-03"]),
    .init(kind: .travel, fields: ["destination": "苏州", "eventDate": "2026-07-03"]),
    .init(kind: .unknown, fields: ["title": "社区活动", "eventDate": "2026-07-03"])
]
```

Assert every fixture validates with no optional fields. Assert train missing
`trainNumber` returns a `.validation` failure whose missing fields contain
`车次`. Assert an overnight arrival earlier than departure rolls to the next
day only when no explicit arrival date is present.

- [ ] **Step 2: Run coordinator tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests -quiet
```

Expected: validation types are missing and date-only fixtures fail timing.

- [ ] **Step 3: Implement the deterministic validator**

Create:

```swift
struct RecognizedEventValidation: Equatable {
    let payload: ExternalEventTemplatePayload
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
}

struct RecognizedEventValidator {
    let calendar: Calendar

    func validate(
        _ payload: ExternalEventTemplatePayload
    ) throws -> RecognizedEventValidation
}
```

First call `RecognitionKindSchema.missingFields(in:)`. Convert missing aliases
to concise Chinese display names. Then parse:

- `startDateTime`, `departureDateTime`, or `deadlineDateTime`;
- otherwise `eventDate` plus optional start/departure time;
- otherwise a date-only all-day event at the calendar's start of day.

Parse explicit ISO-8601 offsets as authoritative. Use the injected calendar
time zone for local date/time pairs. Validate that explicit end time is after
start; preserve the current implicit overnight rollover behavior.

Move the private `RecognizedEventTiming` behavior into this validator and
remove the old generic `invalidResponse` throws.

- [ ] **Step 4: Integrate the validator in image recognition**

In `SystemEventRecognitionCoordinator.recognizeImage`, validate the verified
payload before building the template:

```swift
let validation = try validator.validate(result.payload)
guard let template = templateFactory.makeTemplate(from: validation.payload) else {
    throw RecognitionPipelineFailure(
        stage: .validation,
        reason: "未识别到可保存的事件内容",
        technicalSummary: "模板工厂无法从核对后的字段构建事件",
        httpStatus: nil,
        serviceCode: nil,
        serviceMessage: nil,
        missingFields: [],
        responseExcerpt: nil
    )
}
```

Add `isAllDay` to `ImageRecognitionDraft`.

- [ ] **Step 5: Run coordinator tests and verify GREEN**

Run the same targeted Xcode command.

Expected: all coordinator validation and existing coordinator tests pass.

- [ ] **Step 6: Commit validation**

```bash
git add Pecker/Recognition/RecognizedEventValidator.swift Pecker/Recognition/SystemEventRecognitionCoordinator.swift PeckerTests/SystemEventRecognitionCoordinatorTests.swift
git commit -m "feat: validate tolerant recognition results"
```

### Task 5: Persist All-Day Results and Build Generic Unknown Templates

**Files:**
- Modify: `Sources/PeckerCore/Storage/EventRepository.swift`
- Modify: `Sources/PeckerCore/Classification/EventTemplateFactory.swift`
- Modify: `Pecker/Recognition/SystemEventRecognitionCoordinator.swift`
- Modify: `Tests/PeckerCoreTests/EventRepositoryTests.swift`
- Modify: `Tests/PeckerCoreTests/EventTemplateFactoryTests.swift`
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`

- [ ] **Step 1: Write failing persistence and generic-template tests**

Add a repository migration test proving an old record without `isAllDay`
decodes as `false`, and a round-trip test proving a new all-day record remains
`true`.

Add:

```swift
@Test func unknownPayloadWithContentBuildsGenericTemplate() {
    let fields = [
        "title": "社区活动",
        "eventDate": "2026-07-03",
        "location": "文化中心",
        "notes": "携带报名二维码"
    ]
    #expect(EventTemplateFactory().makeTemplate(
        from: .init(kind: .unknown, fields: fields)
    ) == .generic(.init(
        kind: .unknown,
        title: "社区活动",
        location: "文化中心",
        notes: "携带报名二维码",
        fields: fields
    )))
}
```

Coordinator tests assert a date-only draft saves and returns a timeline item
with `isAllDay == true`.

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
swift test --filter EventRepositoryTests
swift test --filter EventTemplateFactoryTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests -quiet
```

Expected: `StoredEventRecord` does not persist all-day state and coordinator
items are always timed.

- [ ] **Step 3: Add backward-compatible all-day persistence**

Add `isAllDay: Bool` to `StoredEventRecord`, default it to `false` in the
memberwise initializer, and write a custom `Decodable` initializer using:

```swift
isAllDay = try container.decodeIfPresent(
    Bool.self,
    forKey: .isAllDay
) ?? false
```

Carry `ImageRecognitionDraft.isAllDay` through save and
`timelineItem(from:now:)`. Existing call sites continue compiling through the
default initializer argument.

- [ ] **Step 4: Keep unknown content in the generic factory**

Ensure `.unknown` uses `makeGenericTemplate(from:)`. Permit `destination` as
the title fallback for travel and unknown only:

```swift
let title = payload.value(for: "title", "eventTitle", "事件标题")
    ?? payload.value(for: "destination", "目的地")
```

Do not generate a title from OCR provenance or arbitrary response text.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run all three focused commands from Step 2.

Expected: old data decodes, new all-day state round-trips, and generic unknown
events reach the timeline.

- [ ] **Step 6: Commit persistence and template changes**

```bash
git add Sources/PeckerCore/Storage/EventRepository.swift Sources/PeckerCore/Classification/EventTemplateFactory.swift Pecker/Recognition/SystemEventRecognitionCoordinator.swift Tests/PeckerCoreTests/EventRepositoryTests.swift Tests/PeckerCoreTests/EventTemplateFactoryTests.swift PeckerTests/SystemEventRecognitionCoordinatorTests.swift
git commit -m "feat: save tolerant generic recognition results"
```

### Task 6: Show Concise Failures with Expandable Technical Details

**Files:**
- Modify: `Pecker/Features/Today/TodayScreenContent.swift`
- Modify: `Pecker/Features/Today/TodayView.swift`
- Modify: `PeckerTests/TodayPresentationTests.swift`

- [ ] **Step 1: Write failing recognition presentation tests**

Introduce a presentation value with `reason` and optional `technicalDetails`.
Test:

```swift
let issue = RecognitionIssuePresentation(
    reason: "服务返回 429：请求过于频繁",
    technicalDetails: "阶段：核对\nHTTP 429\n错误码：rate_limit"
)
let actions = try XCTUnwrap(TodayScreenContent.recognitionActions(
    settings: enabledSettings,
    phase: .failure(issue)
))

XCTAssertEqual(actions.errorText, issue.reason)
XCTAssertEqual(actions.errorTechnicalDetails, issue.technicalDetails)
```

Also assert generic non-provider errors have a useful localized technical
description, while structured failures use their exact stage and service
details.

- [ ] **Step 2: Run presentation tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerTests/TodayPresentationTests -quiet
```

Expected: failure state accepts only a string and has no technical details.

- [ ] **Step 3: Implement structured UI presentation**

Define:

```swift
struct RecognitionIssuePresentation: Equatable {
    let reason: String
    let technicalDetails: String?
}
```

Change `.failure(String)` to `.failure(RecognitionIssuePresentation)` and add
`errorTechnicalDetails` to `RecognitionActions`.

Replace `errorMessage(for:)` with a mapper that:

- passes through `RecognitionPipelineFailure.reason`;
- uses `RecognitionPipelineFailure.technicalDetails`;
- retains the existing friendly mappings for legacy `RecognitionError`;
- includes `error.localizedDescription` as technical details for other errors.

- [ ] **Step 4: Render the disclosure control**

Under the concise error text, render technical details only when non-empty:

```swift
DisclosureGroup("技术详情") {
    Text(details)
        .font(.caption.monospaced())
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
}
```

Keep the card compact while collapsed. Add accessibility labels that identify
the concise error and the expandable diagnostics.

- [ ] **Step 5: Run presentation tests and verify GREEN**

Run the targeted command from Step 2.

Expected: all presentation mappings pass.

- [ ] **Step 6: Commit UI failure details**

```bash
git add Pecker/Features/Today/TodayScreenContent.swift Pecker/Features/Today/TodayView.swift PeckerTests/TodayPresentationTests.swift
git commit -m "feat: show detailed recognition failures"
```

### Task 7: Verify the Complete Pipeline and Regression Surface

**Files:**
- Modify when required by failing integration coverage:
  - `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`
  - `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`
  - `PeckerTests/TodayPresentationTests.swift`

- [ ] **Step 1: Add a Chinese standard train-ticket integration fixture**

Use three queued model responses for a ticket containing:

- C5770;
- 重庆北站 to 成都东站;
- 2026-07-03 10:30 in `Asia/Shanghai`;
- only a subset of optional seat/ticket fields.

Assert the final draft has the exact train route and start instant and succeeds
without absent optional fields. Add a companion fixture where Stage 2 omits
the train number and Stage 3 repairs it.

- [ ] **Step 2: Run the integration fixture**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests -quiet
```

Expected: all standard-ticket and correction fixtures pass.

- [ ] **Step 3: Run all Swift package tests**

Run:

```bash
swift test
```

Expected: all PeckerCore tests pass with zero failures.

- [ ] **Step 4: Run all iOS app tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: all Pecker app tests pass with zero failures.

- [ ] **Step 5: Build the complete app**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build -project Pecker.xcodeproj -scheme Pecker \
-destination 'generic/platform=iOS Simulator' -quiet
```

Expected: build exits successfully.

- [ ] **Step 6: Check repository hygiene and commit final test adjustments**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; only intentional feature files plus the
pre-existing untracked `releases/` directory are present.

If Step 1 required test changes after the preceding commits:

```bash
git add Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift PeckerTests/SystemEventRecognitionCoordinatorTests.swift PeckerTests/TodayPresentationTests.swift
git commit -m "test: cover complete recognition pipeline"
```
