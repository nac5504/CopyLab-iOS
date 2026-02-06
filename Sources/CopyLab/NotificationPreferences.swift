import Foundation

// MARK: - Notification Preferences Models

/// Topic type - determines visibility behavior in preference center
public enum TopicType: String, Codable, Sendable {
    /// Always visible in preference center regardless of subscription status
    case persistent
    /// Only shown when user is subscribed; disappears when they unsubscribe
    case contextual
}

/// User's notification preferences returned from the API
public struct NotificationPreferences: Codable, Sendable {
    /// iOS notification permission status (authorized, denied, notDetermined, provisional)
    public let osPermission: String
    /// List of subscribed topic IDs
    public let topics: [String]
    /// Schedule toggles (schedule_id -> enabled)
    public let schedules: [String: Bool]
    /// User's preferred times for schedules (schedule_id -> "HH:mm")
    public let scheduleTimes: [String: String]
    /// Generic preference toggles (preference_id -> enabled)
    public let preferences: [String: Bool]
    /// User's timezone identifier (e.g., "America/New_York")
    public let timezone: String?
    
    enum CodingKeys: String, CodingKey {
        case osPermission = "os_permission"
        case topics
        case schedules
        case scheduleTimes = "schedule_times"
        case preferences
        case timezone
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        osPermission = try container.decode(String.self, forKey: .osPermission)
        topics = try container.decodeIfPresent([String].self, forKey: .topics) ?? []
        schedules = try container.decodeIfPresent([String: Bool].self, forKey: .schedules) ?? [:]
        scheduleTimes = try container.decodeIfPresent([String: String].self, forKey: .scheduleTimes) ?? [:]
        preferences = try container.decodeIfPresent([String: Bool].self, forKey: .preferences) ?? [:]
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
    }
}

/// A topic/category that users can subscribe to
public struct NotificationTopic: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let type: TopicType
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, type
    }
    
    public init(id: String, title: String, description: String = "", type: TopicType = .persistent) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        type = try container.decodeIfPresent(TopicType.self, forKey: .type) ?? .persistent
    }
}

/// A notification schedule that users can toggle
public struct NotificationSchedule: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let enabledByDefault: Bool
    /// Whether users can configure a custom time for this schedule
    public let timeConfigurable: Bool
    /// Default time (HH:mm format) if user hasn't set one
    public let defaultTime: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case enabledByDefault = "enabled_by_default"
        case timeConfigurable = "time_configurable"
        case defaultTime = "default_time"
    }
    
    public init(id: String, title: String, description: String = "", enabledByDefault: Bool = true, timeConfigurable: Bool = false, defaultTime: String = "09:00") {
        self.id = id
        self.title = title
        self.description = description
        self.enabledByDefault = enabledByDefault
        self.timeConfigurable = timeConfigurable
        self.defaultTime = defaultTime
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        enabledByDefault = try container.decodeIfPresent(Bool.self, forKey: .enabledByDefault) ?? true
        timeConfigurable = try container.decodeIfPresent(Bool.self, forKey: .timeConfigurable) ?? false
        defaultTime = try container.decodeIfPresent(String.self, forKey: .defaultTime) ?? "09:00"
    }
}

/// Parameters for a preference item
public struct PreferenceParameters: Codable, Sendable {
    public let schedule: PreferenceScheduleParameter?
}

/// Schedule parameter details
public struct PreferenceScheduleParameter: Codable, Sendable {
    public let defaultTime: String?
    
    enum CodingKeys: String, CodingKey {
        case defaultTime = "default_time"
    }
}

/// Section type in the preference center config
public enum PreferenceCenterSectionType: String, Codable, Sendable {
    case systemPermissionCard = "system_permission_card"
    case preferences
    case topics
    case schedules
}

/// A section in the preference center config
public struct PreferenceCenterSection: Codable, Sendable {
    public let type: PreferenceCenterSectionType
    public let items: [PreferenceCenterItem]?
    
    public init(type: PreferenceCenterSectionType, items: [PreferenceCenterItem]? = nil) {
        self.type = type
        self.items = items
    }
}

/// An item within a preference center section (topic or schedule)
public struct PreferenceCenterItem: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    /// Topic type (persistent/contextual) - only for topics
    public let type: TopicType?
    /// Whether enabled by default - only for schedules
    public let enabledByDefault: Bool?
    /// Whether time is configurable - only for schedules
    public let timeConfigurable: Bool?
    /// Default time - only for schedules
    public let defaultTime: String?
    /// Custom parameters (e.g. nested schedule config)
    public let parameters: PreferenceParameters?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case type
        case enabledByDefault = "enabled_by_default"
        case timeConfigurable = "time_configurable"
        case defaultTime = "default_time"
        case parameters
    }
    
    public init(id: String, title: String, description: String = "", type: TopicType? = nil, enabledByDefault: Bool? = nil, timeConfigurable: Bool? = nil, defaultTime: String? = nil, parameters: PreferenceParameters? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.enabledByDefault = enabledByDefault
        self.timeConfigurable = timeConfigurable
        self.defaultTime = defaultTime
        self.parameters = parameters
    }
}

/// The complete preference center configuration returned from the API
public struct PreferenceCenterConfig: Codable, Sendable {
    public let version: String
    public let sections: [PreferenceCenterSection]
    
    public init(version: String = "1.0", sections: [PreferenceCenterSection] = []) {
        self.version = version
        self.sections = sections
    }
}
