import Foundation
import PeckerCore
import Observation

enum SettingsStoreError: Error {
    case appGroupUnavailable
}

@MainActor
@Observable
final class SettingsStore {
    private static let storageKey = "timeline.settings.v1"
    private static let validReminderDurations = [15, 30, 45, 60]

    private let defaults: UserDefaults
    private(set) var value: TimelineSettings

    init(defaults: UserDefaults) {
        self.defaults = defaults
        value = Self.load(from: defaults)
    }

    static func appGroupStore(
        suiteProvider: (String) -> UserDefaults? = {
            UserDefaults(suiteName: $0)
        }
    ) throws -> SettingsStore {
        guard let defaults = suiteProvider(AppGroup.identifier) else {
            throw SettingsStoreError.appGroupUnavailable
        }

        return SettingsStore(defaults: defaults)
    }

    func update(_ mutation: (inout TimelineSettings) -> Void) {
        var updatedValue = value
        mutation(&updatedValue)
        Self.normalize(&updatedValue)

        guard let data = try? JSONEncoder().encode(updatedValue) else {
            return
        }

        defaults.set(data, forKey: Self.storageKey)
        value = updatedValue
    }

    private static func load(from defaults: UserDefaults) -> TimelineSettings {
        guard
            let data = defaults.data(forKey: storageKey),
            var settings = try? JSONDecoder().decode(
                TimelineSettings.self,
                from: data
            )
        else {
            return TimelineSettings()
        }

        normalize(&settings)
        return settings
    }

    private static func normalize(_ settings: inout TimelineSettings) {
        guard
            validReminderDurations.contains(
                settings.reminderDurationMinutes
            )
        else {
            settings.reminderDurationMinutes = 30
            return
        }
    }
}
