import Foundation
import UserNotifications

/// CopyLab SDK for iOS
/// Handles interaction with the CopyLab notification system via secure API.
public enum CopyLab {
    
    // MARK: - Private State
    
    private static var apiKey: String?
    private static var identifiedUserId: String?
    private static var baseURL = "https://us-central1-copylab-3f220.cloudfunctions.net"
    
    private static let userDefaults = UserDefaults.standard
    private static let installIdKey = "copylab_install_id"
    
    /// SDK Version
    public static let sdkVersion = "2.5.1"
    
    private static var pendingActions: [() -> Void] = []
    
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    
    // MARK: - Configuration
    
    /// Configure CopyLab with an API Key.
    /// This connects to the CopyLab backend using secure HTTPS API calls.
    /// Call this in your AppDelegate or App init.
    ///
    /// - Parameter apiKey: Your CopyLab API Key (starts with cl_)
    public static func configure(apiKey: String) {
        self.apiKey = apiKey
        print("✅ CopyLab: Configured with API Key: \(apiKey.prefix(15))...")
    }
    
    /// Set a custom base URL for the API (useful for testing).
    public static func setBaseURL(_ url: String) {
        self.baseURL = url
    }
    
    /// Identify the current user with their User ID from your system.
    /// Call this after your user logs in.
    ///
    /// - Parameter userId: The unique ID of the user in your database.
    public static func identify(userId: String) {
        self.identifiedUserId = userId
        print("👤 CopyLab: Identified user: \(userId)")
        
        // Execute pending actions now that we have an identity
        let actions = pendingActions
        pendingActions = []
        for action in actions {
            action()
        }
        
        // Sync permission status immediately when user is identified
        syncNotificationPermissionStatus()
    }
    
    /// Clear the identified user. Call this on logout.
    public static func logout() {
        self.identifiedUserId = nil
        print("👤 CopyLab: Logged out user")
    }
    
    // MARK: - Private Helpers
    
    /// Returns the Install ID (Anonymous ID) for this device.
    private static var installId: String {
        if let existingId = userDefaults.string(forKey: installIdKey) {
            return existingId
        }
        let newId = UUID().uuidString
        userDefaults.set(newId, forKey: installIdKey)
        return newId
    }
    
    /// Returns the effective User ID (Identified User or Install ID).
    private static var currentUserId: String {
        return identifiedUserId ?? installId
    }
    
    /// Extracts the App ID from the API key.
    private static var appId: String {
        guard let key = apiKey else { return "unknown" }
        let components = key.split(separator: "_")
        if components.count >= 2 {
            return String(components[1])
        }
        return "unknown"
    }
    
    // MARK: - API Request Helper
    
    private static func makeAPIRequest(
        endpoint: String,
        method: String = "POST",
        body: [String: Any]? = nil,
        completion: ((Result<[String: Any], Error>) -> Void)? = nil
    ) {
        guard let apiKey = apiKey else {
            print("⚠️ CopyLab: API Key not configured")
            completion?(.failure(CopyLabError.notConfigured))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            print("⚠️ CopyLab: Invalid URL for endpoint: \(endpoint)")
            completion?(.failure(CopyLabError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("⚠️ CopyLab: API error for \(endpoint): \(error.localizedDescription)")
                completion?(.failure(error))
                return
            }
            
            guard let data = data else {
                completion?(.failure(CopyLabError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorMessage = json["error"] as? String {
                        completion?(.failure(CopyLabError.apiError(errorMessage)))
                    } else {
                        completion?(.success(json))
                    }
                } else {
                    completion?(.failure(CopyLabError.invalidResponse))
                }
            } catch {
                completion?(.failure(error))
            }
        }.resume()
    }
    
    /// Generic API request helper for Decodable types
    private static func makeDecodableAPIRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let apiKey = apiKey else {
            print("⚠️ CopyLab: API Key not configured")
            completion(.failure(CopyLabError.notConfigured))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            print("⚠️ CopyLab: Invalid URL for endpoint: \(endpoint)")
            completion(.failure(CopyLabError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(CopyLabError.noData))
                return
            }
            
            // Check for error response first
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                completion(.failure(CopyLabError.apiError(errorMessage)))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                print("⚠️ CopyLab: Decoding error for \(endpoint): \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Push Notification Logging
    
    /// Logs a push notification open event to CopyLab analytics.
    /// This should be called when a user taps on a notification.
    ///
    /// - Parameter userInfo: The userInfo dictionary from the notification response.
    public static func logPushOpen(userInfo: [AnyHashable: Any]) {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing push open log until user is identified")
            pendingActions.append { logPushOpen(userInfo: userInfo) }
            return
        }
        
        var body: [String: Any] = [
            "user_id": currentUserId,
            "platform": "ios",
            "type": (userInfo["type"] as? String) ?? (userInfo["notification_type"] as? String) ?? "unknown"
        ]
        
        // Add CopyLab metadata
        if let notificationId = userInfo["notification_id"] as? String {
            body["notification_id"] = notificationId
        }
        if let placementId = userInfo["copylab_placement_id"] as? String {
            body["placement_id"] = placementId
        }
        if let placementName = userInfo["copylab_placement_name"] as? String {
            body["placement_name"] = placementName
        }
        if let templateId = userInfo["copylab_template_id"] as? String {
            body["template_id"] = templateId
        }
        if let templateName = userInfo["copylab_template_name"] as? String {
            body["template_name"] = templateName
        }
        
        makeAPIRequest(endpoint: "log_push_open", body: body) { result in
            switch result {
            case .success:
                print("📊 CopyLab: Logged push_open event")
            case .failure(let error):
                print("⚠️ CopyLab: Error logging push_open: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Topic Subscriptions
    
    /// Subscribes the current user to a CopyLab topic.
    ///
    /// - Parameter topicId: The topic ID (e.g., "chat_community_chat_alerts")
    public static func subscribeToTopic(_ topicId: String) {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing subscription to \(topicId) until user is identified")
            pendingActions.append { subscribeToTopic(topicId) }
            return
        }
        
        let body: [String: Any] = [
            "topic_id": topicId,
            "user_id": currentUserId
        ]
        
        makeAPIRequest(endpoint: "subscribe_to_topic", body: body) { result in
            switch result {
            case .success:
                print("📊 CopyLab: Subscribed to topic \(topicId)")
            case .failure(let error):
                print("⚠️ CopyLab: Error subscribing to topic \(topicId): \(error.localizedDescription)")
            }
        }
    }
    
    /// Unsubscribes the current user from a CopyLab topic.
    ///
    /// - Parameter topicId: The topic ID
    public static func unsubscribeFromTopic(_ topicId: String) {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing unsubscription from \(topicId) until user is identified")
            pendingActions.append { unsubscribeFromTopic(topicId) }
            return
        }
        
        let body: [String: Any] = [
            "topic_id": topicId,
            "user_id": currentUserId
        ]
        
        makeAPIRequest(endpoint: "unsubscribe_from_topic", body: body) { result in
            switch result {
            case .success:
                print("📊 CopyLab: Unsubscribed from topic \(topicId)")
            case .failure(let error):
                print("⚠️ CopyLab: Error unsubscribing from topic \(topicId): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notification Permission Tracking
    
    /// Checks the current iOS notification permission status and syncs it to CopyLab.
    /// Call on app launch, when app enters foreground, and after requesting permissions.
    public static func syncNotificationPermissionStatus() {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing permission sync until user is identified")
            pendingActions.append { syncNotificationPermissionStatus() }
            return
        }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let statusString: String
            switch settings.authorizationStatus {
            case .authorized: statusString = "authorized"
            case .denied: statusString = "denied"
            case .notDetermined: statusString = "notDetermined"
            case .provisional: statusString = "provisional"
            case .ephemeral: statusString = "ephemeral"
            @unknown default: statusString = "unknown"
            }
            
            let body: [String: Any] = [
                "user_id": currentUserId,
                "notification_status": statusString,
                "platform": "ios"
            ]
            
            makeAPIRequest(endpoint: "sync_notification_permission", body: body) { result in
                switch result {
                case .success:
                    print("📊 CopyLab: Synced notification status: \(statusString)")
                case .failure(let error):
                    print("⚠️ CopyLab: Error syncing notification status: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Logs when the app is opened.
    /// Used for calculating influenced attribution.
    public static func logAppOpen() {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing app open log until user is identified")
            pendingActions.append { logAppOpen() }
            return
        }
        
        let body: [String: Any] = [
            "user_id": currentUserId,
            "platform": "ios"
        ]
        
        makeAPIRequest(endpoint: "log_app_open", body: body) { result in
            switch result {
            case .success:
                print("📱 CopyLab: Logged app open")
            case .failure(let error):
                print("⚠️ CopyLab: Error logging app open: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Subscription Status
    
    /// Updates the user's in-app purchase subscription status.
    /// Call this when the user's subscription changes (purchase, renewal, expiration).
    ///
    /// - Parameters:
    ///   - isSubscribed: Whether the user has an active subscription
    ///   - tier: Optional subscription tier (e.g., "premium", "pro")
    ///   - expiresAt: Optional expiration date
    public static func updateSubscriptionStatus(
        isSubscribed: Bool,
        tier: String? = nil,
        expiresAt: Date? = nil
    ) {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing subscription status update until user is identified")
            pendingActions.append { updateSubscriptionStatus(isSubscribed: isSubscribed, tier: tier, expiresAt: expiresAt) }
            return
        }
        
        var body: [String: Any] = [
            "user_id": currentUserId,
            "is_subscribed": isSubscribed,
            "platform": "ios"
        ]
        
        if let tier = tier {
            body["subscription_tier"] = tier
        }
        
        if let expiresAt = expiresAt {
            let formatter = ISO8601DateFormatter()
            body["expires_at"] = formatter.string(from: expiresAt)
        }
        
        makeAPIRequest(endpoint: "update_subscription_status", body: body) { result in
            switch result {
            case .success:
                print("💳 CopyLab: Updated subscription status: \(isSubscribed ? "active" : "inactive")")
            case .failure(let error):
                print("⚠️ CopyLab: Error updating subscription status: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Notification Preferences
    
    /// Fetches the current user's notification preferences.
    /// - Parameter completion: Callback with the user's preferences or an error
    public static func getNotificationPreferences(completion: @escaping (Result<NotificationPreferences, Error>) -> Void) {
        guard let userId = identifiedUserId else {
            print("⚠️ CopyLab: User not identified. Call identify(userId:) first.")
            completion(.failure(CopyLabError.notConfigured))
            return
        }
        
        makeDecodableAPIRequest(endpoint: "get_notification_preferences?user_id=\(userId)", completion: completion)
    }
    
    /// Updates the current user's schedule preferences.
    /// - Parameters:
    ///   - schedules: Dictionary of schedule_id -> enabled state (only schedules being changed)
    ///   - scheduleTimes: Dictionary of schedule_id -> time string "HH:mm" (optional)
    ///   - completion: Callback with success or error
    public static func updateNotificationPreferences(
        schedules: [String: Bool] = [:],
        scheduleTimes: [String: String] = [:],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard identifiedUserId != nil else {
            print("⚠️ CopyLab: User not identified. Call identify(userId:) first.")
            completion(.failure(CopyLabError.notConfigured))
            return
        }
        
        var body: [String: Any] = [
            "user_id": currentUserId
        ]
        
        if !schedules.isEmpty {
            body["schedules"] = schedules
        }
        
        if !scheduleTimes.isEmpty {
            body["schedule_times"] = scheduleTimes
            // Include timezone for server-side scheduling
            body["timezone"] = TimeZone.current.identifier
        }
        
        makeAPIRequest(endpoint: "update_notification_preferences", body: body) { result in
            switch result {
            case .success:
                print("📬 CopyLab: Updated notification preferences")
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Fetches the preference center configuration for the app.
    /// This returns the structure needed to build the preference center UI.
    /// - Parameter completion: Callback with the config or an error
    public static func getPreferenceCenterConfig(completion: @escaping (Result<PreferenceCenterConfig, Error>) -> Void) {
        makeDecodableAPIRequest(endpoint: "get_notification_center_config", completion: completion)
    }
    
    /// Updates the current user's preference states (for preference-gated placements).
    /// - Parameters:
    ///   - preferences: Dictionary of preference_id -> enabled state
    ///   - completion: Callback with success or error
    public static func updateUserPreferences(
        preferences: [String: Bool],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard identifiedUserId != nil else {
            print("⚠️ CopyLab: User not identified. Call identify(userId:) first.")
            completion(.failure(CopyLabError.notConfigured))
            return
        }
        
        let body: [String: Any] = [
            "user_id": currentUserId,
            "preferences": preferences
        ]
        
        makeAPIRequest(endpoint: "update_user_preferences", body: body) { result in
            switch result {
            case .success:
                print("📬 CopyLab: Updated user preferences")
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Async/Await Wrappers
    
    /// Async version of getNotificationPreferences
    @available(iOS 13.0, macOS 10.15, *)
    public static func getNotificationPreferences() async throws -> NotificationPreferences {
        try await withCheckedThrowingContinuation { continuation in
            getNotificationPreferences { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Async version of updateNotificationPreferences
    @available(iOS 13.0, macOS 10.15, *)
    public static func updateNotificationPreferences(schedules: [String: Bool]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            updateNotificationPreferences(schedules: schedules) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Async version of getPreferenceCenterConfig
    @available(iOS 13.0, macOS 10.15, *)
    public static func getPreferenceCenterConfig() async throws -> PreferenceCenterConfig {
        try await withCheckedThrowingContinuation { continuation in
            getPreferenceCenterConfig { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Error Types

public enum CopyLabError: LocalizedError {
    case notConfigured
    case invalidURL
    case noData
    case invalidResponse
    case apiError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "CopyLab SDK not configured. Call CopyLab.configure(apiKey:) first."
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from API"
        case .invalidResponse:
            return "Invalid response format from API"
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
}
