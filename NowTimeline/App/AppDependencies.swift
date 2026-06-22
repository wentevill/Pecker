import Foundation
import NowTimelineCore

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

    init(
        gateway: any EventKitGatewayProtocol,
        mapper: EventKitMapper,
        engine: TimelineEngine,
        snapshotStore: any SnapshotStoring,
        settingsStore: SettingsStore,
        calendar: Calendar
    ) {
        self.gateway = gateway
        self.mapper = mapper
        self.engine = engine
        self.snapshotStore = snapshotStore
        self.settingsStore = settingsStore
        self.calendar = calendar
    }

    static func production(
        fileManager: FileManager = .default
    ) throws -> AppDependencies {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            throw AppDependenciesError.appGroupContainerUnavailable
        }

        return AppDependencies(
            gateway: EventKitGateway(),
            mapper: EventKitMapper(),
            engine: TimelineEngine(),
            snapshotStore: SnapshotStore(directoryURL: containerURL),
            settingsStore: try SettingsStore.appGroupStore(),
            calendar: .autoupdatingCurrent
        )
    }
}
