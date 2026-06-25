# Event Template Factory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a factory-based event template system with a train-ticket template, two creation modes, and train-ticket UI in the detail screen.

**Architecture:** Core owns structured templates and factory creation. `TimelineClassifier` remains a compatibility facade, while `TimelineEngine` attaches templates to enriched items. SwiftUI detail rendering switches on `TimelineEventTemplate` and shows a specialized train-ticket view when present.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, Codable models.

---

### Task 1: Core template model and factory tests

**Files:**
- Create: `Tests/PeckerCoreTests/EventTemplateFactoryTests.swift`
- Create: `Sources/PeckerCore/Classification/EventTemplateFactory.swift`
- Modify: `Sources/PeckerCore/Classification/TimelineClassifier.swift`

- [ ] Add tests for local train-ticket creation from raw strings.
- [ ] Add tests for external payload creation of a train ticket.
- [ ] Add tests for classifier compatibility and false-positive behavior.
- [ ] Implement `ClassificationInput`, `ExternalEventTemplatePayload`, `TimelineEventTemplate`, `TrainTicketTemplate`, and `EventTemplateFactory`.
- [ ] Make `TimelineClassifier.classify(...)` return the factory-created template kind, with reminder fallback to `.task`.

### Task 2: Attach templates to timeline items

**Files:**
- Modify: `Sources/PeckerCore/Models/TimelineItem.swift`
- Modify: `Sources/PeckerCore/Engine/TimelineEngine.swift`
- Modify: `Tests/PeckerCoreTests/ModelTests.swift`
- Modify: `Tests/PeckerCoreTests/TimelineEngineTests.swift`

- [ ] Add optional `template: TimelineEventTemplate?` to `TimelineItem` with a default value to preserve existing call sites.
- [ ] Add Codable round-trip coverage for a templated item.
- [ ] Add engine coverage that unknown train-like items become `.train` and receive `.trainTicket`.
- [ ] Clear travel templates when travel events are hidden and the item is downgraded to `.unknown`.

### Task 3: UI train-ticket presentation

**Files:**
- Modify: `Pecker/Features/Detail/ItemDetailView.swift`
- Modify: `PeckerTests/ItemDetailActionTests.swift` if needed for compile compatibility.

- [ ] Add `TrainTicketTemplateView`, rendered before the generic detail field card.
- [ ] Keep the generic detail rows for source, type, time, location, and notes so existing information remains visible.
- [ ] Add a preview item with a train-ticket template.
- [ ] Build with Xcode to verify SwiftUI compiles.

### Task 4: Full verification and commit

**Files:**
- All changed files.

- [ ] Run `swift test`.
- [ ] Run `xcodegen generate --spec project.yml`.
- [ ] Run iOS simulator build with code signing disabled.
- [ ] Commit the implementation.
