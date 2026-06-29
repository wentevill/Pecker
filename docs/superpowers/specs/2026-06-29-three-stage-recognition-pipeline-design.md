# Three-Stage Event Recognition Pipeline Design

**Date:** 2026-06-29  
**Status:** Approved

## Goal

Make image recognition accurate and tolerant across every supported event type,
with Chinese standard train tickets as the primary acceptance case.

Recognition must:

1. classify the basic event type;
2. extract as many relevant fields as the image supports;
3. use a final LLM pass to verify and correct the structured result;
4. accept a result as soon as its type-specific minimum fields are present;
5. show a concise user-facing failure reason with expandable technical details.

Missing optional fields must never make an otherwise usable result fail.

## Supported Types

The pipeline covers:

- meeting;
- task;
- flight;
- train;
- travel;
- interview;
- deadline;
- unknown.

`unknown` remains a useful classification. When it has meaningful content and
time information, it produces the generic event template instead of failing.

## Architecture

The recognition provider performs three independent model requests. Each
request receives the source image and only the structured context required for
that stage. Model reasoning is neither requested nor passed between stages.

### Stage 1: Type classification

The first request returns only one supported kind. It does not extract event
fields.

An `unknown` result does not stop the pipeline. Stage 2 still attempts to
extract a generic event.

### Stage 2: Type-specific extraction

The second request receives:

- the image;
- the Stage 1 kind;
- the field schema for that kind;
- the device time context;
- an explicit task checklist.

It extracts every clearly visible or directly implied useful field. It must
not invent missing values. Required and optional fields are both requested,
but missing optional values are omitted.

### Stage 3: Verification and correction

The third request receives:

- the image;
- the Stage 1 kind;
- the Stage 2 structured payload;
- the same type schema and device time context;
- an explicit verification checklist.

It checks the event kind, field accuracy, date interpretation, time zone,
chronology, and internal consistency. It returns a corrected, normalized
payload rather than a prose critique.

Stage 3 may change the kind when the image contradicts Stage 1. The corrected
kind determines final validation.

### Local validation

After Stage 3, deterministic local validation checks only the minimum success
requirements for the corrected kind. Optional field absence is accepted.

The local validator reports the exact missing or invalid fields. It does not
collapse validation failures into a generic response-format error.

## Device Time Context

Every model request includes fresh values captured from the device:

- `deviceNow`: ISO-8601 date and time with an explicit UTC offset;
- `deviceTimeZone`: IANA identifier, such as `Asia/Shanghai`;
- `deviceUTCOffset`: the current offset, such as `+08:00`.

The prompts require relative expressions such as 今天, 明天, 周五, and 今晚 to
be resolved from this context. The model must not assume a time zone.

Date-only task, deadline, travel, and generic events are represented as
all-day events in the device time zone. No precise time is invented.

## Type Schemas and Minimum Success Requirements

### Train

Minimum:

- train number;
- departure station;
- arrival station;
- departure date and time.

Optional fields include arrival date/time, carriage, seat, check-in gate,
passenger name, ticket/order number, seat class, and price.

The prompt explicitly describes Chinese railway ticket conventions, including
车次, 发站/到站, 开车时间, 车厢, 座位, 检票口, 席别, 票价, passenger, and ticket or
order identifiers. Station suffixes are preserved when visible.

### Flight

Minimum:

- flight number;
- departure location;
- arrival location;
- departure date and time.

Optional fields include carrier, airport codes, arrival time, terminal, gate,
seat, booking reference, passenger, cabin, and status.

### Meeting

Minimum:

- title;
- start date and time.

Optional fields include end time, location, participants, organizer, meeting
link, agenda, and useful notes.

### Interview

Minimum:

- title;
- start date and time.

Optional fields include end time, company, role, interviewer, location,
meeting link, contact, and preparation notes visible in the source.

### Task

Minimum:

- title;
- due or execution date.

A date without a time is accepted as all-day. Optional fields include precise
time, location, priority, assignee, project, and useful instructions.

### Deadline

Minimum:

- title;
- deadline date.

A date without a time is accepted as all-day. Optional fields include precise
time, owner, project, submission channel, and useful requirements.

### Travel

Minimum:

- a meaningful title or destination;
- start date.

A date without a time is accepted as all-day. Optional fields include end
time, origin, destination, booking reference, accommodation, transport,
address, and useful itinerary details.

### Unknown / generic

Minimum:

- meaningful content from which a concise title can be formed;
- a date or date and time.

A date without a time is accepted as all-day. Optional fields include
location and concise useful notes. If meaningful content or all time
information is absent, recognition fails.

## Content Quality

The final payload must be compact and user-facing:

- titles state the event itself;
- notes contain only useful preparation, instruction, or itinerary content;
- duplicate facts already represented by structured fields are omitted from
  notes;
- OCR provenance, recognition evidence, confidence commentary, model
  reasoning, and unrelated visible text are excluded;
- source text is preserved where accuracy matters, while dates and times use
  the canonical structured representation.

## Error Model and Presentation

Recognition failures use a structured error value containing:

- pipeline stage;
- user-facing reason;
- technical summary;
- HTTP status when available;
- service error code and message when available;
- underlying network error code and description when available;
- missing or invalid field names for local validation;
- a bounded response excerpt when decoding fails.

The recognition card shows the concise reason by default. A disclosure control
reveals technical details.

Examples:

- 网络连接超时;
- 模型不支持图片输入;
- 服务返回 429：请求过于频繁;
- 核对后仍缺少：车次、出发时间;
- 图片中未发现可形成事件的内容或时间.

Secrets and bulky or sensitive diagnostic data are never shown. This includes
API keys, authorization headers, image Base64 data, full prompts, and model
reasoning.

Request-level failures such as networking, authentication, rate limiting, and
image incompatibility stop immediately. An incomplete Stage 2 payload proceeds
to Stage 3. Recognition fails for content quality only after Stage 3 and local
validation have both had a chance to produce a usable event.

## Data Flow

1. The UI supplies image data, source metadata, device date, and device
   calendar time zone.
2. The coordinator creates one immutable recognition context.
3. The provider runs classification, extraction, and verification.
4. The provider returns the verified structured payload or a structured
   pipeline error.
5. The coordinator constructs the matching dedicated or generic template.
6. The local validator parses canonical timing and applies type-specific
   minimum requirements.
7. The existing confirmation card shows the draft, or shows a concise failure
   with expandable technical details.
8. Saving remains an explicit user action.

## Testing

Provider tests cover:

- the three requests and their stage-specific prompts;
- device time, IANA time zone, and UTC offset injection;
- all supported kind schemas;
- Stage 3 correction of Stage 1 or Stage 2 mistakes;
- server error body preservation;
- authentication, rate-limit, unsupported-image, network, and decode errors;
- redaction and response-excerpt bounds.

Coordinator and validator tests cover:

- Chinese standard train ticket minimum fields;
- every supported dedicated and generic type;
- success with every optional field absent;
- exact missing-field failures;
- date-only all-day events;
- relative dates and cross-midnight events in the device time zone;
- corrected-kind validation;
- `unknown` payloads becoming generic events when content and time exist.

Presentation tests cover:

- concise failure copy;
- expandable technical details;
- hidden sensitive values;
- successful confirmation cards with compact notes and no recognition
  provenance.

## Out of Scope

- exposing model chain-of-thought;
- persisting failed images or recognition diagnostics;
- automatic retries that could multiply model cost without user intent;
- adding new timeline kinds beyond the existing eight;
- changing the explicit confirmation-before-save flow.
