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
    let startDate = Date(timeIntervalSince1970: 1_000)
    let endDate = Date(timeIntervalSince1970: 2_000)
    let calendar = RecognitionInput.calendar(
        sourceIdentifier: "calendar-1",
        title: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}",
        startDate: startDate,
        endDate: endDate,
        isAllDay: false,
        location: "\u{68c0}\u{7968}\u{53e3} B7",
        notes: "08\u{8f66} 03A"
    )
    let reminder = RecognitionInput.reminder(
        sourceIdentifier: "reminder-1",
        title: "\u{4e70}\u{7968}",
        dueDate: startDate,
        endDate: endDate,
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
    #expect(calendar.startDate == startDate)
    #expect(calendar.endDate == endDate)
    #expect(calendar.isAllDay == false)
    #expect(reminder.startDate == startDate)
    #expect(reminder.endDate == endDate)
    #expect(reminder.isAllDay == false)
    #expect(image.imageData == Data([1, 2, 3]))
    #expect(image.images == [
        RecognitionImageInput(
            data: Data([1, 2, 3]),
            filename: "ticket.jpg",
            mimeType: "image/jpeg"
        )
    ])
    #expect(camera.filename == "recognition.jpg")
    #expect(camera.imageMIMEType == "image/jpeg")
    #expect(camera.images == [
        RecognitionImageInput(
            data: Data([4, 5, 6]),
            filename: "recognition.jpg",
            mimeType: "image/jpeg"
        )
    ])
}

@Test func imageRecognitionInputCarriesExplicitMIMEType() {
    let input = RecognitionInput.importedImage(
        id: "image-1",
        imageData: Data([0xFF, 0xD8, 0xFF]),
        filename: "recognition.jpg",
        mimeType: "image/jpeg"
    )

    #expect(input.imageMIMEType == "image/jpeg")
    #expect(input.images.first?.mimeType == "image/jpeg")
}

@Test func recognitionInputSupportsOrderedImportedImageNarratives() {
    let referenceDate = Date(timeIntervalSince1970: 1_000)
    let input = RecognitionInput.importedImages(
        id: "story-1",
        images: [
            RecognitionImageInput(
                data: Data([1]),
                filename: "checkout.png",
                mimeType: "image/png"
            ),
            RecognitionImageInput(
                data: Data([2]),
                filename: "details.webp",
                mimeType: "image/webp"
            )
        ],
        referenceDate: referenceDate,
        timeZoneIdentifier: "Asia/Shanghai"
    )

    #expect(input.id == "image:story-1")
    #expect(input.source == .importedImage)
    #expect(input.sourceIdentifier == "story-1")
    #expect(input.imageData == Data([1]))
    #expect(input.filename == "checkout.png")
    #expect(input.imageMIMEType == "image/png")
    #expect(input.images.map(\.data) == [Data([1]), Data([2])])
    #expect(input.images.map(\.filename) == ["checkout.png", "details.webp"])
    #expect(input.images.map(\.mimeType) == ["image/png", "image/webp"])
    #expect(input.referenceDate == referenceDate)
    #expect(input.timeZoneIdentifier == "Asia/Shanghai")
}

@Test func recognitionInputSupportsOrderedCameraImageNarratives() {
    let input = RecognitionInput.cameraImages(
        id: "camera-story-1",
        images: [
            RecognitionImageInput(
                data: Data([3]),
                filename: "front.jpg",
                mimeType: "image/jpeg"
            ),
            RecognitionImageInput(
                data: Data([4]),
                filename: "back.jpg",
                mimeType: "image/jpeg"
            )
        ],
        referenceDate: nil,
        timeZoneIdentifier: nil
    )

    #expect(input.id == "camera:camera-story-1")
    #expect(input.source == .cameraImage)
    #expect(input.imageData == Data([3]))
    #expect(input.filename == "front.jpg")
    #expect(input.images.map(\.data) == [Data([3]), Data([4])])
}
