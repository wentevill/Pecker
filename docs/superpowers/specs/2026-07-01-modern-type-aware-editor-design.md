# Modern Type-Aware Event Editor Design

Date: 2026-07-01

## Goal

Replace the current long grouped `Form` with a modern Apple-style editing
experience for Pecker-owned records. The editor must preserve all existing
editing capabilities while making common information, type-specific
information, and user-defined fields visibly distinct.

This change applies only to the local event editor. Calendar and Reminder
records remain read-only, and the rest of the app keeps its current visual
language.

## Approved Direction

The editor opens from the detail screen as a bottom sheet. The sheet uses a
large continuous corner radius and native material, then expands to a full
screen editing surface when the keyboard appears or the content requires more
space. This preserves the lightness of a sheet without constraining long
forms.

The visual hierarchy is:

1. Navigation actions: Cancel and Done.
2. Event title and a concise time or route summary.
3. Horizontally scrollable event-type chips.
4. Common event information.
5. A type-specific information module.
6. Custom fields, available for every event type.

The UI uses system typography, semantic colors, native materials, continuous
rounded rectangles, subtle separators, and restrained shadows. It avoids the
current warm gradient behind the form and does not use decorative glass
overlays inside every field.

## Presentation Architecture

`TimelineRecordEditorView` becomes a composition of focused SwiftUI views:

- `EditorHeader` presents the title, summary, Cancel, and Done.
- `EventKindPicker` presents the eight `TimelineKind` values as scrollable
  selection chips.
- `CommonEventSection` edits title, all-day state, start, optional end,
  location, and notes.
- `TypeSpecificSection` selects one editor module for the current kind.
- `CustomFieldsSection` edits ordered name/value pairs for every kind.
- `EditorSaveError` presents validation and persistence errors near the
  affected content.

The root view owns the draft, save state, focus state, and sheet expansion
behavior. Child sections receive only the bindings and actions they need.

## Type-Specific Information

Each kind receives a deliberate field set:

- Meeting: location and notes are emphasized; no additional structured fields.
- Interview: location and notes are emphasized; no additional structured
  fields.
- Task: completion-oriented common information and notes; no additional
  structured fields.
- Deadline: deadline timing and notes; no additional structured fields.
- Travel: origin, destination, departure text, and arrival text.
- Flight: flight number, carrier, departure airport and code, arrival airport
  and code, departure and arrival text, terminal, gate, seat, and status.
- Train: train number, departure and arrival stations, departure and arrival
  text, carriage, seat, check-in gate, passenger, class, price, and ticket
  number.
- Unknown: common information and custom fields only.

Where the persisted template has no dedicated structure, type-specific values
remain custom fields instead of introducing partially used model types. Flight
and train continue using their specialized templates.

Changing the kind immediately changes the visible module but does not silently
delete values. Values belonging to a previously selected type remain in the
draft until Save. On Save, fields represented by the destination template are
written to that template; other non-empty values are preserved as custom
fields when they cannot be represented structurally.

## Custom Fields

Custom fields are ordered records with two strings:

- `name`
- `value`

They are not typed. The editor supports:

- Adding a row inline and focusing its name.
- Moving from name to value with the keyboard Return action.
- Deleting a row with a visible destructive control.
- Dragging rows to reorder them.
- Editing name and value directly in place.

Custom fields must work for generic, flight, and train records. They therefore
belong to `StoredEventRecord`, not only `GenericEventTemplate`.

Add a public, codable, hashable `EventCustomField` model with a stable ID,
name, and value. Add `[EventCustomField]` to `StoredEventRecord`; decoding old
records defaults to an empty array. Generic-template dictionaries are migrated
into ordered record fields when opened for editing, sorted by name because the
old dictionary contains no order. New saves use the record-level array as the
canonical source.

Add the same default-empty custom-field collection to `TimelineItem`, and pass
it through each local-record mapping path. The detail view renders non-empty
custom fields in their stored order after the specialized template fields.
This is a data-visibility addition, not a visual redesign of the detail page.

Save behavior is explicit:

- A row whose name and value are both blank is ignored.
- A row with only one side filled blocks Save and identifies that row.
- Names are trimmed and compared case-insensitively.
- Duplicate names block Save instead of silently overwriting a value.
- Reordering is persisted.

## Interaction Details

The title uses a prominent inline text field. Tapping a type chip updates the
type-specific section with a short content transition. Date controls use
compact native pickers and only reveal the end picker when enabled.

The editor starts at the large sheet detent from the detail screen, retaining
the visible rounded sheet edge. It remains at the large detent while a text
field is focused. The navigation-bar Done button is the canonical save action.
A bottom Save button is shown only while the keyboard is hidden; it invokes
the same save action and disappears while typing to avoid duplicated controls.

During save, both actions are disabled and the Done action shows progress.
Cancel dismisses immediately when the draft is unchanged. If the draft has
changed, Cancel asks whether to discard changes.

Accessibility requirements:

- All controls retain at least a 44-point hit target.
- Type selection is exposed as a single-selection group.
- Delete and reorder controls have explicit localized labels.
- Dynamic Type does not truncate field names or values.
- Reduce Motion disables the section transition.
- VoiceOver announces inline validation errors and save failures.

## Data Flow

1. `TimelineManagerModel` loads a local record and creates a
   `TimelineRecordEditor` draft.
2. The editor normalizes the stored template and record-level custom fields
   into editable state.
3. User changes stay in the draft; persistence is untouched.
4. Done validates common fields and every custom-field row.
5. The draft creates one updated `StoredEventRecord`, preserving source and
   image metadata.
6. The manager saves atomically through the existing repository flow.
7. On success, the sheet dismisses and Today, Timeline, detail, and Live
   Activity refresh through the existing update path.
8. On failure, the sheet stays open with all edits intact.

## Error Handling

Common validation continues to require a non-empty title and an end later than
the start. Custom-field errors appear immediately below the affected row.
Duplicate-name errors identify both conflicting rows.

Persistence failures use one localized inline error at the bottom of the
editor and keep the draft editable. Save may be retried. No validation or
persistence failure mutates the stored record.

## Testing

Model tests cover:

- Old records decode with no custom fields.
- Generic-template fields migrate into deterministic ordered fields.
- Custom fields persist for generic, flight, and train records.
- Reordering survives encode/decode and editor save.
- Blank rows are ignored.
- Half-complete and duplicate rows fail validation.
- Changing kinds preserves representable values and moves unrepresentable
  non-empty values into custom fields.
- Existing title and date validation remains intact.

View and interaction tests cover:

- Every kind exposes the correct type-specific section.
- Adding a custom field focuses the name, then advances to the value.
- Delete and reorder update the draft.
- Dirty Cancel requests discard confirmation.
- Save progress, success, and failure states behave correctly.

Simulator verification covers compact and large Dynamic Type, light and dark
appearance, keyboard presentation, a long flight form, a train form, and a
generic form with at least five custom fields.

## Out of Scope

- Editing Calendar or Reminder records.
- Typed custom fields.
- Changing recognition prompts or recognition payloads.
- Redesigning detail, Today, Timeline, Settings, or onboarding screens.
- Cloud synchronization or schema sharing between records.
