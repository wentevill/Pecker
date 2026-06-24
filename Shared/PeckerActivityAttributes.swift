import ActivityKit
import Foundation

public struct PeckerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public let primaryTitle: String
        public let primarySubtitle: String?
        public let primaryStartDate: Date?
        public let primaryEndDate: Date?
        public let primaryKindRawValue: String
        public let primarySourceIdentifier: String?
        public let nextTitle: String?
        public let nextStartDate: Date?
        public let pinnedTitle: String?
        public let pinnedSubtitle: String?
        public let additionalActiveCount: Int
        public let generatedAt: Date

        public init(
            primaryTitle: String,
            primarySubtitle: String?,
            primaryStartDate: Date?,
            primaryEndDate: Date?,
            primaryKindRawValue: String,
            primarySourceIdentifier: String?,
            nextTitle: String?,
            nextStartDate: Date?,
            pinnedTitle: String?,
            pinnedSubtitle: String?,
            additionalActiveCount: Int,
            generatedAt: Date
        ) {
            self.primaryTitle = primaryTitle
            self.primarySubtitle = primarySubtitle
            self.primaryStartDate = primaryStartDate
            self.primaryEndDate = primaryEndDate
            self.primaryKindRawValue = primaryKindRawValue
            self.primarySourceIdentifier = primarySourceIdentifier
            self.nextTitle = nextTitle
            self.nextStartDate = nextStartDate
            self.pinnedTitle = pinnedTitle
            self.pinnedSubtitle = pinnedSubtitle
            self.additionalActiveCount = additionalActiveCount
            self.generatedAt = generatedAt
        }
    }

    public let localDayIdentifier: String

    public init(localDayIdentifier: String) {
        self.localDayIdentifier = localDayIdentifier
    }
}
