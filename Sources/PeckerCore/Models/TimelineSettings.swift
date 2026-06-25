import Foundation

public struct TimelineSettings: Codable, Equatable, Sendable {
    public var calendarEnabled: Bool
    public var remindersEnabled: Bool
    public var showTravelEvents: Bool
    public var manualPinnedSourceIdentifier: String?
    public var liveActivityEnabled: Bool
    public var aiRecognitionMode: AIRecognitionMode
    public var openAIHost: String
    public var openAIModel: String
    public var openAIAPIKeyConfigured: Bool
    public var syncCalendarToStorage: Bool
    public var syncRemindersToStorage: Bool

    public init(
        calendarEnabled: Bool = true,
        remindersEnabled: Bool = true,
        showTravelEvents: Bool = true,
        manualPinnedSourceIdentifier: String? = nil,
        liveActivityEnabled: Bool = false,
        aiRecognitionMode: AIRecognitionMode = .off,
        openAIHost: String = "https://api.openai.com",
        openAIModel: String = "gpt-5.4-mini",
        openAIAPIKeyConfigured: Bool = false,
        syncCalendarToStorage: Bool = false,
        syncRemindersToStorage: Bool = false
    ) {
        self.calendarEnabled = calendarEnabled
        self.remindersEnabled = remindersEnabled
        self.showTravelEvents = showTravelEvents
        self.manualPinnedSourceIdentifier = manualPinnedSourceIdentifier
        self.liveActivityEnabled = liveActivityEnabled
        self.aiRecognitionMode = aiRecognitionMode
        self.openAIHost = openAIHost
        self.openAIModel = openAIModel
        self.openAIAPIKeyConfigured = openAIAPIKeyConfigured
        self.syncCalendarToStorage = syncCalendarToStorage
        self.syncRemindersToStorage = syncRemindersToStorage
    }

    private enum CodingKeys: String, CodingKey {
        case calendarEnabled
        case remindersEnabled
        case showTravelEvents
        case manualPinnedSourceIdentifier
        case liveActivityEnabled
        case aiRecognitionMode
        case openAIHost
        case openAIModel
        case openAIAPIKeyConfigured
        case syncCalendarToStorage
        case syncRemindersToStorage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            calendarEnabled: try container.decodeIfPresent(Bool.self, forKey: .calendarEnabled) ?? true,
            remindersEnabled: try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true,
            showTravelEvents: try container.decodeIfPresent(Bool.self, forKey: .showTravelEvents) ?? true,
            manualPinnedSourceIdentifier: try container.decodeIfPresent(String.self, forKey: .manualPinnedSourceIdentifier),
            liveActivityEnabled: try container.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? false,
            aiRecognitionMode: try container.decodeIfPresent(AIRecognitionMode.self, forKey: .aiRecognitionMode) ?? .off,
            openAIHost: try container.decodeIfPresent(String.self, forKey: .openAIHost) ?? "https://api.openai.com",
            openAIModel: try container.decodeIfPresent(String.self, forKey: .openAIModel) ?? "gpt-5.4-mini",
            openAIAPIKeyConfigured: try container.decodeIfPresent(Bool.self, forKey: .openAIAPIKeyConfigured) ?? false,
            syncCalendarToStorage: try container.decodeIfPresent(Bool.self, forKey: .syncCalendarToStorage) ?? false,
            syncRemindersToStorage: try container.decodeIfPresent(Bool.self, forKey: .syncRemindersToStorage) ?? false
        )
    }
}
