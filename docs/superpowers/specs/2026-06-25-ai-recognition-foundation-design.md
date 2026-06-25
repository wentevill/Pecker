# AI Recognition Foundation Design

## Goal

Add the foundation for AI event recognition while keeping the current timeline stable. The system supports OpenAI-compatible remote recognition, a future local small-model path, and a local event store that can optionally sync Calendar and Reminder data.

## UI Design First

Settings gains an “AI 识别” card:

- Mode picker:
  - Off
  - OpenAI / OpenAI-compatible
  - Local small model, shown as reserved/unavailable
- OpenAI-compatible settings:
  - Host text field, defaulting to `https://api.openai.com`
  - Model text field
  - API key status and save/clear actions through Keychain-backed storage
- Local storage switches:
  - Sync Calendar into Pecker storage
  - Sync Reminders into Pecker storage
- Privacy copy:
  - Local sync stores source content on device.
  - AI recognition sends content only when recognition is explicitly triggered.

The UI does not yet expose camera/photo import controls. This phase creates the input model for imported images and camera images so the next UI phase can attach to the same recognition pipeline.

## Architecture

Core models:

- `AIRecognitionMode`
- `RecognitionSource`
- `RecognitionInput`
- `RecognitionResult`
- `StoredEventRecord`
- `EventRepository`

Settings:

- `TimelineSettings` owns AI mode, OpenAI host/model, API-key configured flag, and Calendar/Reminder sync preferences.
- API keys are not stored in `TimelineSettings`; the app layer stores them in Keychain.

Recognition:

- `RecognitionProvider` is the common protocol.
- `OpenAIRecognitionProvider` is an OpenAI-compatible provider skeleton using `/v1/responses` and a JSON-schema-oriented prompt contract.
- `LocalModelRecognitionProvider` is an explicit unavailable placeholder.
- Providers return `ExternalEventTemplatePayload`, which flows into the existing `EventTemplateFactory`.

Storage:

- `EventRepository` stores `StoredEventRecord` values in app-group JSON.
- Calendar and Reminder records can be mirrored into this store when the user opts in.
- Image/camera records can be stored later using the same model with local image references.

## Boundaries

This phase does not implement a full OpenAI network call parser, camera UI, photo picker UI, OCR, or background sync scheduler. It creates the durable seams and settings required for those features.

## Verification

- Core tests cover settings defaults, recognition input modes, local-model placeholder, OpenAI request construction, event repository save/load/upsert, and Calendar/Reminder sync settings.
- App tests cover SettingsViewModel mutations for AI configuration and Keychain status.
- Full Swift tests and Xcode simulator tests must pass.
