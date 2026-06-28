# Timeline Management, Strict Today, and Universal Live Activity Design

Date: 2026-06-28

## Summary

Pecker will use one consistent time model across the Today screen, the full
timeline manager, recognized cards, and Live Activity.

The Today screen must contain only items whose time range intersects the local
calendar day. The full timeline manager will organize every item into Today,
Future, or History and support type filtering. Pecker-owned records can be
edited and deleted; EventKit calendar events and reminders remain read-only.

Every supported card kind can participate in Live Activity. Train tickets are
the first image-recognition acceptance fixture, but Live Activity eligibility
must not be limited to train, flight, or travel cards.

The UI must preserve the approved warm visual direction already represented by
`TimelineTheme`. The original design images remain the source of truth for
timeline structure, card hierarchy, semantic accents, spacing, and
interaction. New screens must extend that system instead of introducing a
separate visual language.

## Goals

- Keep the Today screen strictly limited to the current local day.
- Correct the “今天还有 N 个日程” count and expose all remaining Today cards.
- Add an independent timeline manager for Today, Future, and History.
- Support time-scope and event-kind filtering.
- Allow local Pecker records to be edited and deleted.
- Save recognized travel images with their real start and end dates.
- Make every card kind eligible for Live Activity when it is temporally
  relevant.
- Preserve the original timeline composition with the approved warm palette.

## Non-goals

- Editing or deleting EventKit calendar events and reminders.
- Adding a separate “overdue” time scope.
- Treating completion state as a time scope.
- Syncing Pecker edits back into Calendar or Reminders.
- Building cloud sync or an external database.
- Redesigning the app with a new palette, card system, or navigation model.

## Current Problems and Root Causes

### Today count and card visibility

`TodayPresentation.summaryCount(for:)` currently derives the count from the
total item count minus the number of visible Now cards. This does not represent
all unfinished items remaining today and can count elapsed items.

`TodayScreenContent` renders only Now, Next, and Pinned cards. Other Today
items are represented only by the summary row, so users cannot see them on the
home screen without opening the full timeline.

### Other dates leaking into Today

The reminders query currently starts at an unbounded date and ends at the end
of Today. Old incomplete reminders therefore enter the Today input.

Recognized image records are loaded without a day filter. Their stored
`startDate` currently uses recognition time instead of the recognized event
time, so both classification and Live Activity can be wrong.

### Timeline management

`FullTimelineView` is tied to a `TodaySnapshot`. It cannot independently load
History or Future, filter by kind, or perform local record management.

The local repository can upsert records and delete records by recognition
source, but it cannot delete a single record by identifier.

### Visual consistency

The approved implementation uses a warm cream gradient, translucent warm
glass cards, a continuous left timeline, and green/blue/orange semantic
accents. The new manager and editor must reuse these tokens and the original
design's information hierarchy instead of creating a visually separate
surface.

## Time Model

### Local-day intervals

All scopes use `Calendar.current` and half-open intervals:

- Today: `[startOfToday, startOfTomorrow)`
- Future: items whose effective start is at or after `startOfTomorrow`
- History: items whose effective end is at or before `startOfToday`

An item intersects Today when:

```text
item.start < startOfTomorrow
and
effectiveEnd > startOfToday
```

`effectiveEnd` is the item end date when it is later than the start date.
Otherwise, the item is treated as a point-in-time item with a minimal positive
duration for interval classification.

Cross-midnight items that are still active during Today belong to Today.
Items must belong to exactly one of Today, Future, or History.

### No overdue scope

Pecker will not display “逾期” as a time scope. A reminder whose due date is in
the past belongs to History even when it is incomplete. Completion state may
be shown as metadata, but it does not move an item between scopes.

### Strict Today input

The home snapshot is built only from items that intersect Today:

- Calendar events are queried for the Today interval.
- Reminders are queried for the Today interval instead of using an unbounded
  lower bound.
- Local recognized records are classified by their saved start and end dates.

The classifier is shared by the home screen and timeline manager so the two
surfaces cannot disagree at day boundaries.

## Today Screen

### Remaining count

“今天还有 N 个日程” counts every unfinished Today item, including a currently
active item. It excludes elapsed items and completed reminders.

An item is unfinished when its effective end is after `now`. A point-in-time
item without an end is unfinished when its start is at or after `now`.

### Card presentation

The primary home hierarchy remains:

1. Now
2. Next
3. Pinned
4. Summary row

The summary row opens the new manager preselected to Today, where every Today
item is visible. This keeps the home screen glanceable without silently hiding
the rest of the day.

## Timeline Manager

### Architecture

The manager receives data from an independent model rather than a
`TodaySnapshot`.

It combines:

- EventKit calendar events for the requested date window.
- EventKit reminders for the requested date window.
- All locally stored Pecker records.

EventKit loading is paged by calendar month to avoid an unbounded query.
Opening the manager loads the month containing Today. Scrolling or requesting
more Future or History content loads adjacent months in the corresponding
direction. Local records can be loaded in one pass because they are stored in
Pecker's repository.

The model normalizes all sources into timeline items, applies the shared time
scope classifier, then applies the selected kind filter.

### Layout

The approved layout is:

- A segmented control for `今日 / 未来 / 历史`.
- A single-select horizontal kind filter:
  `全部 / 会议 / 任务 / 航班 / 火车 / 行程 / 面试 / 截止 / 未分类`.
- A chronological vertical timeline using the existing timeline-card
  hierarchy.

The selected kind remains active when switching time scopes. Within a scope,
items are sorted chronologically; History uses reverse chronological order so
the most recent item is first.

### Ownership and actions

EventKit items are read-only. Their detail screens do not show edit or delete
actions.

Pecker-owned image and external records support:

- Editing title, start date, end date, type, location, and notes.
- Editing template-specific fields, including train number, route, carriage,
  seat, and gate for a train ticket.
- Deleting a single record after confirmation.

Deleting a record also deletes its locally stored source image. If the deleted
record is manually pinned, the pin is cleared.

After edit or delete, Today, the manager, and Live Activity reconcile from the
same refreshed data.

## Recognition and Canonical Dates

### Provider result

Image recognition must return canonical event timing in addition to display
fields. The preferred representation is a full local date-time with time-zone
context for both start and end.

For travel that supplies a date and separate time strings, Pecker combines
them in the current local time zone. If the parsed arrival time is earlier
than the departure time and no explicit arrival date is present, arrival is
treated as the following day.

The confirmation card shows the parsed dates and times before Save. Missing or
invalid required timing blocks Save and shows a corrective error.

### Persistence

Saving a recognized image writes the canonical event start and end to
`StoredEventRecord.startDate` and `StoredEventRecord.endDate`. Recognition time
remains audit metadata and is never used as the event start time.

The saved timing becomes the source of truth for scope classification,
countdowns, progress, sorting, Today inclusion, and Live Activity.

### Train ticket acceptance fixture

The supplied test image must produce:

- Date: 2026-06-28
- Train: C5770
- Route: 成都东 → 重庆西
- Departure: 10:30
- Arrival: 11:48
- Carriage: 02
- Seat: 06D
- Gate: B3
- Class: 二等座 when represented by the recognition payload
- Price: ¥96 when represented by the recognition payload
- Order number: E123456789 when represented by the recognition payload

On 2026-06-28, this card appears in Today. Before departure it can be selected
as the next or pinned Live Activity item; from 10:30 through 11:48 it can be
the Now item with progress.

## Universal Live Activity

Live Activity eligibility is based on timing and Today membership, not card
kind. Calendar events, reminders, meetings, tasks, flights, trains, travel,
interviews, deadlines, unknown items, and future template kinds all use the
same selection pipeline.

The primary selection priority remains:

1. Now
2. Next
3. Unfinished Pinned

Every eligible item supplies the shared fields required by Live Activity:
title, subtitle, start, end, kind, source identifier, countdown target, and
progress when an end date exists.

The subtitle uses a type-aware presentation adapter:

- Train/travel: route, then carriage/seat/gate as space permits.
- Flight: airport/terminal/gate details.
- Meeting/interview: location or participant/context.
- Task/reminder/deadline: notes or due context.
- Unknown: first non-empty location or notes.

The adapter only changes presentation. It does not create kind-specific
eligibility rules.

Editing the active item updates Live Activity immediately. Deleting it causes
the coordinator to select the next eligible item or end the activity when none
remains.

## Visual Design Contract

### Sources of truth

Visual implementation is checked against:

1. `Pecker/Design/TimelineTheme.swift` for the approved warm palette and
   shared material tokens.
2. `demo.png` for timeline structure and card hierarchy.
3. `docs/visual-design/previews/03-home-design.jpg` for home composition.
4. `docs/visual-design/previews/04-supporting-screens.jpg` for supporting
   screen structure.
5. `docs/visual-design/previews/05-live-activity.jpg` for Live Activity
   information hierarchy.

### Required language

- Warm cream gradient based on the existing `TimelineTheme.backgroundGradient`.
- Translucent warm glass cards with a restrained border, highlight, and shadow.
- A continuous left-side timeline with illuminated nodes.
- Green for Now, blue for Next, and orange for Pinned or important travel.
- Dark warm primary text and progressively subdued secondary and tertiary text.
- Existing large continuous card radius and compact, glanceable information
  hierarchy.
- System typography and SF Symbols unless an existing approved asset is used.

The manager's segmented scope control and kind chips must look like extensions
of the existing glass controls. The editor uses the same background, card
material, spacing rhythm, and accent colors. It must not resemble a separate
generic form app.

Shared visual tokens should be corrected or extended in one place. New
hard-coded palettes in feature views are not allowed.

### Visual verification

Implementation acceptance includes simulator screenshots of:

- Today with Now, Next, Pinned, and the corrected summary.
- Timeline manager in Today, Future, and History scopes.
- A filtered timeline.
- Local record editor.
- The C5770 card in Today.
- Live Activity and relevant Dynamic Island families.

These screenshots are compared side by side with the approved references.
Functional correctness alone is not sufficient when the layout, palette,
timeline structure, or semantic colors visibly diverge.

## Error Handling

- Failed manager loads preserve the last successful content and show a retry
  action for the affected scope.
- Failed edits preserve the original persisted record and keep the editor
  open with an error.
- Failed deletes retain the card and source image.
- Failed image cleanup after a successful record deletion is reported and
  retried without resurrecting the deleted record.
- Invalid start/end ranges block Save.
- EventKit authorization failures show source-specific read-only states and do
  not hide successfully loaded local records.
- System items never expose destructive controls.

## Testing and Acceptance

### Unit tests

- Local-day classification for Today, Future, and History.
- Boundary cases at midnight and cross-midnight ranges.
- Past incomplete reminders classify as History.
- Future local tickets and old incomplete reminders do not enter Today.
- Remaining count includes active and upcoming unfinished Today items and
  excludes elapsed and completed items.
- Recognition result parsing persists canonical start and end dates.
- Overnight arrival rolls to the next day when appropriate.
- Kind and scope filters compose correctly.
- Repository update and delete-by-ID behavior.
- Image deletion and pin cleanup.
- Type-aware Live Activity subtitle formatting.
- Every `TimelineKind` can become the primary Live Activity item.
- Active-item edit, delete, fallback, and activity termination.

### Integration and UI tests

- Saving the C5770 fixture refreshes Today and Live Activity immediately.
- The train is Next before 10:30, Now from 10:30 to 11:48, and History after
  the local day boundary.
- The manager switches among Today, Future, and History without scope leakage.
- Kind selection persists across scope changes.
- EventKit details are read-only.
- Local details expose edit and delete; edits reorder and reclassify items.
- Deleting the active local item reconciles Live Activity.
- Accessibility labels expose scope, kind, status, time, and action ownership.

### Visual regression

Screenshot assertions or reviewed simulator captures verify the approved warm
gradient background, warm glass cards, timeline rail, accent colors,
typography, and spacing on all touched surfaces.

## Delivery Order

1. Add shared time-scope classification and fix strict Today inputs/counting.
2. Persist canonical recognition dates and validate the C5770 fixture.
3. Add repository record-level mutation and image cleanup.
4. Build the independent timeline manager and local editor.
5. Generalize Live Activity presentation for every card kind.
6. Align touched UI with the approved visual tokens and references.
7. Run unit, integration, UI, Live Activity, and screenshot verification.
