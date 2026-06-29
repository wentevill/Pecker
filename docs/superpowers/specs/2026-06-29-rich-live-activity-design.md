# Rich Live Activity Presentation and Local Lifecycle Design

Date: 2026-06-29

## Summary

Pecker Live Activity will use a single-primary-item presentation across the
Lock Screen and Dynamic Island. It will no longer mix the current item, next
item, and pinned item in one presentation.

Train and flight tickets receive dedicated structured templates. Meeting,
task, travel, interview, deadline, and unknown items use a generic template
that preserves recognized fields instead of discarding everything except
title, location, and notes.

At a time boundary, Pecker recalculates the primary item. It updates the
existing Live Activity to the next eligible item when one exists and ends the
Live Activity when no eligible item remains. The project remains local-only:
foreground timers provide exact boundary handling while the app runs,
background refresh is best-effort, and activation reconciliation is the final
correctness fallback.

The approved visual reference is:

- `docs/visual-design/live-activity-all-types.html`

## Goals

- Restore the information hierarchy and strong type identity shown in
  `demo.png`.
- Present one primary item at a time without auxiliary Next or Pinned rows.
- Give train and flight tickets strong, structured ticket presentations.
- Give every generic event kind a recognizable symbol and predictable field
  hierarchy.
- Preserve recognized fields for generic templates.
- Reconcile at event boundaries, switching to the next eligible item or
  ending when none remains.
- Avoid displaying a misleading countdown after an item has ended.
- Keep the solution local-only and document the limits of background timing.

## Non-goals

- Adding an APNs provider or server-side Live Activity updates.
- Guaranteeing exact boundary execution while iOS has suspended the app.
- Creating dedicated templates for meeting, task, travel, interview,
  deadline, or unknown items.
- Displaying multiple simultaneous or supporting items in one Live Activity.
- Redesigning Today cards or item-detail screens beyond sharing presentation
  helpers where that removes duplication.

## Current Problems and Root Causes

### Missing core information

`PeckerActivityAttributes.ContentState` supplies one generic
`primarySubtitle`. `ActivityCoordinator` fills it with a location, note, or a
compressed train-ticket string. It does not provide a proper time range,
route endpoints, transport times, or ticket credentials as distinct fields.

The widget therefore cannot reproduce the approved hierarchy. For ordinary
events, the expected `09:30–10:00` line disappears whenever no code manually
places it in the subtitle. For tickets, multiple important fields collapse
into one truncated line.

### Weak type identity

The content state already carries `primaryKindRawValue`, but the Lock Screen
presentation does not consistently map it to a type symbol. Dynamic Island
often falls back to a status dot or ambiguous short title.

The app already has the correct kind-to-SF-Symbol mapping in
`TodayScreenContent`. Live Activity reimplements presentation separately and
does not consume that mapping.

### Generic recognition loses fields

`TrainTicketTemplate` preserves structured ticket information.
`GenericEventTemplate` preserves only kind, title, location, and notes.
Additional recognized values for flights and other event kinds are discarded,
so the Live Activity cannot render them later.

### No boundary execution

`staleDate` only changes the activity state to stale. It does not call
`Activity.end`.

Live Activity reconciliation currently runs when Today refreshes, such as on
app start, activation, settings changes, or EventKit changes. There is no
timer or background refresh request tied to the next event boundary.

## Presentation Architecture

### Dedicated templates

Pecker supports two dedicated ticket templates:

1. `TrainTicketTemplate`
2. `FlightTicketTemplate`

`FlightTicketTemplate` stores only canonical flight fields needed by the app:

- Flight number
- Carrier
- Departure airport or station name
- Departure airport code
- Arrival airport or station name
- Arrival airport code
- Departure time text when supplied by recognition
- Arrival time text when supplied by recognition
- Terminal
- Gate
- Seat
- Travel status when supplied

Canonical `TimelineItem.startDate` and `endDate` remain the source of truth for
time calculations. Recognized time text is supporting ticket content, not the
countdown clock.

### Generic template

`GenericEventTemplate` retains the normalized recognition field dictionary in
addition to kind, title, location, and notes.

The generic presentation adapter may select at most:

- The title
- The canonical time or time range
- The location
- One supporting detail

Unknown fields are preserved for future presentation and editing but do not
automatically appear in Live Activity. This keeps the content glanceable and
the encoded state below ActivityKit's size limit.

### Unified presentation adapter

A pure, testable adapter converts one `TimelineItem` plus a status and current
date into a `LiveActivityPresentation`.

The presentation contains display-ready semantic fields:

- Stable item identifier
- Status: now, next, or pinned
- Kind
- SF Symbol name
- Status label
- Primary title or ticket number
- Secondary identity such as carrier or route
- Canonical start and end dates
- Location or route endpoints
- At most four compact metadata chips for dedicated tickets
- One optional supporting detail for generic items

The widget formats locale-sensitive dates and countdowns from canonical dates.
It does not parse free-form subtitle text.

The kind symbols are:

- Meeting: `person.2.fill`
- Task: `checklist`
- Flight: `airplane`
- Train: `train.side.front.car`
- Travel: `suitcase.fill`
- Interview: `person.text.rectangle`
- Deadline: `calendar.badge.exclamationmark`
- Unknown: `clock.fill`

### Content state

`PeckerActivityAttributes.ContentState` carries exactly one primary
presentation. The existing supporting fields for next and pinned rows are
removed after migration.

The encoded state contains only fields used by the widget and must remain
comfortably below ActivityKit's 4 KB limit. Dedicated ticket metadata is
bounded to four short values. Generic recognized-field dictionaries never
enter the content state.

## Visual Contract

### Shared rules

- Green is the semantic accent for an item that is currently running.
- Blue supports time, direction, and route information.
- Orange identifies important travel content without replacing the current
  status color.
- Information order is type identity, title or identifier, time, route or
  location, core metadata, then countdown or progress.
- Missing fields collapse cleanly. Empty labels and placeholder punctuation
  never render.

### Train ticket

The train presentation follows approved option A:

- Running status and remaining time in the header
- Strong train symbol and train number
- Route directly below the number
- Departure and arrival times aligned with their stations
- Direction indicator between endpoints
- Up to four chips: carriage, seat, gate, and seat class
- Progress bar when the canonical interval is valid

### Flight ticket

The flight presentation mirrors the train hierarchy:

- Running status and remaining time
- Airplane symbol, flight number, and carrier
- Departure and arrival times with airport names or codes
- Up to four chips: terminal, gate, seat, and travel status
- Progress bar when the canonical interval is valid

### Generic items

Meeting, task, travel, interview, deadline, and unknown items use the same
structural shell with different symbols and copy.

An interval item displays its time range, location, one detail, remaining
time, and progress.

A point-in-time task or deadline displays its absolute target time and
remaining time. It does not show a fake progress bar.

### Dynamic Island

Expanded Dynamic Island follows the same single-item hierarchy with fewer
metadata values.

Compact presentation shows:

- Type symbol or status dot
- The shortest useful identifier or title
- Remaining time

Minimal presentation shows the type symbol. It does not use an unexplained
title abbreviation.

## Selection and Transition Rules

The existing primary priority remains:

1. Now
2. Next
3. Unfinished pinned item

Only the selected primary appears in the Live Activity.

At every relevant boundary:

1. Refresh the Today inputs and build a new snapshot.
2. If a Now item exists, present it.
3. Otherwise, present the Next item.
4. Otherwise, present an unfinished pinned item.
5. Otherwise, end and immediately dismiss the Live Activity.

When a running item ends and another item becomes eligible, update the
existing Live Activity to that item. Do not retain the ended item and do not
render a supporting row for the replacement before the boundary.

## Local Lifecycle Scheduling

### Boundary scheduler

A dedicated boundary scheduler tracks the earliest future date that can
change the primary presentation:

- Primary start
- Primary end
- Next start
- Pinned start or end
- Snapshot stale boundary

While the app process runs, the scheduler sleeps until the boundary and then
requests a full Today refresh and Live Activity reconciliation. Scheduling is
generation-based: replacing the snapshot cancels the previous scheduled
operation so an old task cannot overwrite newer state.

### Background refresh

When the app becomes inactive, Pecker submits a background refresh request
whose earliest begin date is the next boundary. Background execution is
best-effort and may occur later than requested.

The background handler loads current inputs, creates a fresh snapshot,
reconciles Live Activity, schedules the next request, and completes promptly.
Registration and permitted identifiers are configured in the app target.

### Activation fallback

Every app activation performs an immediate refresh and reconciliation before
relying on cached status text. This switches or ends any activity whose
background boundary work was delayed.

### Stale visual fallback

`staleDate` remains equal to the nearest boundary. It is an age signal, not an
end mechanism.

If the widget's local clock passes the primary end before reconciliation:

- It stops the countdown at zero.
- It removes the progress bar.
- It displays a neutral localized “已结束” state.
- It never shows “1m” indefinitely or continues presenting the item as
  running.

The system container may remain visible until iOS runs the app or background
task. This limitation is accepted by choosing the local-only lifecycle.

## Error Handling

- A failed background refresh leaves the activity stale and schedules a later
  best-effort refresh.
- A failed ActivityKit update does not corrupt the saved Today snapshot.
- Missing ticket fields degrade to the next valid hierarchy level.
- A ticket without route endpoints uses its number and canonical time range.
- A generic item without location uses its first non-empty supporting detail.
- A generic item without either remains valid with symbol, title, and time.
- Invalid or non-positive date intervals never produce progress.
- All text is line-limited and scales down before truncating critical
  identifiers.

## Testing

### Presentation tests

Add table-driven tests for all eight `TimelineKind` values:

- Correct symbol
- Correct status label
- Canonical time preservation
- Location and supporting-detail priority
- Missing-field degradation

Add dedicated train and flight tests for:

- Route endpoint mapping
- Departure and arrival times
- Bounded metadata order
- Missing number, endpoint, and credential fields

### Lifecycle tests

Test these transitions with a fake clock, scheduler, and Activity client:

- Now to Next
- Next to Now
- Now to pinned fallback
- Final eligible item to end
- Settings disabled to end
- Snapshot replacement cancels an old boundary
- Background execution after the intended boundary still selects current data
- Activation reconciliation cleans up a stale activity

### Widget presentation tests

Maintain previews for every type in Lock Screen and expanded Dynamic Island
presentations. Maintain compact and minimal previews for representative
ticket, generic interval, and point-in-time items.

Pure copy, color, symbol, metadata-selection, countdown, and stale-state logic
must remain unit-testable outside SwiftUI rendering.

## Acceptance Criteria

- The approved all-types HTML remains the visual source of truth.
- A running ticket clearly shows its transport identity and core credentials.
- A generic item always shows a recognizable type symbol and canonical time.
- The Live Activity never mixes primary, next, and pinned content.
- At a boundary, a running app switches to the next eligible item or ends
  immediately when none remains.
- A suspended app never shows a continued positive countdown after the
  primary end; it shows a neutral ended state until reconciliation.
- App activation always repairs a delayed background transition.
- All eight kinds and both dedicated ticket templates have regression tests.
