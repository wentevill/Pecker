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
        public let localeIdentifier: String?
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
            localeIdentifier: String? = nil,
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
            self.localeIdentifier = localeIdentifier
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
            localeIdentifier: String? = nil,
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
                localeIdentifier: localeIdentifier,
                generatedAt: generatedAt
            )
        }

        private enum CodingKeys: String, CodingKey {
            case itemIdentifier
            case title
            case secondaryIdentity
            case kindRawValue
            case symbolName
            case statusRawValue
            case startDate
            case endDate
            case leadingEndpoint
            case trailingEndpoint
            case location
            case supportingDetail
            case metadata
            case localeIdentifier
            case generatedAt
            case primaryTitle
            case primarySubtitle
            case primaryStartDate
            case primaryEndDate
            case primaryKindRawValue
            case primarySourceIdentifier
            case primaryStatusRawValue
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.itemIdentifier) {
                self.init(
                    itemIdentifier: try container.decode(
                        String.self,
                        forKey: .itemIdentifier
                    ),
                    title: try container.decode(String.self, forKey: .title),
                    secondaryIdentity: try container.decodeIfPresent(
                        String.self,
                        forKey: .secondaryIdentity
                    ),
                    kindRawValue: try container.decode(
                        String.self,
                        forKey: .kindRawValue
                    ),
                    symbolName: try container.decode(
                        String.self,
                        forKey: .symbolName
                    ),
                    statusRawValue: try container.decode(
                        String.self,
                        forKey: .statusRawValue
                    ),
                    startDate: try container.decodeIfPresent(
                        Date.self,
                        forKey: .startDate
                    ),
                    endDate: try container.decodeIfPresent(
                        Date.self,
                        forKey: .endDate
                    ),
                    leadingEndpoint: try container.decodeIfPresent(
                        String.self,
                        forKey: .leadingEndpoint
                    ),
                    trailingEndpoint: try container.decodeIfPresent(
                        String.self,
                        forKey: .trailingEndpoint
                    ),
                    location: try container.decodeIfPresent(
                        String.self,
                        forKey: .location
                    ),
                    supportingDetail: try container.decodeIfPresent(
                        String.self,
                        forKey: .supportingDetail
                    ),
                    metadata: try container.decodeIfPresent(
                        [String].self,
                        forKey: .metadata
                    ) ?? [],
                    localeIdentifier: try container.decodeIfPresent(
                        String.self,
                        forKey: .localeIdentifier
                    ),
                    generatedAt: try container.decode(
                        Date.self,
                        forKey: .generatedAt
                    )
                )
                return
            }

            let title = try container.decode(
                String.self,
                forKey: .primaryTitle
            )
            let kind = try container.decodeIfPresent(
                String.self,
                forKey: .primaryKindRawValue
            ) ?? "unknown"
            let subtitle = try container.decodeIfPresent(
                String.self,
                forKey: .primarySubtitle
            )
            self.init(
                itemIdentifier: try container.decodeIfPresent(
                    String.self,
                    forKey: .primarySourceIdentifier
                ) ?? title,
                title: title,
                secondaryIdentity: nil,
                kindRawValue: kind,
                symbolName: Self.symbolName(for: kind),
                statusRawValue: try container.decodeIfPresent(
                    String.self,
                    forKey: .primaryStatusRawValue
                ) ?? "now",
                startDate: try container.decodeIfPresent(
                    Date.self,
                    forKey: .primaryStartDate
                ),
                endDate: try container.decodeIfPresent(
                    Date.self,
                    forKey: .primaryEndDate
                ),
                leadingEndpoint: nil,
                trailingEndpoint: nil,
                location: subtitle,
                supportingDetail: nil,
                metadata: [],
                localeIdentifier: try container.decodeIfPresent(
                    String.self,
                    forKey: .localeIdentifier
                ),
                generatedAt: try container.decode(
                    Date.self,
                    forKey: .generatedAt
                )
            )
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(itemIdentifier, forKey: .itemIdentifier)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(
                secondaryIdentity,
                forKey: .secondaryIdentity
            )
            try container.encode(kindRawValue, forKey: .kindRawValue)
            try container.encode(symbolName, forKey: .symbolName)
            try container.encode(statusRawValue, forKey: .statusRawValue)
            try container.encodeIfPresent(startDate, forKey: .startDate)
            try container.encodeIfPresent(endDate, forKey: .endDate)
            try container.encodeIfPresent(
                leadingEndpoint,
                forKey: .leadingEndpoint
            )
            try container.encodeIfPresent(
                trailingEndpoint,
                forKey: .trailingEndpoint
            )
            try container.encodeIfPresent(location, forKey: .location)
            try container.encodeIfPresent(
                supportingDetail,
                forKey: .supportingDetail
            )
            try container.encode(metadata, forKey: .metadata)
            try container.encodeIfPresent(
                localeIdentifier,
                forKey: .localeIdentifier
            )
            try container.encode(generatedAt, forKey: .generatedAt)
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
        public var locale: Locale {
            localeIdentifier.map(Locale.init(identifier:)) ?? .autoupdatingCurrent
        }
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
