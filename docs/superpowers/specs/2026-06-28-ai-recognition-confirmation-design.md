# AI Recognition Confirmation Design

## Goal

Change image and camera recognition from immediate persistence to an explicit preview-and-confirm flow:

1. While the AI request is running, show a typing-style activity indicator without exposing model reasoning.
2. When recognition finishes, replace the loading state in place with a result card.
3. Persist the image and recognized event only after the user taps Save.
4. Discard all draft data when the user taps Cancel.

Calendar and reminder synchronization remain unchanged.

## User Experience

The existing recognition card uses one progressive, in-place layout.

### Idle

- Show the photo-library and camera actions.
- Status copy is `等待图片`.

### Recognizing

- Disable the photo-library and camera actions.
- Show `正在识别` followed by three animated typing dots.
- The dots animate in a repeating sequence while the request is in flight.
- When Reduce Motion is enabled, use a static ellipsis instead of animated dots.
- Never display `<think>` content or any other model reasoning.

### Awaiting Confirmation

- Keep the user on the Today screen.
- Expand the same recognition card to show the recognized event preview.
- Use the template presentation already produced by `TimelineEventTemplate`:
  - title;
  - subtitle when available;
  - all non-empty labeled fields.
- Show two actions:
  - `保存`: persist the image and event;
  - `取消`: discard the draft and return to Idle.
- The first version does not allow editing recognized fields.

### Saving

- Keep the preview visible.
- Disable Save and Cancel while persistence is running.
- Show an inline progress indicator and `正在保存`.

### Success

- Clear the draft.
- Return the recognition card to Idle with short success copy.
- Refresh the Today timeline so the saved event appears.

## State Model

Replace the current image recognition phase with a state that owns the pending draft:

```swift
enum ImageRecognitionPhase: Equatable {
    case idle
    case recognizing
    case awaitingConfirmation(ImageRecognitionDraft)
    case saving(ImageRecognitionDraft)
    case success(String)
    case failure(String)
    case saveFailure(ImageRecognitionDraft, String)
}
```

`ImageRecognitionDraft` is an in-memory, sendable value containing:

- a stable draft identifier;
- original image data;
- recognition source;
- original filename;
- recognition timestamp;
- the recognized `TimelineEventTemplate`.

It exposes the template presentation used by the result card. It is not encoded to disk.

## Recognition and Persistence Boundaries

Image recognition becomes a two-step API.

```swift
protocol ImageRecognizing: Sendable {
    func recognizeImage(
        data: Data,
        source: RecognitionSource,
        filename: String?,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft

    func saveRecognizedImage(
        _ draft: ImageRecognitionDraft
    ) async throws -> StoredEventRecord
}
```

### Recognize

1. Validate AI configuration.
2. Send the original image data to the configured provider.
3. Convert the provider payload into a `TimelineEventTemplate`.
4. Return an `ImageRecognitionDraft`.
5. Do not write the image file.
6. Do not insert pending, failed, or recognized event records.

Recognition errors leave no persistent artifacts.

### Save

1. Save the draft image through `ImageFileStoring`.
2. Construct a recognized `StoredEventRecord` using the draft identifier, source, filename, template, and recognition timestamp.
3. Upsert the record through `EventRepositoryStoring`.
4. Return the stored record.

If image persistence succeeds but event persistence fails, delete the newly written image before reporting failure. `ImageFileStoring` therefore gains deletion support for rollback.

### Cancel

Cancel clears the in-memory draft. Because recognition has not written files or repository records, no cleanup operation is required.

## Provider Response Handling

The request remains a non-streaming Chat Completions request. The UI typing indicator represents request activity and is not driven by model tokens.

Some compatible providers return reasoning wrappers before the final object, for example:

```text
<think>
...
</think>

{"kind":"train","fields":{...}}
```

The provider parser must:

1. read the assistant content;
2. locate and decode the final JSON object;
3. discard all leading reasoning or prose;
4. return only `ExternalEventTemplatePayload`.

Reasoning text is never included in `RecognitionResult`, application state, logs, or UI.

## Error Handling

### Recognition Failure

- Show the existing specific configuration, network, unsupported-model, invalid-response, or unsupported-input copy.
- Re-enable photo and camera actions.
- Do not retain a draft or persistent artifact.

### Save Failure

- Keep the result preview and its original image data in memory.
- Display the persistence error below the preview.
- Allow the user to retry Save or choose Cancel.
- Retrying Save must not call the AI provider again.

### New Recognition

Photo and camera actions are disabled while a draft is awaiting confirmation. The user must Save or Cancel before starting another recognition request.

## Accessibility

- The typing indicator has the accessibility label `正在识别图片`.
- Animated dots are hidden from accessibility individually.
- The result card is read in title, subtitle, then field order.
- Save and Cancel use explicit button labels.
- Reduce Motion replaces dot animation with static punctuation.

## Testing

### PeckerCore

- Parse a pure Chat Completions JSON response.
- Parse a response with `<think>` content before the final JSON.
- Reject a response with no decodable final JSON object.

### App Coordination

- Recognition returns a draft without writing an image or event record.
- Saving a draft writes one image and one recognized event record.
- Cancel requires no persistence operation and leaves no record.
- A repository failure rolls back the newly saved image.
- Retrying persistence uses the same draft and does not invoke the provider again.

### Presentation

- Map Idle to enabled recognition actions.
- Map Recognizing to disabled actions and the typing indicator.
- Map Awaiting Confirmation to a preview with Save and Cancel.
- Map Saving to a visible preview with disabled actions.
- Map Save Failure to the retained preview and persistence error.

### Verification

- Run all Swift package tests.
- Run Pecker app tests.
- Build the Pecker scheme for a generic iOS Simulator with code signing disabled.

## Non-Goals

- Displaying or storing model chain-of-thought.
- Streaming model tokens.
- Editing recognized fields before saving.
- Saving recognition drafts across app launches.
- Changing calendar or reminder synchronization.
- Automatically selecting a different model when the configured model does not support images.
