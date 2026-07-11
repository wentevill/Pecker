# Continuous Multi-Image Recognition Design

**Date:** 2026-07-08  
**Status:** Draft

## Goal

Support event recognition from a continuous set of images when one event can
only be understood by combining multiple screenshots, photos, or pages.

The feature must:

1. treat one recognition action as exactly one event;
2. allow multiple images to provide complementary evidence for that event;
3. preserve the existing single-image API behavior;
4. keep the current three-stage recognition pipeline;
5. avoid storage and detail-view changes by saving the first image as the
   primary attachment for now.

## Narrative Rule

The model receives a continuous narrative, not a batch of independent events.
All images in one request describe the same event or provide context for it.

Prompt guidance:

```text
这是连续性叙事识别。一次输入可能包含多张图片，但它们只对应一个事件。
请按图片顺序联合判断：前一张可能给出标题/日期，后一张可能给出地点/座位/订单详情。
不要把多张图拆成多个事件；不要把无关信息拼接成不存在的事件。
若字段冲突，优先采用更具体、更清晰、离事件凭证更近的图片信息。
最终必须只返回一个最完整、可执行的事件。
```

Classification uses all images to choose one event kind. Extraction uses all
images to fill fields for that one event. Verification checks the final payload
against every image, removes unsupported fields, and resolves conflicts.

## Data Model

Add a small image value to `PeckerCore`:

```swift
public struct RecognitionImageInput: Sendable, Equatable {
    public let data: Data
    public let filename: String?
    public let mimeType: String
}
```

Extend `RecognitionInput` with:

```swift
public let images: [RecognitionImageInput]
```

Existing single-image properties stay available:

- `imageData`;
- `imageMIMEType`;
- `filename`.

For compatibility, single-image factory methods populate both the legacy
single-image fields and `images`. Calendar and reminder inputs use an empty
`images` array.

Add multi-image factory methods for imported and camera images. They build the
same `id`, `source`, `sourceIdentifier`, reference date, and time zone context
as the current single-image factories.

## Request Construction

`OpenAIRecognitionProvider` sends all `input.images` in order. Each image is
attached as an `image_url` content block after the task text.

The textual task includes image count and ordered filenames when present:

```text
imageCount: 3
images:
- image 1: checkout.png
- image 2: order-detail.png
- image 3: seat-map.png
```

MIME validation remains limited to:

- `image/jpeg`;
- `image/png`;
- `image/webp`.

Error handling continues to use the existing image-unsupported path. Any
request with one or more images is treated as an image request.

## App Recognition Flow

Add multi-image methods to `ImageRecognizing`, `ImageRecognitionCoordinator`,
and `SystemEventRecognitionCoordinator`:

```swift
func recognizeImages(
    _ images: [PreparedRecognitionImage],
    source: RecognitionSource,
    settings: TimelineSettings,
    now: Date
) async throws -> ImageRecognitionDraft
```

The existing single-image methods call the new multi-image method with a
one-element array.

`ImageRecognitionDraft` keeps its current single primary image fields. The
draft stores `images.first` as `imageData`, `filename`, and `mimeType`, because
current persistence has one `imageReference`. Empty image arrays are rejected
with `RecognitionError.unsupportedInput`.

## UI Flow

The Photos picker should allow selecting multiple images for one recognition
action. The selected items are loaded, preprocessed independently, and passed
to `recognizeImages`.

Camera capture stays single-image. It continues to use the existing camera
path, which delegates to the multi-image API internally.

The confirmation and save UI remain unchanged: the user confirms one event
draft, and saving persists the recognized event with the primary image.

## Testing

Core tests:

- `RecognitionInput` single-image factories also populate `images`;
- multi-image factories preserve order, MIME type, filename, reference date,
  and time zone;
- OpenAI request bodies include one `image_url` block per image;
- prompt text includes continuous narrative guidance;
- image-related service failures still use the image compatibility reason.

App tests:

- coordinator passes every prepared image to the provider in order;
- single-image coordinator calls still behave as before;
- empty multi-image recognition fails before provider invocation;
- drafts use the first image as the primary saved image.

UI tests can stay focused on compile-level behavior unless the picker logic is
factored into a unit-testable helper.

## Non-Goals

This change does not:

- split one multi-image request into multiple events;
- save all source images as attachments;
- add a multi-page detail gallery;
- change timeline record schema;
- support videos or PDFs.

Those can be added later once the recognition behavior is stable.
