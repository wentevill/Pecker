# Now Timeline MVP Design

Date: 2026-06-22
Status: Ready for user review
Reference visual: `demo.png`

> Historical note: this product/design document predates the rename. The
> shipping app and project identity is now Pecker: Xcode project/scheme/app
> target `Pecker`, core module `PeckerCore`, bundle identifier
> `com.wenttang.pecker`, and App Group `group.com.wenttang.pecker`.

## 1. Product Summary

Now Timeline is a native iPhone utility that turns Apple Calendar and Apple
Reminders data into a concise view of:

- what is happening now;
- how much time remains;
- what comes next; and
- which upcoming event deserves special attention.

The primary surface is the Lock Screen and Dynamic Island. The app exists to
grant permissions, configure behavior, inspect the full timeline, and refresh
the Live Activity.

The MVP has no account, backend, cloud synchronization, AI classification,
email parsing, Wallet parsing, Google Calendar integration, or non-iPhone
client.

## 2. Platform and Product Constraints

- Minimum deployment target: iOS 26.
- Build with a stable Xcode 26 SDK; do not depend on iOS 27 beta APIs.
- Native stack only: Swift, SwiftUI, EventKit, ActivityKit, WidgetKit, App
  Groups, and UserDefaults.
- The app reads local Calendar and Reminders data. It does not modify either
  source.
- User-facing copy uses a Chinese-English mix:
  - status and navigation labels use Simplified Chinese;
  - event titles remain exactly as supplied by EventKit;
  - flight numbers, locations, and times use their source or system format.
- Visual direction: dark “time capsule,” based primarily on `demo.png`.

## 3. Information Architecture

The app uses one root screen and no bottom tab bar.

### First-run flow

1. Welcome and privacy promise.
2. Calendar permission explanation and system request.
3. Reminders permission explanation and system request.
4. Explicit user action to enable the Live Activity.
5. Today screen.

The user may continue if either Calendar or Reminders access is denied. The
available source remains usable.

### Daily flow

- **Today** is the root screen.
- A gear button opens **Settings**.
- The bottom summary row opens the **Full Timeline**.
- Selecting a Now, Next, Pinned, or list item opens **Item Detail**.
- Pull to refresh reloads EventKit data and reconciles the Live Activity.

## 4. Visual System

### Foundation

- Deep navy-to-black background with a restrained cool gradient.
- Translucent dark cards with thin light borders and soft shadows.
- A vertical timeline joins the primary cards.
- Rounded geometry should feel native to SwiftUI and iOS rather than like a
  custom web dashboard.
- System typography and SF Symbols are preferred.

### Semantic colors

- Green: currently active.
- Blue: upcoming.
- Orange: pinned or important travel.
- Neutral gray: metadata, elapsed items, and secondary actions.

Color is never the only status indicator. Each state also has a text label,
icon, or position.

### Accessibility

- Support Dynamic Type without truncating essential times or countdowns.
- Preserve readable contrast over materials and gradients.
- Provide VoiceOver labels that combine status, title, time, and countdown.
- Respect Reduce Motion and Reduce Transparency.

## 5. Today Screen

The Today screen adapts the visual hierarchy in `demo.png` into a real app
screen. It does not reproduce the iPhone frame, Lock Screen clock, flashlight,
or camera controls.

### Header

- Local date and weekday.
- `Today` title.
- Settings button.

### Now card

Displays the highest-priority timed item satisfying:

```text
startDate <= now && endDate > now
```

Content:

- `现在` label;
- source-appropriate symbol;
- original title;
- start and end time;
- remaining-time text;
- progress bar calculated from start and end;
- `另有 N 项进行中` when other simultaneous items exist.

Priority for simultaneous active items:

1. manually pinned;
2. flight or train;
3. interview;
4. meeting;
5. deadline;
6. task;
7. unknown.

Stable tie-breakers are earliest end time, earliest start time, then title.

Selecting the card opens its detail. Selecting the concurrent-items label
opens the Full Timeline filtered to active items.

### Next card

Displays the first timed item whose start date is later than now. It shows:

- `下一项`;
- title;
- start and end time when available; and
- relative time until start.

All-day events are excluded from Next because they do not have a meaningful
countdown boundary.

### Pinned card

The Pinned card displays one unfinished important item.

- The engine recommends one item automatically.
- The user may manually pin or unpin an item.
- A valid manual pin overrides the automatic recommendation.
- The card identifies whether it is `自动推荐` or `手动固定`.
- If the pinned source item disappears or finishes, the stored pin is cleared.

Automatic ranking:

1. flight;
2. train;
3. interview;
4. meeting;
5. deadline.

Only unfinished items with a meaningful date are eligible. Earlier eligible
items win within the same category.

### Timeline summary

A row such as `今天还有 3 个日程` opens the Full Timeline. The count includes
unfinished timed items and all-day items that are still relevant today, but
does not duplicate the visible Now item.

### Refresh state

The footer shows the last successful refresh time. Pull to refresh reloads
data. If a reload fails, the last valid snapshot remains visible with a stale
data notice and retry action.

## 6. Full Timeline

Items are grouped in this order:

1. overdue reminders;
2. all-day items;
3. active items;
4. upcoming items;
5. completed or elapsed items.

Each row shows source, title, time, status, and pin state. Concurrent items are
visually marked but remain separate rows. Selecting a row opens Item Detail.

The screen supports a filtered active-items presentation when opened from
`另有 N 项进行中`.

## 7. Item Detail

The detail screen is read-only with respect to EventKit and displays available
fields:

- source and classified kind;
- title;
- start and end time;
- location;
- notes; and
- current timing status.

The primary action is `固定行程` or `取消固定`. This setting is local to Now
Timeline and never changes the Calendar event or Reminder.

## 8. Settings

### Data Sources

- Calendar enabled.
- Reminders enabled.
- Current authorization state for each source.
- When authorization is denied or restricted, show a clear route to iOS
  Settings.

Turning a source off filters it from future snapshots but does not revoke the
system permission.

### Timeline

- Show Travel Events.
- Reminder Duration: 15, 30, 45, or 60 minutes.

When Show Travel Events is off, travel classification and automatic travel
pinning are disabled. The original Calendar item remains available as a normal
event.

### Live Activity

- Current status: active, paused, unavailable, or needs activation.
- Pause or resume.
- Re-enable when the activity has ended or system permission changed.

## 9. Empty and Error States

### No items today

Show `今天暂时空闲` and a refresh action. Do not start or retain an empty Live
Activity.

### Partial authorization

Continue with the authorized source. Show a non-blocking explanation and route
to system settings for the unavailable source.

### No authorization

Show a privacy-focused empty state with controls for enabling access. End any
existing Live Activity.

### Read or decode failure

Retain the last valid snapshot when one exists, mark it as outdated, and offer
retry. If no valid snapshot exists, show a dedicated error state rather than
an empty timeline.

## 10. Live Activity

The user explicitly enables the Live Activity during first run. After that,
the app reconciles it whenever the app launches, returns to the foreground,
refreshes, or receives an EventKit store-change notification while running.

The design does not promise arbitrary background reconstruction without a
backend or push service.

### Lock Screen hierarchy

1. Now title, remaining time, and progress.
2. Next title and time until start.
3. One compact Pinned travel line when relevant and space permits.

### Dynamic Island

- Compact leading: status dot and a safely shortened Now title.
- Compact trailing: remaining minutes.
- Expanded leading: Now.
- Expanded trailing: remaining time.
- Expanded bottom or center: Next and progress.
- Minimal: status dot or remaining minutes.

Avoid opaque abbreviations. If a title cannot fit meaningfully, prioritize the
countdown and status symbol.

### Content fallback

- **Now exists:** Now is primary; Next is secondary.
- **No Now, Next exists:** Next becomes primary and shows time until start.
- **Only Pinned exists:** Pinned becomes primary with its countdown.
- **No relevant items:** end the Live Activity.

Use system timer and date text where possible so visible countdown text can
advance without continuous app execution. Each update sets a stale date so
iOS can identify outdated content.

## 11. Data Model

```swift
struct TimelineItem: Codable, Identifiable, Hashable {
    let id: String
    let sourceIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let source: TimelineSource
    let kind: TimelineKind
    let location: String?
    let notes: String?
}

enum TimelineSource: String, Codable {
    case calendar
    case reminder
}

enum TimelineKind: String, Codable {
    case meeting
    case task
    case flight
    case train
    case travel
    case interview
    case deadline
    case unknown
}

struct TodaySnapshot: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let staleAfter: Date
    let items: [TimelineItem]
    let nowItemID: String?
    let concurrentNowCount: Int
    let nextItemID: String?
    let pinnedItemID: String?
    let pinOrigin: PinOrigin?
}

enum PinOrigin: String, Codable {
    case automatic
    case manual
}
```

The Live Activity content state carries dates, titles, and identifiers needed
for rendering. It should not store only preformatted countdown strings.

## 12. EventKit Mapping

### Calendar

Request full event access and query the local-day interval. Include events
that overlap today, including those that begin before midnight and end today.

Map:

- title;
- start date;
- end date;
- all-day state;
- location;
- notes; and
- stable EventKit identifier.

### Reminders

Request full reminder access. Include:

- incomplete reminders due today;
- incomplete overdue reminders.

A Reminder due date becomes `startDate`. Its `endDate` is the selected default
duration after the due date. Reminders without any due date are not placed on
the Today timeline. The MVP does not query future days to fill an otherwise
empty Today screen.

### Classification

Classification is deterministic keyword matching over normalized title,
location, and notes. Matching is case-insensitive where applicable.

Initial categories include:

- flight: Flight, Gate, Terminal, Airport, common flight-number patterns,
  起飞, 航班, 机场;
- train: Train, Railway, Station, 高铁, 火车, 动车;
- interview: Interview, 面试;
- meeting: Zoom, Meet, Teams, Meeting;
- deadline: Deadline, Due, 截止.

Specific categories win over general ones: flight and train before meeting,
interview before meeting, and deadline before task.

## 13. Architecture

### EventKitGateway

Owns:

- authorization status and requests;
- Calendar queries;
- Reminder queries; and
- mapping EventKit objects into normalized input records.

It is hidden behind protocols so tests do not require a live EventKit store.

### TimelineEngine

A pure Swift component that:

- merges normalized records;
- classifies item kind;
- sorts items;
- calculates Now, concurrent Now count, Next, and Pinned; and
- creates `TodaySnapshot`.

It has no SwiftUI, EventKit, ActivityKit, or file-system dependency.

### SnapshotStore

Writes versioned Codable data atomically to the App Group container:

```text
today_snapshot.json
settings.json
```

It rejects incomplete writes, tolerates missing files, and exposes decode
failures distinctly from an empty timeline.

### ActivityCoordinator

Translates a snapshot into ActivityKit attributes and content state, then
decides whether to start, update, leave unchanged, or end the current
activity.

### SwiftUI App

Renders onboarding, Today, Full Timeline, Item Detail, Settings, and all
empty/error states. It owns foreground refresh orchestration.

### Widget Extension

Renders Lock Screen and Dynamic Island presentations from ActivityKit state.
It does not query EventKit directly.

## 14. Refresh and Storage Lifecycle

Recalculate on:

- cold launch;
- return to foreground;
- pull to refresh;
- relevant settings changes; and
- EventKit store-change notification while the app is active.

`TodaySnapshot` records `generatedAt` and `staleAfter`. The UI may display a
stale snapshot, but must label it. The ActivityKit update uses an appropriate
stale date.

At local-day rollover, the existing state is no longer considered a valid
Today snapshot. The next app execution rebuilds it. The MVP does not add a
server or claim guaranteed midnight background execution.

## 15. Testing Strategy

### TimelineEngine unit tests

Cover:

- active-boundary inclusivity;
- simultaneous active-item ranking;
- stable tie-breaking;
- next-item selection;
- all-day exclusion from Now and Next;
- overdue reminders;
- configurable Reminder duration;
- cross-midnight events;
- travel and meeting keyword precedence;
- automatic versus manual pinning;
- missing or completed manual-pin targets; and
- empty days.

### Storage tests

Cover:

- round-trip encoding;
- atomic replacement;
- missing file;
- corrupted file;
- unsupported schema version; and
- stale snapshot detection.

### ActivityCoordinator tests

Cover:

- first explicit activation;
- start, update, no-op, pause, resume, and end decisions;
- Now-to-Next fallback;
- Pinned-only fallback;
- stale date; and
- no-relevant-item termination.

### UI verification

Use SwiftUI previews and visual checks for:

- default Today;
- simultaneous Now items;
- long titles and Dynamic Type;
- partial and denied permissions;
- empty timeline;
- stale snapshot;
- Lock Screen;
- compact, expanded, and minimal Dynamic Island.

Real-device verification is required for EventKit permissions and Live
Activity/Dynamic Island behavior.

## 16. MVP Acceptance Criteria

The MVP design is satisfied when:

- the user can independently authorize Calendar and Reminders;
- the app produces a Today timeline from authorized sources;
- Now, concurrent Now count, Next, and Pinned follow the specified rules;
- automatic pinning can be overridden and restored by the user;
- the full timeline, detail, settings, empty, permission, and error states are
  implemented;
- the user can explicitly enable, pause, resume, and re-enable the Live
  Activity;
- Lock Screen and supported Dynamic Island presentations follow the content
  hierarchy and fallback rules;
- no backend, account, AI, or non-native runtime is introduced; and
- the interface follows the approved dark visual direction based on
  `demo.png`.
