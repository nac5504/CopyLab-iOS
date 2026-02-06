# CopyLab iOS SDK

A Swift SDK for integrating CopyLab features into your iOS applications. This SDK handles analytics tracking, push open logging, permission status synchronization, and notification preference management.

## Installation

### Swift Package Manager (SPM)

1.  Open your project in Xcode.
2.  Go to **File** > **Add Packages...**
3.  In the search bar, enter the repository URL:
    ```
    https://github.com/nac5504/CopyLab-iOS
    ```
4.  Set the **Dependency Rule** to "Up to Next Major Version" (starting from `2.3.0`).
5.  Click **Add Package**.

## Usage

### 1. Initialization

Configure CopyLab in your `AppDelegate` or `App` entry point with your API Key.

```swift
import CopyLab

// 1. Configure in didFinishLaunching
CopyLab.configure(apiKey: "cl_your_app_id_xxxx")

// 2. Identify the user after login
CopyLab.identify(userId: "user_123")

// 3. (Optional) Call logout when they sign out
// CopyLab.logout()
```

### 2. Track Notification Opens

Call `logPushOpen` when a user taps on a notification to track attribution.

```swift
// UNUserNotificationCenterDelegate
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    let userInfo = response.notification.request.content.userInfo
    
    // Log the event to CopyLab
    CopyLab.logPushOpen(userInfo: userInfo)
}
```

### 3. Sync Permission Status

Keep track of whether users have enabled or disabled notifications. Call this on app launch or when the app enters the foreground.

```swift
CopyLab.syncNotificationPermissionStatus()
```

### 4. Topic Subscriptions

Manage user subscriptions to specific notification topics.

```swift
// Subscribe
CopyLab.subscribeToTopic("community_updates")

// Unsubscribe
CopyLab.unsubscribeFromTopic("community_updates")
```

### 5. Notification Preference Center (NEW)

Display a drop-in settings screen where users can manage their notification preferences:

```swift
import SwiftUI
import CopyLab

struct SettingsView: View {
    var body: some View {
        NavigationView {
            PreferenceCenterView()
        }
    }
}
```

Or use the API directly for custom UI:

```swift
// Fetch user preferences (async/await)
let prefs = try await CopyLab.getNotificationPreferences()
print("OS Permission: \(prefs.osPermission)")
print("Topics: \(prefs.topics)")
print("Schedules: \(prefs.schedules)")

// Fetch preference center config
let config = try await CopyLab.getPreferenceCenterConfig()

// Update schedule toggles
try await CopyLab.updateNotificationPreferences(schedules: [
    "daily_reminder": false,
    "weekly_digest": true
])
```

### 5. Track Subscription Status

Update the user's in-app purchase subscription status to enable segmentation and analytics.

```swift
// When user purchases a subscription
CopyLab.shared.updateSubscriptionStatus(
    isSubscribed: true,
    tier: "premium",
    expiresAt: subscriptionExpiryDate
)

// When subscription expires or is cancelled
CopyLab.shared.updateSubscriptionStatus(isSubscribed: false)
```

## Updating

To update the SDK to the latest version in Xcode:

1.  Select **File** > **Packages** > **Update to Latest Package Versions**.
2.  Xcode will check for newer versions matching your specific dependency rule (e.g., `2.x.x`).
