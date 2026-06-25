# Event Template Factory Design

## Goal

Replace direct keyword classification with a factory-based event template system that supports both local rule extraction and future external/AI structured recognition.

## Design Principles

- `TimelineKind` remains the lightweight category used by sorting, pinning, Live Activity, and existing UI.
- A new `TimelineEventTemplate` represents the semantic shape of an event. It can contain fields and display metadata that are unique to that event type.
- Templates are created by `EventTemplateFactory`, not directly by callers that only have raw strings.
- The factory has two creation modes:
  - Local rules: parse title/location/notes using tokens, phrases, and regex-style signals.
  - External payload: accept structured fields from a future AI or external recognizer and build the matching template.
- Templates are display-aware. A train ticket template is not a generic field list; it declares a train-ticket presentation so the UI can render it like a real ticket.

## Architecture

Core model additions:

- `ClassificationInput`: normalized input for raw local classification.
- `ExternalEventTemplatePayload`: structured external input for AI/external recognizers.
- `TimelineEventTemplate`: enum wrapper for concrete templates.
- `TrainTicketTemplate`: first complete concrete template.
- `EventTemplateFactory`: factory that creates templates from raw input or external payload.

`TimelineClassifier` becomes a compatibility facade over `EventTemplateFactory`: it still returns `TimelineKind`, so existing callers are stable.

`TimelineEngine` enriches unknown items by creating a template, then stores both `kind` and `template` on the resulting `TimelineItem`.

## UI First Scope

The first specialized presentation is `TrainTicketTemplateView` in the detail screen.

Train tickets display like ticket artifacts:

- route line: departure station → arrival station;
- train number as the central identity;
- time row with departure and arrival times;
- metadata chips for carriage, seat, check-in gate, passenger, and ticket/order number when available.

Today cards and Live Activity continue to use the stable `TimelineKind`/title/time summary for this phase. This keeps the user-facing timeline reliable while the specialized template system grows.

## Initial Train Template Fields

- `trainNumber`
- `departureStation`
- `arrivalStation`
- `departureTimeText`
- `arrivalTimeText`
- `carriageNumber`
- `seatNumber`
- `checkInGate`
- `passengerName`
- `ticketNumber`

All fields are optional except that a template must have enough identity to be useful. For this phase, a train ticket template can be created when the factory has a train number or at least a train-like route signal.

## Verification

- Unit tests cover local rule creation, external payload creation, classifier compatibility, engine enrichment, Codable round trips, and presentation descriptors.
- Existing classifier false-positive protections remain.
- Swift tests and Xcode simulator build must pass before completion.
