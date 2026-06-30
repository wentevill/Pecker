import Testing
@testable import PeckerCore

private struct ClassificationCase: Sendable {
    let title: String
    let location: String?
    let notes: String?
    let source: TimelineSource
    let expectedKind: TimelineKind
}

@Test(
    arguments: [
        ClassificationCase(
            title: "SQ833 Flight to Singapore",
            location: "T3 Gate B7",
            notes: nil,
            source: .reminder,
            expectedKind: .flight
        ),
        ClassificationCase(
            title: "\u{9ad8}\u{94c1} G123",
            location: "\u{4e0a}\u{6d77}\u{8679}\u{6865}\u{7ad9}",
            notes: nil,
            source: .reminder,
            expectedKind: .train
        ),
        ClassificationCase(
            title: "Product Interview Meeting",
            location: nil,
            notes: nil,
            source: .reminder,
            expectedKind: .interview
        ),
        ClassificationCase(
            title: "Project Deadline",
            location: nil,
            notes: "\u{622a}\u{6b62}\u{4eca}\u{5929}",
            source: .reminder,
            expectedKind: .deadline
        ),
        ClassificationCase(
            title: "Daily Standup",
            location: nil,
            notes: "Zoom",
            source: .reminder,
            expectedKind: .meeting
        ),
        ClassificationCase(
            title: "Buy milk",
            location: nil,
            notes: nil,
            source: .reminder,
            expectedKind: .task
        ),
        ClassificationCase(
            title: "Lunch with Alex",
            location: "Downtown",
            notes: nil,
            source: .calendar,
            expectedKind: .unknown
        ),
        ClassificationCase(
            title: "flíght status",
            location: nil,
            notes: nil,
            source: .calendar,
            expectedKind: .flight
        ),
        ClassificationCase(
            title: "sq 833",
            location: nil,
            notes: nil,
            source: .calendar,
            expectedKind: .flight
        )
    ]
)
private func classifiesTimelineItems(testCase: ClassificationCase) {
    let classifier = TimelineClassifier()

    let kind = classifier.classify(
        title: testCase.title,
        location: testCase.location,
        notes: testCase.notes,
        source: testCase.source
    )

    #expect(kind == testCase.expectedKind)
}

@Test(
    arguments: [
        "Delegate review",
        "Training plan",
        "Duet practice",
        "Steams report"
    ]
)
private func classifiesLatinKeywordSubstringsAsUnknown(title: String) {
    let classifier = TimelineClassifier()

    let kind = classifier.classify(
        title: title,
        location: nil,
        notes: nil,
        source: .calendar
    )

    #expect(kind == .unknown)
}

@Test(
    arguments: [
        ClassificationCase(
            title: "Zoom\u{4f1a}\u{8bae}",
            location: nil,
            notes: nil,
            source: .calendar,
            expectedKind: .meeting
        ),
        ClassificationCase(
            title: "Train\u{884c}\u{7a0b}",
            location: nil,
            notes: nil,
            source: .calendar,
            expectedKind: .train
        ),
        ClassificationCase(
            title: "Gate\u{767b}\u{673a}",
            location: nil,
            notes: nil,
            source: .calendar,
            expectedKind: .flight
        )
    ]
)
private func classifiesLatinKeywordsAdjacentToChinese(testCase: ClassificationCase) {
    let classifier = TimelineClassifier()

    let kind = classifier.classify(
        title: testCase.title,
        location: testCase.location,
        notes: testCase.notes,
        source: testCase.source
    )

    #expect(kind == testCase.expectedKind)
}
