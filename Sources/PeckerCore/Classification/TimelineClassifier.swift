import Foundation

public struct TimelineClassifier: Sendable {
    private let factory: EventTemplateFactory

    public init(factory: EventTemplateFactory = .init()) {
        self.factory = factory
    }

    public func classify(
        title: String,
        location: String?,
        notes: String?,
        source: TimelineSource
    ) -> TimelineKind {
        let input = ClassificationInput(
            title: title,
            location: location,
            notes: notes
        )
        let text = input.normalizedText

        if let template = factory.makeTemplate(from: input) {
            return template.kind
        }

        if containsKeyword(
            in: text,
            keywords: ["flight", "\u{822a}\u{73ed}", "\u{673a}\u{573a}", "\u{8d77}\u{98de}", "gate", "terminal", "airport"]
        ) || text.range(
            of: "\\b[A-Z]{2}\\s?\\d{2,4}\\b",
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return .flight
        }

        if containsKeyword(
            in: text,
            keywords: ["train", "railway", "station", "\u{9ad8}\u{94c1}", "\u{706b}\u{8f66}", "\u{52a8}\u{8f66}"]
        ) {
            return .train
        }

        if containsKeyword(in: text, keywords: ["interview", "\u{9762}\u{8bd5}"]) {
            return .interview
        }

        if containsKeyword(in: text, keywords: ["deadline", "due", "\u{622a}\u{6b62}"]) {
            return .deadline
        }

        if containsKeyword(
            in: text,
            keywords: ["zoom", "meet", "teams", "meeting"]
        ) {
            return .meeting
        }

        if source == .reminder {
            return .task
        }

        return .unknown
    }

    private func containsKeyword(in text: String, keywords: [String]) -> Bool {
        keywords.contains { keyword in
            if keyword.unicodeScalars.allSatisfy(\.isASCII) {
                let pattern = "(?<![A-Za-z0-9])\(NSRegularExpression.escapedPattern(for: keyword))(?![A-Za-z0-9])"
                return text.range(of: pattern, options: .regularExpression) != nil
            }

            return text.contains(keyword)
        }
    }
}
