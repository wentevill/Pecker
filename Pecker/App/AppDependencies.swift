import Foundation
import PeckerCore
import UserNotifications

protocol SnapshotStoring: Sendable {
    func load() async -> SnapshotLoadResult
    func save(_ snapshot: TodaySnapshot) async throws
}

extension SnapshotStore: SnapshotStoring {}

struct PendingTimelineNotification: Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

enum TimelineNotificationPlan {
    static let identifierPrefix = "pecker.timeline."

    static func make(
        items: [TimelineItem],
        settings: TimelineSettings,
        now: Date
    ) -> [PendingTimelineNotification] {
        guard settings.notificationsEnabled else {
            return []
        }

        return items
            .filter { !$0.isCompleted && !$0.isAllDay }
            .compactMap { item in
                let fireDate = item.startDate.addingTimeInterval(
                    -settings.notificationLeadTime.interval
                )
                guard fireDate > now else {
                    return nil
                }
                return PendingTimelineNotification(
                    id: notificationIdentifier(for: item),
                    title: item.title,
                    body: "Pecker reminder",
                    fireDate: fireDate
                )
            }
            .sorted { lhs, rhs in
                if lhs.fireDate != rhs.fireDate {
                    return lhs.fireDate < rhs.fireDate
                }
                return lhs.id < rhs.id
            }
    }

    private static func notificationIdentifier(for item: TimelineItem) -> String {
        "\(identifierPrefix)\(item.source.rawValue).\(sanitized(item.sourceIdentifier))"
    }

    private static func sanitized(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        .reduce(into: "") { $0.append($1) }
    }
}

protocol TimelineNotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func schedule(
        snapshot: TodaySnapshot,
        settings: TimelineSettings,
        now: Date
    ) async
    func cancelPendingTimelineNotifications() async
}

struct UserNotificationScheduler: TimelineNotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.center = center
        self.calendar = calendar
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(
        snapshot: TodaySnapshot,
        settings: TimelineSettings,
        now: Date
    ) async {
        await cancelPendingTimelineNotifications()
        let pending = TimelineNotificationPlan.make(
            items: snapshot.items,
            settings: settings,
            now: now
        )
        for notification in pending {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: notification.fireDate
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: notification.id,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelPendingTimelineNotifications() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(TimelineNotificationPlan.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

enum AppDependenciesError: Error {
    case appGroupContainerUnavailable
}

@MainActor
struct AppDependencies {
    let gateway: any EventKitGatewayProtocol
    let mapper: EventKitMapper
    let engine: TimelineEngine
    let snapshotStore: any SnapshotStoring
    let settingsStore: SettingsStore
    let calendar: Calendar
    let activityCoordinator: ActivityCoordinator
    let systemEventRecognizer: any SystemEventRecognizing
    let imageRecognizer: any ImageRecognizing
    let localTimelineCards: any LocalTimelineCardManaging
    let notificationScheduler: any TimelineNotificationScheduling

    init(
        gateway: any EventKitGatewayProtocol,
        mapper: EventKitMapper,
        engine: TimelineEngine,
        snapshotStore: any SnapshotStoring,
        settingsStore: SettingsStore,
        calendar: Calendar,
        activityClient: any ActivityClient = LiveActivityClient(),
        systemEventRecognizer: (any SystemEventRecognizing)? = nil,
        imageRecognizer: (any ImageRecognizing)? = nil,
        localTimelineCards: (any LocalTimelineCardManaging)? = nil,
        notificationScheduler: (any TimelineNotificationScheduling)? = nil
    ) {
        self.gateway = gateway
        self.mapper = mapper
        self.engine = engine
        self.snapshotStore = snapshotStore
        self.settingsStore = settingsStore
        self.calendar = calendar
        activityCoordinator = ActivityCoordinator(
            client: activityClient,
            calendar: calendar
        )
        self.systemEventRecognizer = systemEventRecognizer ?? NoopSystemEventRecognizer()
        self.imageRecognizer = imageRecognizer ?? NoopImageRecognizer()
        self.localTimelineCards =
            localTimelineCards ?? NoopLocalTimelineCardService()
        self.notificationScheduler =
            notificationScheduler ?? UserNotificationScheduler(calendar: calendar)
    }

    static func production(
        containerURLProvider: () -> URL? = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppGroup.identifier
            )
        },
        settingsStoreFactory: () throws -> SettingsStore = {
            try SettingsStore.appGroupStore()
        }
    ) throws -> AppDependencies {
        guard let containerURL = containerURLProvider() else {
            throw AppDependenciesError.appGroupContainerUnavailable
        }

        let settingsStore = try settingsStoreFactory()
        let repository = EventRepository(
            directoryURL: containerURL.appendingPathComponent(
                "EventStore",
                isDirectory: true
            )
        )

        let recognitionCoordinator = SystemEventRecognitionCoordinator(
            repository: repository,
            calendar: .autoupdatingCurrent
        )
        let imageStore = ImageRecognitionStore(directoryURL: containerURL)

        return AppDependencies(
            gateway: EventKitGateway(),
            mapper: EventKitMapper(),
            engine: TimelineEngine(),
            snapshotStore: SnapshotStore(directoryURL: containerURL),
            settingsStore: settingsStore,
            calendar: .autoupdatingCurrent,
            systemEventRecognizer: recognitionCoordinator,
            imageRecognizer: ImageRecognitionCoordinator(
                imageStore: imageStore,
                systemCoordinator: recognitionCoordinator
            ),
            localTimelineCards: LocalTimelineCardService(
                repository: repository,
                imageStore: imageStore
            )
        )
    }
}
