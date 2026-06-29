# Recognition Function Calling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make classification, event-field entry, and final verification use mandatory typed LLM function calls instead of free-form JSON content.

**Architecture:** A focused function-contract model owns the nine JSON Schema tool definitions and maps function names to timeline kinds. `OpenAIRecognitionProvider` sends stage-specific tools, decodes exactly one returned call, normalizes its arguments into the existing string payload, and emits structured compatibility errors without content fallback.

**Tech Stack:** Swift 6, Foundation Codable and JSONSerialization, OpenAI-compatible Chat Completions tools, Swift Testing, XCTest.

---

## File Structure

- Create `Sources/PeckerCore/Recognition/RecognitionFunctionContract.swift` for function names, per-type properties, strict Chat Completions tool definitions, and function-to-kind mapping.
- Modify `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift` for stage-specific tool requests and function-call response decoding.
- Modify `Sources/PeckerCore/Recognition/RecognitionPipelineModels.swift` to align minimum-field aliases with function argument names.
- Modify `Pecker/Recognition/RecognizedEventValidator.swift` to parse the same canonical task and deadline date-time keys.
- Modify `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift` for request, response, compatibility, and content-rejection behavior.
- Create `Tests/PeckerCoreTests/RecognitionFunctionContractTests.swift` for all function schemas.
- Modify `PeckerTests/SystemEventRecognitionCoordinatorTests.swift` for task and train acceptance fixtures.
- Modify `Pecker.xcodeproj/project.pbxproj` so both new files participate in Xcode builds and tests.

### Task 1: Define Strict Function Contracts

**Files:**
- Create: `Sources/PeckerCore/Recognition/RecognitionFunctionContract.swift`
- Create: `Tests/PeckerCoreTests/RecognitionFunctionContractTests.swift`
- Modify: `Pecker.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing contract tests**

Add tests for classification and every field-entry function:

```swift
@Test func classificationContractUsesStrictKindEnum() {
    let contract = RecognitionFunctionContract.classifyEvent
    #expect(contract.name == "classify_event")
    #expect(contract.kind == nil)
    #expect(contract.requiredProperties == ["kind"])
    #expect(contract.toolDefinition.function.strict)
}

@Test(arguments: TimelineKind.allCases)
func everyKindHasDedicatedFieldFunction(_ kind: TimelineKind) {
    let contract = RecognitionFunctionContract.fieldContract(for: kind)
    #expect(contract.kind == kind)
    #expect(contract.name.hasPrefix("fill_"))
    #expect(contract.requiredProperties == Set(contract.properties.map(\.name)))
    #expect(contract.additionalProperties == false)
}
```

Assert train contains `departureDateTime`, task contains `dueDateTime`, deadline
contains `deadlineDateTime`, and every business property schema is either
`string` or nullable `string`.

- [ ] **Step 2: Run tests and verify RED**

```bash
swift test --filter RecognitionFunctionContractTests
```

Expected: compilation fails because `RecognitionFunctionContract` does not
exist.

- [ ] **Step 3: Implement typed contracts**

Define:

```swift
enum RecognitionFunctionContract: String, CaseIterable, Sendable {
    case classifyEvent = "classify_event"
    case fillMeeting = "fill_meeting_event"
    case fillTask = "fill_task_event"
    case fillFlight = "fill_flight_event"
    case fillTrain = "fill_train_event"
    case fillTravel = "fill_travel_event"
    case fillInterview = "fill_interview_event"
    case fillDeadline = "fill_deadline_event"
    case fillGeneric = "fill_generic_event"

    static func fieldContract(for kind: TimelineKind) -> Self
    var kind: TimelineKind?
    var properties: [RecognitionFunctionProperty]
    var toolDefinition: [String: Any]
}
```

`toolDefinition` uses the Chat Completions shape:

```json
{
  "type": "function",
  "function": {
    "name": "fill_task_event",
    "description": "...",
    "strict": true,
    "parameters": {
      "type": "object",
      "properties": {
        "title": {"type": ["string", "null"], "description": "..."},
        "dueDateTime": {"type": ["string", "null"], "description": "..."}
      },
      "required": ["title", "dueDateTime"],
      "additionalProperties": false
    }
  }
}
```

List every declared property in `required`; nullable types represent missing
optional or alternative values. Classification uses a non-null string enum.

- [ ] **Step 4: Add files to Xcode and verify GREEN**

Add the production source to `PeckerCore` and the test source to
`PeckerCoreTests`, then run:

```bash
swift test --filter RecognitionFunctionContractTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerCoreTests/RecognitionFunctionContractTests -quiet
```

Expected: all contract tests pass in both test runners.

- [ ] **Step 5: Commit**

```bash
git add Sources/PeckerCore/Recognition/RecognitionFunctionContract.swift Tests/PeckerCoreTests/RecognitionFunctionContractTests.swift Pecker.xcodeproj/project.pbxproj
git commit -m "feat: define recognition function contracts"
```

### Task 2: Send Mandatory Function Tools in All Three Stages

**Files:**
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Write failing request tests**

Use queued HTTP responses and inspect each recorded body:

```swift
let requests = await client.recordedRequests
let classification = try requestJSON(requests[0])
let extraction = try requestJSON(requests[1])
let verification = try requestJSON(requests[2])

#expect(classification["parallel_tool_calls"] as? Bool == false)
#expect(forcedFunctionName(in: classification) == "classify_event")
#expect(toolNames(in: extraction) == ["fill_task_event"])
#expect(forcedFunctionName(in: extraction) == "fill_task_event")
#expect(Set(toolNames(in: verification)) == Set(
    RecognitionFunctionContract.fieldContracts.map(\.name)
))
#expect(verification["tool_choice"] as? String == "required")
```

Assert every function uses `strict: true`, has
`additionalProperties: false`, and every stage still contains
`deviceNow`, `deviceTimeZone`, and `deviceUTCOffset`.

- [ ] **Step 2: Run the request test and verify RED**

```bash
swift test --filter openAIProviderSendsMandatoryFunctionToolsForEveryStage
```

Expected: request bodies have no `tools`, `tool_choice`, or
`parallel_tool_calls`.

- [ ] **Step 3: Extend the request builder**

Change the private request path to accept:

```swift
private enum FunctionChoice {
    case forced(RecognitionFunctionContract)
    case required
}

private func makeRequest(
    for input: RecognitionInput,
    systemPrompt: String,
    taskText: String,
    contracts: [RecognitionFunctionContract],
    choice: FunctionChoice
) throws -> URLRequest
```

Add:

```swift
body["tools"] = contracts.map(\.toolDefinition)
body["tool_choice"] = choice.jsonValue
body["parallel_tool_calls"] = false
```

Classification forces `classify_event`; extraction forces the classified
kind's single field function; verification exposes all eight field functions
with `tool_choice: "required"`.

- [ ] **Step 4: Run request tests and verify GREEN**

```bash
swift test --filter openAIProviderSendsMandatoryFunctionToolsForEveryStage
```

Expected: all stage request assertions pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift
git commit -m "feat: require functions in recognition requests"
```

### Task 3: Decode Exactly One Function Call Without Content Fallback

**Files:**
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Replace successful content fixtures with function calls**

Create helpers:

```swift
private func toolCallEnvelope(name: String, arguments: String) -> Data
private func legacyFunctionCallEnvelope(name: String, arguments: String) -> Data
```

Use a three-response success sequence:

```swift
[
  toolCallEnvelope(name: "classify_event", arguments: #"{"kind":"task"}"#),
  toolCallEnvelope(name: "fill_task_event", arguments: #"{"title":"巡逻仓库","dueDateTime":"2026-06-29T23:30:00+08:00"}"#),
  toolCallEnvelope(name: "fill_task_event", arguments: #"{"title":"巡逻仓库","dueDateTime":"2026-06-29T23:30:00+08:00"}"#)
]
```

Add tests that content-only JSON now fails with reason
`模型未调用要求的函数`, while a legacy single `message.function_call`
sequence succeeds.

- [ ] **Step 2: Add failing malformed-call tests**

Cover:

- no function call;
- two `tool_calls`;
- wrong function at classification;
- wrong function at extraction;
- malformed arguments;
- nested argument values.

Assert stage, concise reason, and technical details.

- [ ] **Step 3: Run response tests and verify RED**

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: current decoder still reads `message.content` and cannot decode
function calls.

- [ ] **Step 4: Decode calls from the response envelope**

Extend the Chat Completions message model:

```swift
struct FunctionCall: Decodable {
    let name: String
    let arguments: String
}

struct ToolCall: Decodable {
    let type: String
    let function: FunctionCall
}

let toolCalls: [ToolCall]?
let functionCall: FunctionCall?
```

Add:

```swift
private func requiredFunctionCall(
    from data: Data,
    stage: RecognitionPipelineStage,
    allowed: Set<RecognitionFunctionContract>
) throws -> FunctionCall
```

Prefer `tool_calls`; use legacy `function_call` only when `tool_calls` is
absent. Require exactly one call and an allowed function name. Never inspect
`message.content` for stage success.

For event arguments, parse the arguments object with `JSONSerialization`,
inject the kind derived from the function name, and decode
`ExternalEventTemplatePayload` so scalar normalization remains centralized.

- [ ] **Step 5: Run response tests and verify GREEN**

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: valid modern and legacy calls pass; missing, multiple, wrong,
malformed, nested, and content-only responses return exact structured errors.

- [ ] **Step 6: Commit**

```bash
git add Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift
git commit -m "feat: decode recognition function calls"
```

### Task 4: Align Canonical Time Fields and Unsupported-Function Errors

**Files:**
- Modify: `Sources/PeckerCore/Recognition/RecognitionPipelineModels.swift`
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Modify: `Pecker/Recognition/RecognizedEventValidator.swift`
- Modify: `Tests/PeckerCoreTests/RecognitionPipelineModelsTests.swift`
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`
- Modify: `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`

- [ ] **Step 1: Write failing task/deadline alias tests**

```swift
@Test func taskSchemaAcceptsCanonicalDueDateTime() {
    let missing = RecognitionKindSchema.schema(for: .task).missingFields(in: [
        "title": "巡逻仓库",
        "dueDateTime": "2026-06-29T23:30:00+08:00"
    ])
    #expect(missing.isEmpty)
}

@Test func deadlineSchemaAcceptsCanonicalDeadlineDateTime() {
    let missing = RecognitionKindSchema.schema(for: .deadline).missingFields(in: [
        "title": "提交报告",
        "deadlineDateTime": "2026-06-30T18:00:00+08:00"
    ])
    #expect(missing.isEmpty)
}
```

Add a coordinator fixture whose final task fields are title plus
`dueDateTime`; assert start date and non-all-day state.

- [ ] **Step 2: Verify alias tests RED**

```bash
swift test --filter 'taskSchemaAcceptsCanonicalDueDateTime|deadlineSchemaAcceptsCanonicalDeadlineDateTime'
```

Expected: both schemas report their date field missing.

- [ ] **Step 3: Align schema alternatives and parser**

Use type-specific date alternatives:

```swift
task: [["dueDateTime"], ["executionDateTime"], ["eventDate"]]
deadline: [["deadlineDateTime"], ["dueDateTime"], ["eventDate"]]
meeting/interview/travel/generic: [["startDateTime"], ["eventDate"]]
train/flight: [["departureDateTime"], ["startDateTime"], ["eventDate", "departureTime"]]
```

Extend the timing parser with `executionDateTime` while retaining existing
aliases.

- [ ] **Step 4: Write and verify unsupported function-call service errors**

Feed HTTP 400 bodies containing `tools are not supported` and
`function calling unsupported`. Assert:

```swift
#expect(failure.reason == "当前模型或服务不支持函数调用")
#expect(failure.stage == .classification)
```

Update `serviceFailure` to recognize unsupported tool/function phrases without
losing status, code, or provider message.

- [ ] **Step 5: Run focused tests and commit**

```bash
swift test --filter 'RecognitionPipelineModelsTests|OpenAIRecognitionProviderTests'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
-only-testing:PeckerTests/SystemEventRecognitionCoordinatorTests -quiet
git add Sources/PeckerCore/Recognition/RecognitionPipelineModels.swift Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift Pecker/Recognition/RecognizedEventValidator.swift Tests/PeckerCoreTests/RecognitionPipelineModelsTests.swift Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift PeckerTests/SystemEventRecognitionCoordinatorTests.swift
git commit -m "fix: align recognition function time fields"
```

Expected: all focused tests pass.

### Task 5: Acceptance and Full Verification

**Files:**
- Modify if coverage needs it:
  - `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`
  - `PeckerTests/SystemEventRecognitionCoordinatorTests.swift`

- [ ] **Step 1: Add final acceptance fixtures**

Test `今天晚上11点半巡逻仓库` with device context
`2026-06-29T20:00:00+08:00` and assert the final task call produces:

```swift
title == "巡逻仓库"
startDate == ISO8601DateFormatter().date(
    from: "2026-06-29T23:30:00+08:00"
)
isAllDay == false
```

Retain C5788 train coverage and verify its numeric source price remains the
string `"96"`.

- [ ] **Step 2: Run all core tests**

```bash
swift test
```

Expected: zero failures.

- [ ] **Step 3: Run all iOS tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test -project Pecker.xcodeproj -scheme Pecker \
-destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: zero failures.

- [ ] **Step 4: Build and inspect repository**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build -project Pecker.xcodeproj -scheme Pecker \
-destination 'generic/platform=iOS Simulator' -quiet
git diff --check
git status --short
```

Expected: build succeeds and only the pre-existing untracked `releases/`
directory remains.

- [ ] **Step 5: Commit final acceptance adjustments**

If Step 1 changed tests:

```bash
git add Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift PeckerTests/SystemEventRecognitionCoordinatorTests.swift
git commit -m "test: cover recognition function calling"
```
