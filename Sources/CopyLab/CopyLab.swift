import Foundation
import UserNotifications
import UIKit

/// CopyLab SDK for iOS
/// Handles interaction with the CopyLab notification system via secure API.
public enum CopyLab {
    
    // MARK: - Private State
    
    private static var apiKey: String?
    private static var identifiedUserId: String?
    private static var baseURL = "https://us-central1-copylab-3f220.cloudfunctions.net"
    
    private static let userDefaults = UserDefaults.standard
    private static let installIdKey = "copylab_install_id"
    private static let configCacheKey = "copylab_config_cache"
    private static let prefsCacheKey = "copylab_prefs_cache"
    
    /// SDK Version
    public static let sdkVersion = "2.9.0"

    private static var pendingActions: [() -> Void] = []

    // MARK: - Metadata Collection Helpers

    /// Get app version from Bundle
    private static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    /// Get app build number from Bundle
    private static func getAppBuild() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    /// Get device timezone identifier
    private static func getTimezone() -> String {
        return TimeZone.current.identifier
    }

    /// Get device model identifier
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /// Get iOS version
    private static func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    /// Get human-readable device name
    private static func getDeviceName() -> String {
        return UIDevice.current.model
    }

    /// Get current timestamp in ISO 8601 format
    private static func getCurrentTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    
    // MARK: - Public Configuration
    
    /// Configuration for the "Disable Notifications" alert in the Preference Center
    public struct DisableNotificationsAlertConfig {
        public let title: String
        public let message: String
        public let cancelTitle: String
        public let confirmTitle: String
        
        public init(title: String, message: String, cancelTitle: String = "Cancel", confirmTitle: String = "Disable") {
            self.title = title
            self.message = message
            self.cancelTitle = cancelTitle
            self.confirmTitle = confirmTitle
        }
    }
    
    /// Current configuration for the disable notifications alert.
    /// Set this in your app configuration to customize the text.
    public static var disableNotificationsAlertConfig = DisableNotificationsAlertConfig(
        title: "Disable Notifications?",
        message: "You will miss out on important updates. Are you sure you want to disable notifications?",
        confirmTitle: "Open Settings"
    )

    #if canImport(UIKit)
    /// Current style for the PreferenceCenterView.
    /// Set this before presenting the view to customize its appearance.
    @available(iOS 14.0, *)
    public static var preferenceCenterStyle = PreferenceCenterStyle()
    #endif
    
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
    /// - Parameters:
    ///   - apiKey: Your CopyLab API Key (starts with cl_)
    ///   - pushToken: Optional FCM token to register immediately
    public static func configure(apiKey: String, pushToken: String? = nil) {
        self.apiKey = apiKey
        print("✅ CopyLab: Configured with API Key: \(apiKey.prefix(15))...")
        
        // Register token if provided
        if let token = pushToken {
            registerPushToken(token)
        }
        
        // Prefetch app configuration
        prefetchPreferenceCenterConfig()
    }
    
    /// Set a custom base URL for the API (useful for testing).
    public static func setBaseURL(_ url: String) {
        self.baseURL = url
    }
    
    /// Identify the current user with their User ID from your system.
    /// Call this after your user logs in.
    ///
    /// - Parameters:
    ///   - userId: The unique ID of the user in your database.
    ///   - pushToken: Optional FCM token to register for this user
    public static func identify(userId: String, pushToken: String? = nil) {
        self.identifiedUserId = userId
        print("👤 CopyLab: Identified user: \(userId)")
        
        // Register token if provided
        if let token = pushToken {
            registerPushToken(token)
        }
        
        // Execute pending actions now that we have an identity
        let actions = pendingActions
        pendingActions = []
        for action in actions {
            action()
        }
        
        // Sync permission status immediately when user is identified
        syncNotificationPermissionStatus()
        
        // Prefetch user preferences
        prefetchNotificationPreferences()
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
        if let userNotificationId = userInfo["user_notification_id"] as? String {
            body["user_notification_id"] = userNotificationId
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
    
    /// Sets the APNs device token from raw Data received in didRegisterForRemoteNotificationsWithDeviceToken.
    /// This converts the data to a hex string and registers it with CopyLab.
    ///
    /// - Parameter data: The raw device token Data
    public static func setDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        registerPushToken(token)
    }
    
    /// Registers a device token string with CopyLab.
    ///
    /// - Parameter token: Hex-encoded device token string
    public static func registerPushToken(_ token: String) {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing push token registration until user is identified")
            pendingActions.append { registerPushToken(token) }
            return
        }
        
        let body: [String: Any] = [
            "user_id": currentUserId,
            "token": token,
            "platform": "ios"
        ]
        
        makeAPIRequest(endpoint: "register_push_token", body: body) { result in
            switch result {
            case .success:
                print("📊 CopyLab: Device token registered successfully")
            case .failure(let error):
                print("⚠️ CopyLab: Error registering device token: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - SMS

    /// Registers a phone number for the current user to enable SMS delivery.
    ///
    /// The number must be in E.164 format, e.g. `"+14155552671"`.
    /// Registrations are queued if no user has been identified yet.
    ///
    /// - Parameter phoneNumber: The phone number in E.164 format.
    public static func registerPhoneNumber(_ phoneNumber: String) {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing phone number registration until user is identified")
            pendingActions.append { registerPhoneNumber(phoneNumber) }
            return
        }

        let body: [String: Any] = [
            "user_id": currentUserId,
            "phone_number": phoneNumber
        ]

        makeAPIRequest(endpoint: "register_phone_number", body: body) { result in
            switch result {
            case .success:
                print("📱 CopyLab: Phone number registered successfully")
            case .failure(let error):
                print("⚠️ CopyLab: Error registering phone number: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Topic Subscriptions

    /// Subscribes the current user to a CopyLab topic.
    ///
    /// - Parameters:
    ///   - topicId: The topic ID (e.g., "chat_community_chat_alerts")
    ///   - topicName: Optional display name for the topic (e.g., "Community Chat Alerts")
    public static func subscribeToTopic(_ topicId: String, topicName: String? = nil) {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing subscription to \(topicId) until user is identified")
            pendingActions.append { subscribeToTopic(topicId, topicName: topicName) }
            return
        }

        var body: [String: Any] = [
            "topic_id": topicId,
            "user_id": currentUserId
        ]
        if let topicName = topicName {
            body["topic_name"] = topicName
        }
        
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
    
    /// Requests notification permissions from the user.
    /// - Parameter completion: Callback with the granted status and any error
    public static func requestNotificationPermission(completion: @escaping (Bool, Error?) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            // Sync status regardless of outcome
            syncNotificationPermissionStatus()
            
            DispatchQueue.main.async {
                completion(granted, error)
            }
        }
    }
    
    /// Logs when the app is opened with rich metadata.
    /// Used for calculating influenced attribution and tracking app usage.
    /// Captures app version, SDK version, device info, timezone, and timestamp.
    public static func logAppOpen() {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing app open log until user is identified")
            pendingActions.append { logAppOpen() }
            return
        }

        // Collect metadata
        let metadata: [String: Any] = [
            "app_version": getAppVersion(),
            "sdk_version": sdkVersion,
            "client_timestamp": getCurrentTimestamp(),
            "timezone": getTimezone(),
            "device_model": getDeviceModel(),
            "os_version": getOSVersion(),
            "device_name": getDeviceName(),
            "app_build": getAppBuild()
        ]

        let body: [String: Any] = [
            "user_id": currentUserId,
            "platform": "ios",
            "metadata": metadata
        ]

        makeAPIRequest(endpoint: "log_app_open", body: body) { result in
            switch result {
            case .success:
                print("📱 CopyLab: Logged app open with metadata")
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

    // MARK: - User Attributes

    /// Sets user attributes that are used as fallback variables when generating
    /// notification content. Attributes are merged with any existing values.
    ///
    /// - Parameter attributes: A dictionary of string key-value pairs (e.g., `["user_name": "Nick"]`)
    public static func setUserAttributes(_ attributes: [String: String]) {
        guard identifiedUserId != nil else {
            print("⏳ CopyLab: Queueing setUserAttributes until user is identified")
            pendingActions.append { setUserAttributes(attributes) }
            return
        }

        let body: [String: Any] = [
            "user_id": currentUserId,
            "user_attributes": attributes
        ]

        makeAPIRequest(endpoint: "set_user_attributes", body: body) { result in
            switch result {
            case .success:
                print("📋 CopyLab: User attributes updated")
            case .failure(let error):
                print("⚠️ CopyLab: Error setting user attributes: \(error.localizedDescription)")
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
        
        makeDecodableAPIRequest(endpoint: "get_notification_preferences?user_id=\(userId)") { (result: Result<NotificationPreferences, Error>) in
            switch result {
            case .success(let prefs):
                print("🔍 CopyLab: API returned preferences: \(prefs.preferences), times: \(prefs.scheduleTimes)")
                saveCachedPreferences(prefs)
                completion(.success(prefs))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Retrieve cached notification preferences if available.
    public static func getCachedNotificationPreferences() -> NotificationPreferences? {
        guard let data = userDefaults.data(forKey: prefsCacheKey) else { return nil }
        return try? JSONDecoder().decode(NotificationPreferences.self, from: data)
    }
    
    private static func saveCachedPreferences(_ prefs: NotificationPreferences) {
        if let data = try? JSONEncoder().encode(prefs) {
            userDefaults.set(data, forKey: prefsCacheKey)
        }
    }
    
    /// Prefetch config in the background (called on configure)
    private static func prefetchPreferenceCenterConfig() {
        getPreferenceCenterConfig { result in
            switch result {
            case .success:
                print("📦 CopyLab: Prefetched preference center config")
            case .failure(let error):
                print("⚠️ CopyLab: Failed to prefetch config: \(error.localizedDescription)")
            }
        }
    }
    
    /// Prefetch user preferences in the background (called on identify)
    private static func prefetchNotificationPreferences() {
        getNotificationPreferences { result in
            switch result {
            case .success:
                print("📦 CopyLab: Prefetched notification preferences")
            case .failure(let error):
                print("⚠️ CopyLab: Failed to prefetch preferences: \(error.localizedDescription)")
            }
        }
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
        }

        // Always include timezone when any schedule-related field changes
        if !schedules.isEmpty || !scheduleTimes.isEmpty {
            body["timezone"] = TimeZone.current.identifier
        }
        
        makeAPIRequest(endpoint: "update_user_preferences", body: body) { result in
            switch result {
            case .success:
                print("📬 CopyLab: Updated notification preferences")
                // Update cached preferences to keep local state in sync
                if var cachedPrefs = getCachedNotificationPreferences() {
                    for (scheduleId, enabled) in schedules {
                        var updatedSchedules = cachedPrefs.schedules
                        updatedSchedules[scheduleId] = enabled
                        cachedPrefs = NotificationPreferences(
                            osPermission: cachedPrefs.osPermission,
                            topics: cachedPrefs.topics,
                            schedules: updatedSchedules,
                            scheduleTimes: cachedPrefs.scheduleTimes,
                            preferences: cachedPrefs.preferences,
                            timezone: cachedPrefs.timezone
                        )
                    }
                    for (scheduleId, timeStr) in scheduleTimes {
                        var updatedTimes = cachedPrefs.scheduleTimes
                        updatedTimes[scheduleId] = timeStr
                        cachedPrefs = NotificationPreferences(
                            osPermission: cachedPrefs.osPermission,
                            topics: cachedPrefs.topics,
                            schedules: cachedPrefs.schedules,
                            scheduleTimes: updatedTimes,
                            preferences: cachedPrefs.preferences,
                            timezone: cachedPrefs.timezone
                        )
                    }
                    saveCachedPreferences(cachedPrefs)
                }
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
        makeDecodableAPIRequest(endpoint: "get_notification_center_config") { (result: Result<PreferenceCenterConfig, Error>) in
            switch result {
            case .success(let config):
                saveCachedConfig(config)
                completion(.success(config))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Retrieve cached preference center configuration if available.
    public static func getCachedPreferenceCenterConfig() -> PreferenceCenterConfig? {
        guard let data = userDefaults.data(forKey: configCacheKey) else { return nil }
        return try? JSONDecoder().decode(PreferenceCenterConfig.self, from: data)
    }
    
    private static func saveCachedConfig(_ config: PreferenceCenterConfig) {
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: configCacheKey)
        }
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
                // Update cached preferences to keep local state in sync
                if var cachedPrefs = getCachedNotificationPreferences() {
                    var updatedPrefs = cachedPrefs.preferences
                    for (prefId, enabled) in preferences {
                        updatedPrefs[prefId] = enabled
                    }
                    let newCachedPrefs = NotificationPreferences(
                        osPermission: cachedPrefs.osPermission,
                        topics: cachedPrefs.topics,
                        schedules: cachedPrefs.schedules,
                        scheduleTimes: cachedPrefs.scheduleTimes,
                        preferences: updatedPrefs,
                        timezone: cachedPrefs.timezone
                    )
                    saveCachedPreferences(newCachedPrefs)
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Preference Management

    /// Returns the user's preferences as `UserPreference` objects, merging config with user state.
    ///
    /// Uses cached config and user preference data. Call after `configure()` and `identify()`.
    ///
    /// - Parameter preferenceId: Optional ID to return a single preference. If nil, returns all.
    /// - Returns: An array of `UserPreference` objects (empty if config not cached, or single-element if filtered).
    public static func getPreferences(_ preferenceId: String? = nil) -> [UserPreference] {
        guard let config = getCachedPreferenceCenterConfig() else { return [] }
        var prefItems = config.sections
            .first(where: { $0.type == .preferences })?
            .items ?? []

        if let id = preferenceId {
            prefItems = prefItems.filter { $0.id == id }
        }

        let userPrefs = getCachedNotificationPreferences()

        return prefItems.map { item in
            let enabled = userPrefs?.preferences[item.id] ?? item.enabledByDefault ?? true

            var time: String? = nil
            if item.parameters?.schedule != nil {
                time = userPrefs?.scheduleTimes[item.id] ?? item.parameters?.schedule?.defaultTime
            }

            return UserPreference(
                id: item.id,
                title: item.title,
                description: item.description,
                enabledByDefault: item.enabledByDefault ?? true,
                parameters: item.parameters,
                enabled: enabled,
                time: time
            )
        }
    }

    /// Updates a single preference's enabled state and optional time.
    ///
    /// Persists the change to the server and updates the local cache on success.
    ///
    /// - Parameters:
    ///   - preferenceId: The preference ID to update
    ///   - enabled: Whether the preference should be enabled
    ///   - time: Optional time in "HH:mm" format (only for preferences with a schedule parameter)
    ///   - completion: Callback with success or error
    public static func setPreference(
        _ preferenceId: String,
        enabled: Bool,
        time: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard identifiedUserId != nil else {
            print("⚠️ CopyLab: User not identified. Call identify(userId:) first.")
            completion(.failure(CopyLabError.notConfigured))
            return
        }

        var body: [String: Any] = [
            "user_id": currentUserId,
            "preferences": [preferenceId: enabled]
        ]

        if let time = time {
            body["schedule_times"] = [preferenceId: time]
        }

        // Always include timezone — the preference may gate a scheduled notification
        body["timezone"] = TimeZone.current.identifier

        makeAPIRequest(endpoint: "update_user_preferences", body: body) { result in
            switch result {
            case .success:
                print("📬 CopyLab: Updated preference \(preferenceId)")
                // Update cached preferences
                if let cachedPrefs = getCachedNotificationPreferences() {
                    var updatedPrefs = cachedPrefs.preferences
                    updatedPrefs[preferenceId] = enabled
                    var updatedTimes = cachedPrefs.scheduleTimes
                    if let time = time {
                        updatedTimes[preferenceId] = time
                    }
                    let newCachedPrefs = NotificationPreferences(
                        osPermission: cachedPrefs.osPermission,
                        topics: cachedPrefs.topics,
                        schedules: cachedPrefs.schedules,
                        scheduleTimes: updatedTimes,
                        preferences: updatedPrefs,
                        timezone: cachedPrefs.timezone
                    )
                    saveCachedPreferences(newCachedPrefs)
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Debug / Testing

    /// Sends a test notification to the current user (Debug Only).
    /// Uses the 'daily_nomi_reminder' placement by default.
    public static func sendTestNotification(
        placementId: String = "daily_nomi_reminder",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        
        // Ensure we have a user context (either identified or anonymous is fine, but backend expects ID in list)
        let targetId = currentUserId
        
        // Construct payload for send_notification_to_users
        let body: [String: Any] = [
            "placement_id": placementId,
            "user_ids": [targetId],
            "variables": ["user_name": "Valued User"], 
            "data": ["is_test": true]
        ]
        
        makeAPIRequest(endpoint: "send_notification_to_users", body: body) { result in
            switch result {
            case .success:
                print("✅ CopyLab: Test notification sent successfully to \(targetId)")
                completion(.success(()))
            case .failure(let error):
                print("❌ CopyLab: Failed to send test notification: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Sends a test SMS to the current user's registered phone number.
    /// The backend resolves the user's phone number and user_attributes from Firestore,
    /// so the SMS uses real data exactly as a production send would.
    public static func sendTestSms(
        placementId: String = "sms_test",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "placement_id": placementId,
            "user_ids": [currentUserId]
        ]
        makeAPIRequest(endpoint: "send_sms_to_users", body: body) { result in
            switch result {
            case .success:
                print("✅ CopyLab: Test SMS sent to user \(currentUserId)")
                completion(.success(()))
            case .failure(let error):
                print("❌ CopyLab: Failed to send test SMS: \(error.localizedDescription)")
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

    /// Async version of setPreference
    @available(iOS 13.0, macOS 10.15, *)
    public static func setPreference(_ preferenceId: String, enabled: Bool, time: String? = nil) async throws {
        try await withCheckedThrowingContinuation { continuation in
            setPreference(preferenceId, enabled: enabled, time: time) { result in
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
