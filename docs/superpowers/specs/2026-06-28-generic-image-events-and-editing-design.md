# Generic Image Events and Local Editing Design

Date: 2026-06-28

## Goal

Image recognition must create ordinary events as well as specialized tickets.
Every Pecker-owned card must support manual editing and deletion.

## Recognition Model

Add a generic event template alongside the existing train-ticket template.
The provider returns one common envelope:

- `kind`: meeting, task, flight, train, travel, interview, deadline, or unknown.
- `title`: concise event title.
- `startDateTime`: canonical ISO-8601 start with UTC offset.
- `endDateTime`: canonical ISO-8601 end with UTC offset when known.
- `location`: optional place.
- `notes`: optional details.
- `fields`: type-specific display fields.

Train tickets continue using the train template. All other actionable content
uses the generic event template. An actionable non-ticket result must no longer
fail merely because no specialized template exists.

Relative dates are resolved against the recognition time using Pecker's local
calendar and time zone. A visible time without a date belongs to the local
recognition day. When an end time is earlier than its start and no explicit end
date exists, the end belongs to the following day.

Missing title or start time blocks Save. The confirmation card shows title,
time range, location, notes, and recognized type.

## Acceptance Example

For an image containing:

> 今天晚上11点去巡逻，11半结束。巡查楼梯口、仓库、围栏。

when recognized on 2026-06-28 in Asia/Shanghai, Pecker creates:

- Title: `巡逻`
- Kind: `task`
- Start: `2026-06-28 23:00 +08:00`
- End: `2026-06-28 23:30 +08:00`
- Notes: `巡查楼梯口、仓库、围栏`

The card appears in Today, can become Next or Now in Live Activity, and moves
to History according to the shared date-scope rules.

## Editing

Only Pecker-owned external/image cards are editable. Calendar and Reminder
cards remain read-only.

The warm editor supports:

- Title
- Kind
- Start date and time
- Optional end date and time
- Location
- Notes
- Train-specific route, train number, carriage, seat, gate, class, price, and
  ticket/order number when the card is a train ticket

Save validates a non-empty title, a valid start, and an end later than start.
Successful edits immediately refresh Today, Timeline Manager, and Live
Activity. A time edit may move the card among Today, Future, and History.

## Deletion

Local cards expose a destructive action with confirmation. Successful deletion
removes the stored record and its source image, clears a matching manual pin,
refreshes all timelines, and reconciles Live Activity. If the deleted card is
active, Live Activity selects the next eligible card or ends.

Failed edits keep the editor open with the persisted card unchanged. Failed
record deletion keeps the card and image. A record deleted successfully but
whose image cleanup fails remains deleted and reports cleanup failure.

## Visual Contract

Recognition confirmation, editor, and delete confirmation reuse the existing
warm gradient, warm glass cards, 30-point continuous radius, dark warm text,
and green/blue/orange semantic accents. They must remain visually continuous
with Today and the Timeline Manager.

## Tests

- Generic provider payload creates a generic template instead of unsupported
  input.
- The patrol sentence produces the exact title, kind, start, end, and notes
  above.
- Missing title or start blocks Save.
- Relative date and overnight end parsing use the injected calendar/time zone.
- Generic cards enter Today and Live Activity using canonical timing.
- Editing updates content and can reclassify time scope.
- System cards expose no edit/delete actions.
- Deleting a local card removes its image, clears its pin, and reconciles Live
  Activity.
- Edit/delete failures preserve persisted data.
- Simulator screenshots verify the warm visual contract.
