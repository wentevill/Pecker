import ActivityKit
import Foundation

public struct PeckerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public let itemIdentifier: String
        public let title: String
        public let secondaryIdentity: String?
        public let kindRawValue: String
        public let symbolName: String
        public let statusRawValue: String
        public let startDate: Date?
        public let endDate: Date?
        public let leadingEndpoint: String?
        public let trailingEndpoint: String?
        public let location: String?
        public let supportingDetail: String?
        public let metadata: [String]
        public let generatedAt: Date

        public init(
            itemIdentifier: String,
            title: String,
            secondaryIdentity: String?,
            kindRawValue: String,
            symbolName: String,
            statusRawValue: String,
            startDate: Date?,
            endDate: Date?,
            leadingEndpoint: String?,
            trailingEndpoint: String?,
            location: String?,
            supportingDetail: String?,
            metadata: [String],
            generatedAt: Date
        ) {
            self.itemIdentifier = itemIdentifier
            self.title = title
            self.secondaryIdentity = secondaryIdentity
            self.kindRawValue = kindRawValue
            self.symbolName = symbolName
            self.statusRawValue = statusRawValue
            self.startDate = startDate
            self.endDate = endDate
            self.leadingEndpoint = leadingEndpoint
            self.trailingEndpoint = trailingEndpoint
            self.location = location
            self.supportingDetail = supportingDetail
            self.metadata = Array(
                metadata
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .prefix(4)
            )
            self.generatedAt = generatedAt
        }

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
            generatedAt: Date,
            primaryStatusRawValue: String = "now"
        ) {
            self.init(
                itemIdentifier: primarySourceIdentifier ?? primaryTitle,
                title: primaryTitle,
                secondaryIdentity: primarySubtitle,
                kindRawValue: primaryKindRawValue,
                symbolName: Self.symbolName(for: primaryKindRawValue),
                statusRawValue: primaryStatusRawValue,
                startDate: primaryStartDate,
                endDate: primaryEndDate,
                leadingEndpoint: nil,
                trailingEndpoint: nil,
                location: nil,
                supportingDetail: primarySubtitle,
                metadata: [],
                generatedAt: generatedAt
            )
        }

        public func countdownTargetDate(at date: Date) -> Date? {
            if let startDate,
               let endDate,
               startDate <= date,
               endDate > date
            {
                return endDate
            }

            if let startDate, startDate > date
            {
                return startDate
            }

            return nil
        }

        public func isPrimaryRunning(at date: Date) -> Bool {
            guard let startDate, let endDate
            else {
                return false
            }

            return startDate <= date && endDate > date
        }

        public func hasEnded(at date: Date) -> Bool {
            guard let endDate else {
                return false
            }
            return date >= endDate
        }

        public var primaryTitle: String { title }
        public var primarySubtitle: String? {
            secondaryIdentity ?? location ?? supportingDetail
        }
        public var primaryStartDate: Date? { startDate }
        public var primaryEndDate: Date? { endDate }
        public var primaryKindRawValue: String { kindRawValue }
        public var primarySourceIdentifier: String? { itemIdentifier }
        public var primaryStatusRawValue: String { statusRawValue }
        public var nextTitle: String? { nil }
        public var nextStartDate: Date? { nil }
        public var pinnedTitle: String? { nil }
        public var pinnedSubtitle: String? { nil }
        public var additionalActiveCount: Int { 0 }

        private static func symbolName(for kindRawValue: String) -> String {
            switch kindRawValue {
            case "meeting":
                "person.2.fill"
            case "task":
                "checklist"
            case "flight":
                "airplane"
            case "train":
                "train.side.front.car"
            case "travel":
                "suitcase.fill"
            case "interview":
                "person.text.rectangle"
            case "deadline":
                "calendar.badge.exclamationmark"
            default:
                "clock.fill"
            }
        }
    }

    public let localDayIdentifier: String

    public init(localDayIdentifier: String) {
        self.localDayIdentifier = localDayIdentifier
    }
}
