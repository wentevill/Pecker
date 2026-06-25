import Foundation
import PeckerCore

protocol SnapshotStoring: Sendable {
    func load() async -> SnapshotLoadResult
    func save(_ snapshot: TodaySnapshot) async throws
}

extension SnapshotStore: SnapshotStoring {}

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

    init(
        gateway: any EventKitGatewayProtocol,
        mapper: EventKitMapper,
        engine: TimelineEngine,
        snapshotStore: any SnapshotStoring,
        settingsStore: SettingsStore,
        calendar: Calendar,
        activityClient: any ActivityClient = LiveActivityClient(),
        systemEventRecognizer: (any SystemEventRecognizing)? = nil,
        imageRecognizer: (any ImageRecognizing)? = nil
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
            repository: repository
        )

        return AppDependencies(
            gateway: EventKitGateway(),
            mapper: EventKitMapper(),
            engine: TimelineEngine(),
            snapshotStore: SnapshotStore(directoryURL: containerURL),
            settingsStore: settingsStore,
            calendar: .autoupdatingCurrent,
            systemEventRecognizer: recognitionCoordinator,
            imageRecognizer: ImageRecognitionCoordinator(
                imageStore: ImageRecognitionStore(directoryURL: containerURL),
                systemCoordinator: recognitionCoordinator
            )
        )
    }
}
