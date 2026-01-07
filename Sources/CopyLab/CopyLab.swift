import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

/// CopyLab SDK for iOS
/// Handles interaction with the CopyLab notification system, specifically analytics tracking.
final class CopyLab {
    static let shared = CopyLab()
    
    private var _db: Firestore?
    private var apiKey: String?
    
    private var db: Firestore {
        if let database = _db {
            return database
        }
        // Fallback to default app
        return Firestore.firestore()
    }
    
    private init() {}
    
    /// Configure CopyLab with an API Key and optional Firebase App.
    /// Call this in your AppDelegate or App init.
    ///
    /// - Parameters:
    ///   - apiKey: Your CopyLab API Key (starts with cl_)
    ///   - app: Optional FirebaseApp instance for CopyLab project. If nil, uses default app.
    public func configure(apiKey: String, app: FirebaseApp? = nil) {
        self.apiKey = apiKey
        
        if let app = app {
            self._db = Firestore.firestore(app: app)
            print("✅ CopyLab: Configured with separate Firebase App: \(app.name)")
        } else {
            print("⚠️ CopyLab: Configured with default Firebase App (Make sure this is intended)")
        }
        
        print("✅ CopyLab: Initialized with API Key: \(apiKey)")
    }
    
    /// Convenience: Configure using a plist file from the Bundle.
    ///
    /// - Parameters:
    ///   - apiKey: Your CopyLab API Key
    ///   - plistName: Name of the plist file (excluding .plist extension). Default: "CopyLab-GoogleService-Info"
    public func configure(apiKey: String, plistName: String = "CopyLab-GoogleService-Info") {
        guard let filePath = Bundle.main.path(forResource: plistName, ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            print("⚠️ CopyLab: Could not find or load \(plistName).plist. Using default app.")
            self.configure(apiKey: apiKey, app: nil)
            return
        }
        
        // Configure secondary app
        // We use a specific name "CopyLab" to avoid conflicts
        var app: FirebaseApp?
        
        // Check if already configured to avoid crash
        if let existingApp = FirebaseApp.allApps?.values.first(where: { $0.name == "CopyLab" }) {
            app = existingApp
        } else {
            FirebaseApp.configure(options: options, name: "CopyLab")
            app = FirebaseApp.app(name: "CopyLab")
        }
        
        self.configure(apiKey: apiKey, app: app)
    }
    
    // MARK: - Private Helpers
    
    /// Extracts the App ID from the API key.
    /// Format: cl_{app_id}_{random_hex}
    private var appId: String {
        guard let key = apiKey else { return "unknown" }
        let components = key.split(separator: "_")
        if components.count >= 2 {
            return String(components[1])
        }
        return "unknown"
    }
    
    /// Returns the collection path prefixed for the current tenant.
    /// e.g. "apps/nomigo/push_analytics"
    private func getCollectionPath(_ collection: String) -> String {
        let tenantPrefix = "apps/\(appId)/"
        return tenantPrefix + collection
    }
    
    /// Logs a push notification open event to CopyLab analytics.
    /// This should be called when a user taps on a notification.
    ///
    /// - Parameter userInfo: The userInfo dictionary from the notification response.
    func logPushOpen(userInfo: [AnyHashable: Any]) {
        // Extract CopyLab data
        let placementId = userInfo["copylab_placement_id"] as? String
        let placementName = userInfo["copylab_placement_name"] as? String
        let templateId = userInfo["copylab_template_id"] as? String
        let templateName = userInfo["copylab_template_name"] as? String
        let notificationId = userInfo["notification_id"] as? String
        
        // Also capture generic notification type if available
        let type = (userInfo["type"] as? String) ?? (userInfo["notification_type"] as? String) ?? "unknown"
        
        // Get current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ CopyLab: No authenticated user, skipping push_open log")
            return
        }
        
        // Prepare data payload
        var data: [String: Any] = [
            "user_id": userId,
            "timestamp": FieldValue.serverTimestamp(),
            "platform": "ios",
            "type": type
        ]
        
        if let notificationId = notificationId {
            data["notification_id"] = notificationId
        }
        
        if let placementId = placementId {
            data["placement_id"] = placementId
        }
        
        if let placementName = placementName {
            data["placement_name"] = placementName
        }
        
        if let templateId = templateId {
            data["template_id"] = templateId
        }
        
        if let templateName = templateName {
            data["template_name"] = templateName
        }
        
        // Log to Firestore (Tenant Scoped)
        let collectionPath = getCollectionPath("copylab_push_open")
        db.collection(collectionPath).addDocument(data: data) { error in
            if let error = error {
                print("⚠️ CopyLab: Error logging push_open: \(error.localizedDescription)")
            } else {
                print("📊 CopyLab: Logged push_open event (id: \(notificationId ?? "unknown")) to \(self.appId)")
            }
        }
    }
    
    // MARK: - Topic Subscriptions
    
    /// Subscribes the current user to a CopyLab topic.
    /// Topics are stored in the centralized copylab_topics collection for efficient lookup.
    ///
    /// - Parameter topicId: The topic ID (e.g., "chat_community_chat_alerts")
    func subscribeToTopic(_ topicId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ CopyLab: No authenticated user, skipping topic subscribe")
            return
        }
        
        // Tenant Scoped
        let collectionPath = getCollectionPath("copylab_topics")
        
        db.collection(collectionPath).document(topicId).setData([
            "subscriber_ids": FieldValue.arrayUnion([userId]),
            "updated_at": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                print("⚠️ CopyLab: Error subscribing to topic \(topicId): \(error.localizedDescription)")
            } else {
                print("📊 CopyLab: Subscribed to topic \(topicId) (\(self.appId))")
            }
        }
    }
    
    /// Unsubscribes the current user from a CopyLab topic.
    ///
    /// - Parameter topicId: The topic ID (e.g., "chat_community_chat_alerts")
    func unsubscribeFromTopic(_ topicId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ CopyLab: No authenticated user, skipping topic unsubscribe")
            return
        }
        
        // Tenant Scoped
        let collectionPath = getCollectionPath("copylab_topics")
        
        db.collection(collectionPath).document(topicId).updateData([
            "subscriber_ids": FieldValue.arrayRemove([userId]),
            "updated_at": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("⚠️ CopyLab: Error unsubscribing from topic \(topicId): \(error.localizedDescription)")
            } else {
                print("📊 CopyLab: Unsubscribed from topic \(topicId) (\(self.appId))")
            }
        }
    }
    
    // MARK: - Notification Permission Tracking
    
    /// Checks the current iOS notification permission status and syncs it to Firestore.
    /// This should be called on app launch, when app enters foreground, and after requesting permissions.
    ///
    /// Stores the permission status in the `copylab_users/{userId}` document as a `notification_status` field.
    /// The status is stored as a string: "authorized", "denied", "notDetermined", "provisional", or "ephemeral"
    func syncNotificationPermissionStatus() {
        print("📊 CopyLab: syncNotificationPermissionStatus() called")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ CopyLab: No authenticated user, skipping permission sync")
            return
        }
        
        print("📊 CopyLab: Checking notification settings for user: \(userId)")
        
        // Check notification settings on iOS
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📊 CopyLab: Got notification settings - authorizationStatus: \(settings.authorizationStatus.rawValue)")
            
            // Map authorization status to string
            let statusString: String
            switch settings.authorizationStatus {
            case .authorized:
                statusString = "authorized"
            case .denied:
                statusString = "denied"
            case .notDetermined:
                statusString = "notDetermined"
            case .provisional:
                statusString = "provisional"
            case .ephemeral:
                statusString = "ephemeral"
            @unknown default:
                statusString = "unknown"
            }
            
            print("📊 CopyLab: Mapped status to string: \(statusString)")
            
            // Prepare data to sync
            let data: [String: Any] = [
                "notification_status": statusString,
                "last_updated": FieldValue.serverTimestamp(),
                "platform": "ios"
            ]
            
            print("📊 CopyLab: Syncing to Firestore - copylab_users/\(userId)")
            
            // Sync to Firestore using user ID as document ID in copylab_users collection
            // Tenant Scoped
            let collectionPath = self.getCollectionPath("copylab_users")
            self.db.collection(collectionPath).document(userId).setData(data, merge: true) { error in
                if let error = error {
                    print("⚠️ CopyLab: Error syncing notification status: \(error.localizedDescription)")
                } else {
                    print("📊 CopyLab: ✅ Successfully synced notification status: \(statusString) (\(self.appId))")
                }
            }
        }
    }
    
    /// Logs when the app is opened
    /// Used for calculating influenced attribution (app opens within X min of notification send)
    /// Creates a new document in the user's app_opens subcollection for each app open
    func logAppOpen() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        let data: [String: Any] = [
            "timestamp": FieldValue.serverTimestamp(),
            "platform": "ios"
        ]
        
        // Add a new document to the app_opens subcollection for each app open
        // Tenant Scoped
        let collectionPath = getCollectionPath("copylab_users")
        db.collection(collectionPath).document(userId).collection("app_opens").addDocument(data: data) { error in
            if let error = error {
                print("⚠️ CopyLab: Error logging app open: \(error.localizedDescription)")
            } else {
                print("📱 CopyLab: Logged app open (\(self.appId))")
            }
        }
    }
}
