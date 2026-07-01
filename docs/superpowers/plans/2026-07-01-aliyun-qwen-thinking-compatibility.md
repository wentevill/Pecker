# Aliyun Qwen Thinking Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Disable thinking for every Pecker recognition request sent to Alibaba Cloud Model Studio so forced function choices work with Qwen models.

**Architecture:** Keep the OpenAI-compatible request body unchanged for generic providers. Add a small URL-host capability check inside `OpenAIRecognitionProvider`, and conditionally attach Alibaba's `enable_thinking: false` extension to the shared request body used by all three recognition stages.

**Tech Stack:** Swift 6, Foundation URL parsing and JSON serialization, Swift Testing, iOS Simulator

---

### Task 1: Add Request Compatibility Regression Tests

**Files:**
- Modify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Write the failing Alibaba host test**

Add a request test using
`https://llm-example.cn-beijing.maas.aliyuncs.com/compatible-mode/v1`
and assert:

```swift
#expect(json["enable_thinking"] as? Bool == false)
```

- [ ] **Step 2: Preserve generic-provider compatibility**

Extend the existing custom-host test with:

```swift
#expect(json["enable_thinking"] == nil)
```

- [ ] **Step 3: Run the focused tests and verify RED**

Run:

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: the Alibaba host test fails because `enable_thinking` is absent,
while the generic-provider assertion passes.

### Task 2: Add Minimal Alibaba Capability Detection

**Files:**
- Modify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Test: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Add a parsed-host suffix helper**

Add a private computed property that parses `configuration.host`, lowercases
the URL host, and returns true for the exact domains or subdomains of:

```swift
maas.aliyuncs.com
dashscope.aliyuncs.com
```

The suffix check must require either exact equality or a preceding dot so an
unrelated host such as `notmaas.aliyuncs.com.example.org` does not match.

- [ ] **Step 2: Add the vendor request field**

In the shared `requestBody` function, add:

```swift
if usesAlibabaModelStudio {
    body["enable_thinking"] = false
}
```

This automatically covers classification, extraction, and verification.

- [ ] **Step 3: Run focused tests and verify GREEN**

Run:

```bash
swift test --filter OpenAIRecognitionProviderTests
```

Expected: all provider tests pass.

### Task 3: Remove Diagnostic Injection and Verify

**Files:**
- Restore: `Pecker/App/PeckerApp.swift`
- Verify: `Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift`
- Verify: `Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift`

- [ ] **Step 1: Remove temporary simulator diagnostic code**

Remove the Debug environment-variable injection, generated image, automatic
request task, logging, and the temporary UIKit import. Preserve all user
changes that existed before this diagnosis.

- [ ] **Step 2: Run package tests**

Run:

```bash
swift test
```

Expected: zero failures.

- [ ] **Step 3: Build the signed simulator app**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -quiet \
  -project Pecker.xcodeproj \
  -scheme Pecker \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=1940BD1A-9696-4896-8A9A-8C7620DB6A26' \
  build
```

Expected: exit status 0.

- [ ] **Step 4: Repeat the real Qwen simulator request**

Use a temporary Debug-only launch injection outside the final diff, launch the
signed app with the supplied Alibaba host, API key, and `qwen3.7-plus`, and
confirm no stage returns the thinking-mode `invalid_parameter_error`.

- [ ] **Step 5: Inspect the final diff**

Run:

```bash
git diff --check
git diff -- Sources/PeckerCore/Recognition/OpenAIRecognitionProvider.swift \
  Tests/PeckerCoreTests/OpenAIRecognitionProviderTests.swift \
  Pecker/App/PeckerApp.swift
```

Expected: only the provider implementation and regression tests remain;
`PeckerApp.swift` contains no diagnostic changes.
