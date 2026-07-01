# Recognized Event Save Visibility Design

## Problem

After an ordinary image-recognized event is saved, the UI reports success but
the event cannot be found in the Today, Future, or History timeline scopes.
The current save flow treats a repository write as complete without verifying
that the full timeline can reload and expose the saved record. Existing kind
filters can also hide a newly saved event, and elapsed point-in-time events
without an end date are omitted by timeline grouping.

## Design

`TodayView.saveRecognitionDraft()` will keep the returned
`StoredEventRecord`. After persistence succeeds, it will reload
`TimelineManagerModel`, clear the selected kind filter, select the date scope
computed from the saved event, and verify that the saved record ID exists in
the manager's loaded items.

Only a record found after reload is considered a successful save. On success,
the recognition UI shows its success state and navigates to the full timeline
with the saved event's scope selected. If reload fails or the record is absent,
the recognition UI remains on the draft and shows a save failure instead of a
false success.

`TimelineGrouping` will classify a non-reminder, non-all-day item with no end
date as upcoming before its start and elapsed at or after its start. This
ensures point-in-time ordinary events appear in exactly one section.

## Data Flow

1. Persist the image and recognized record.
2. Reload `TimelineManagerModel` from the repository and system sources.
3. Clear `selectedKind`.
4. Classify the saved item into Today, Future, or History.
5. Select that scope and verify the saved ID is present.
6. Show success and navigate to the full timeline.
7. If any verification step fails, retain the draft and show save failure.

## Error Handling

Timeline reload must expose whether loading failed so the save flow can
distinguish a verified result from an empty list caused by an error. A missing
saved ID is treated as a save verification failure. The image-store rollback
behavior remains unchanged for repository write failures.

## Tests

- A timeline-manager test will cover reloading and locating a persisted
  ordinary recognized event by ID.
- A save-flow helper test will cover clearing kind filters and selecting the
  saved event's date scope.
- A grouping test will prove that an elapsed event without an end date appears
  in the elapsed section.
- Existing recognition, persistence, timeline, and app build checks will run
  after implementation.
