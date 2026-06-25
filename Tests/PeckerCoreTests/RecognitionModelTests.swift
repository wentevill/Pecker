import Foundation
import Testing
@testable import PeckerCore

@Test func timelineSettingsExposeAIRecognitionDefaults() {
    let settings = TimelineSettings()

    #expect(settings.aiRecognitionMode == .off)
    #expect(settings.openAIHost == "https://api.openai.com")
    #expect(settings.openAIModel == "gpt-5.4-mini")
    #expect(settings.openAIAPIKeyConfigured == false)
    #expect(settings.syncCalendarToStorage == false)
    #expect(settings.syncRemindersToStorage == false)
}

@Test func recognitionInputSupportsCalendarReminderAndImages() {
    let calendar = RecognitionInput.calendar(
        sourceIdentifier: "calendar-1",
        title: "G123 上海虹桥 → 北京南",
        location: "检票口 B7",
        notes: "08车 03A"
    )
    let reminder = RecognitionInput.reminder(
        sourceIdentifier: "reminder-1",
        title: "买票",
        notes: nil
    )
    let image = RecognitionInput.importedImage(
        id: "image-1",
        imageData: Data([1, 2, 3]),
        filename: "ticket.jpg"
    )
    let camera = RecognitionInput.cameraImage(
        id: "camera-1",
        imageData: Data([4, 5, 6])
    )

    #expect(calendar.source == .calendar)
    #expect(reminder.source == .reminder)
    #expect(image.source == .importedImage)
    #expect(camera.source == .cameraImage)
    #expect(image.imageData == Data([1, 2, 3]))
    #expect(camera.filename == nil)
}

@Test func localModelProviderIsExplicitlyUnavailable() async {
    let provider = LocalModelRecognitionProvider()

    await #expect(throws: RecognitionError.self) {
        _ = try await provider.recognize(
            .calendar(
                sourceIdentifier: "calendar-1",
                title: "Daily standup",
                location: nil,
                notes: nil
            )
        )
    }
}
