# Recognition Function Calling Design

**Date:** 2026-06-29  
**Status:** Approved in conversation

## Goal

Replace free-form JSON recognition responses with mandatory LLM function calls
for classification, type-specific field extraction, and final verification.

The model performs structured data entry. Pecker reads function arguments,
normalizes them to its existing string field model, validates minimum usable
content, and still requires user confirmation before saving.

## Scope

Function calling covers all three recognition stages and all eight event
types:

- meeting;
- task;
- flight;
- train;
- travel;
- interview;
- deadline;
- unknown/generic.

There is no fallback to text JSON. A model or compatible API that cannot
perform the required function call produces an explicit compatibility error.

## Request Protocol

Requests continue using the OpenAI-compatible Chat Completions endpoint.
Every stage sends:

- `tools` containing the allowed function definitions;
- an explicit `tool_choice`;
- `parallel_tool_calls: false`;
- the source image or text;
- `deviceNow`, `deviceTimeZone`, and `deviceUTCOffset`;
- the stage-specific checklist.

Every function definition uses:

- `type: "function"`;
- a precise name and description;
- a JSON Schema parameters object;
- `strict: true`;
- `additionalProperties: false`.

All business values are strings. Optional values are represented as
`string | null` because strict schemas require every declared property to be
listed as required. Pecker removes nulls after decoding, leaving the existing
`[String: String]` representation.

## Stage 1: Classification

The request provides and forces exactly one function:

```text
classify_event(kind)
```

`kind` is an enum containing the eight supported raw values. Pecker rejects a
plain text response, a missing call, multiple calls, the wrong function name,
or invalid arguments.

## Stage 2: Type-Specific Field Entry

Pecker maps the classified kind to one function and forces that exact
function. Only that function is present in `tools`.

### `fill_train_event`

Minimum usable arguments:

- `trainNumber`;
- `departureStation`;
- `arrivalStation`;
- `departureDateTime`.

Optional nullable strings include `title`, `arrivalDateTime`,
`carriageNumber`, `seatNumber`, `checkInGate`, `passengerName`,
`ticketNumber`, `orderNumber`, `seatClass`, `price`, `ticketType`,
`purchaseTime`, `purchaseChannel`, `idCardLastDigits`, `location`, and
`notes`.

### `fill_flight_event`

Minimum usable arguments:

- `flightNumber`;
- a departure airport name or code;
- an arrival airport name or code;
- `departureDateTime`.

Optional nullable strings include carrier, airport names and codes,
`arrivalDateTime`, terminal, gate, seat, booking reference, passenger, cabin,
status, location, and notes.

### `fill_meeting_event`

Minimum usable arguments:

- `title`;
- `startDateTime`.

Optional nullable strings include end time, location, participants, organizer,
meeting link, agenda, and notes.

### `fill_interview_event`

Minimum usable arguments:

- `title`;
- `startDateTime`.

Optional nullable strings include end time, company, role, interviewer,
location, meeting link, contact, and notes.

### `fill_task_event`

Minimum usable arguments:

- `title`;
- at least one of `dueDateTime` or `eventDate`.

Optional nullable strings include location, priority, assignee, project, and
notes.

Example:

```text
今天晚上11点半巡逻仓库
```

must become a title such as `巡逻仓库` plus `dueDateTime` resolved from the
device date and time zone with an explicit UTC offset.

### `fill_deadline_event`

Minimum usable arguments:

- `title`;
- at least one of `deadlineDateTime` or `eventDate`.

Optional nullable strings include owner, project, submission channel,
location, and notes.

### `fill_travel_event`

Minimum usable arguments:

- `title` or `destination`;
- at least one of `startDateTime` or `eventDate`.

Optional nullable strings include end time, origin, destination, booking
reference, accommodation, transport, address, location, and notes.

### `fill_generic_event`

This function corresponds to `unknown`.

Minimum usable arguments:

- `title` or `destination`;
- at least one of `startDateTime` or `eventDate`.

Optional nullable strings include location and notes.

## Stage 3: Verification and Correction

The final request provides all eight field-entry functions and sets:

```json
{
  "tool_choice": "required",
  "parallel_tool_calls": false
}
```

The prompt includes the Stage 2 candidate and requires exactly one function
call. The model chooses the correct function, so it can repair a wrong Stage 1
classification. The selected function name determines the final kind.

The verifier checks the image or source text again, corrects field placement,
normalizes relative dates using device context, removes unsupported claims,
and keeps notes compact and user-facing.

## Response Decoding

For Chat Completions, Pecker reads:

```text
choices[0].message.tool_calls[0].function.name
choices[0].message.tool_calls[0].function.arguments
```

The arguments string is decoded against the selected local function contract.
Scalar values are normalized to strings as defense in depth, although strict
schemas request string values. Null values are omitted.

The compatibility decoder may recognize the legacy single
`message.function_call` envelope only when the API actually returned a
function call. It never parses `message.content` as a successful stage result.

Function calls are used as a structured output channel. Pecker does not
execute external side effects, send tool outputs back to the model, or save an
event as part of the call.

## Validation

The selected Stage 3 function maps to `TimelineKind` and canonical field
names. Local deterministic validation remains the final authority:

- train and flight require precise departure date-time;
- meeting and interview require precise start date-time;
- task accepts `dueDateTime` or a date-only `eventDate`;
- deadline accepts `deadlineDateTime` or a date-only `eventDate`;
- travel and generic accept a start date-time or date-only event;
- optional field absence does not fail recognition.

The schema requirement aliases and timing parser must use the same canonical
keys. This removes the current mismatch where the parser accepts
`dueDateTime`, but the task minimum-field check does not.

## Error Handling

Structured failures distinguish:

- the service rejected `tools` or function calling;
- the model returned no function call;
- the model called a function not allowed for that stage;
- the model returned multiple calls;
- function arguments were not valid JSON;
- arguments contained unsupported nested values;
- final local validation found missing minimum content.

No condition silently falls back to free-form JSON.

HTTP errors whose service message indicates unsupported tools, functions, or
tool choice map to:

```text
当前模型或服务不支持函数调用
```

Technical details retain the pipeline stage, HTTP status, provider code, and
redacted provider message. Missing/wrong/multiple call errors retain the
returned function names but never expose image data, API keys, or full prompts.

## Testing

Provider request tests verify:

- each stage sends `tools`, the intended `tool_choice`, strict schemas, and
  `parallel_tool_calls: false`;
- every request contains device time and time zone;
- Stage 2 forces the classified type's function;
- Stage 3 offers all eight functions and permits type correction.

Response tests verify:

- Chat Completions `tool_calls` decoding;
- legacy single `function_call` decoding;
- string, number, boolean, and null argument normalization;
- missing, wrong, multiple, and malformed calls;
- explicit unsupported-function-call service errors;
- content-only JSON is rejected.

Acceptance fixtures include:

- `今天晚上11点半巡逻仓库`, producing `fill_task_event` with a valid
  `dueDateTime`;
- C5788 成都东站 to 重庆西站 with numeric source price normalized into a string;
- all eight event functions with only their minimum usable arguments;
- verification changing the selected function and therefore the final type.

## Out of Scope

- executing external tools or actions;
- sending function results back for an additional fourth model turn;
- automatic fallback to content JSON;
- saving without the existing confirmation step;
- adding new timeline kinds.
