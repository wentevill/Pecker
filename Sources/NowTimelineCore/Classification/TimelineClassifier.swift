import Foundation

public struct TimelineClassifier: Sendable {
    public init() {}

    public func classify(
        title: String,
        location: String?,
        notes: String?,
        source: TimelineSource
    ) -> TimelineKind {
        let text = [title, location, notes]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )

        if containsKeyword(
            in: text,
            keywords: ["flight", "航班", "机场", "起飞", "gate", "terminal", "airport"]
        ) || text.range(
            of: "\\b[A-Z]{2}\\s?\\d{2,4}\\b",
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return .flight
        }

        if containsKeyword(
            in: text,
            keywords: ["train", "railway", "station", "高铁", "火车", "动车"]
        ) {
            return .train
        }

        if containsKeyword(in: text, keywords: ["interview", "面试"]) {
            return .interview
        }

        if containsKeyword(in: text, keywords: ["deadline", "due", "截止"]) {
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
        keywords.contains { text.contains($0) }
    }
}
