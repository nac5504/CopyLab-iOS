# CopyLab iOS SDK

The CopyLab iOS SDK handles push notification management, analytics tracking, user preferences, and provides a drop-in preference center UI for your app.

**Current version: 2.8.9** | iOS 13+ | Swift 5.5+ | Swift Package Manager

## Installation

### Swift Package Manager

1. In Xcode, go to **File > Add Packages...**
2. Enter the repository URL:
   ```
   https://github.com/nac5504/CopyLab-iOS
   ```
3. Set the dependency rule to **Up to Next Major Version** starting from `2.8.9`.
4. Click **Add Package**.

## Quick Start

```swift
import CopyLab

// 1. Configure on app launch (AppDelegate or @main App init)
CopyLab.configure(apiKey: "cl_your_app_id_xxxx")

// 2. Identify the user after login
CopyLab.identify(userId: "user_123")

// 3. Register for push notifications
CopyLab.setDeviceToken(deviceTokenData)

// 4. Log when user taps a notification
CopyLab.logPushOpen(userInfo: notificationUserInfo)
```

## Setup

### Configure

Call `configure` as early as possible in your app lifecycle. This initializes the SDK and prefetches the preference center configuration.

```swift
// In AppDelegate.didFinishLaunchingWithOptions or App.init
CopyLab.configure(apiKey: "cl_your_app_id_xxxx")
```

You can also pass a push token at configure time:

```swift
CopyLab.configure(apiKey: "cl_your_app_id_xxxx", pushToken: fcmToken)
```

### Identify

Call `identify` after the user logs in. This associates the device with a user in your system and prefetches their notification preferences.

```swift
CopyLab.identify(userId: "user_123")
```

Any SDK calls made before `identify` (like `logPushOpen` or `registerPushToken`) are automatically queued and executed once the user is identified.

### Logout

Clear the identified user when they sign out:

```swift
CopyLab.logout()
```

## Push Notifications

### Register Device Token

Pass the raw APNs device token to CopyLab:

```swift
// In AppDelegate
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    CopyLab.setDeviceToken(deviceToken)
}
```

Or register a hex-encoded token string directly:

```swift
CopyLab.registerPushToken("a1b2c3d4...")
```

### Log Notification Opens

Track when users tap on notifications for analytics and attribution:

```swift
// In your UNUserNotificationCenterDelegate
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    CopyLab.logPushOpen(userInfo: response.notification.request.content.userInfo)
}
```

### Log App Opens

Track app opens for influenced attribution (measures users who open your app after receiving a notification, even without tapping it):

```swift
// In your app's sceneDidBecomeActive or applicationDidBecomeActive
CopyLab.logAppOpen()
```

### Request Notification Permissions

```swift
CopyLab.requestNotificationPermission { granted, error in
    if granted {
        // User allowed notifications
    }
}
```

### Sync Permission Status

Keeps CopyLab's server in sync with the user's current iOS notification permission. This is called automatically on `identify()`, but you can also call it manually (e.g., when the app enters the foreground):

```swift
CopyLab.syncNotificationPermissionStatus()
```

## Preference Center

The SDK provides two ways to manage notification preferences: a **drop-in SwiftUI view** or a **programmatic API** for fully custom UIs.

### Option 1: Drop-in PreferenceCenterView

The built-in `PreferenceCenterView` displays a complete notification settings screen with toggles for preferences, topics, schedules, and system permission status.

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

#### Styling the PreferenceCenterView

Customize the appearance with `PreferenceCenterStyle`. You can set a global style or pass one per instance.

**Global style** (applies to all instances):

```swift
// Set before presenting the view
CopyLab.preferenceCenterStyle = PreferenceCenterStyle(
    navigationTitle: "Notifications",
    backgroundColor: .black,
    sectionBackgroundColor: Color(.systemGray6),
    primaryTextColor: .white,
    secondaryTextColor: .gray,
    toggleTintColor: .purple,
    accentColor: .mint,
    destructiveColor: .pink
)
```

**Per-instance style:**

```swift
PreferenceCenterView(style: PreferenceCenterStyle(
    backgroundColor: .black,
    primaryTextColor: .white,
    toggleTintColor: .blue
))
```

**All available style properties:**

| Property | Description |
|---|---|
| `navigationTitle` | Nav bar title (default: "Notification Settings") |
| `backgroundColor` | Background behind the list |
| `sectionBackgroundColor` | Background of grouped section cards |
| `sectionHeaderColor` | Color of section headers ("Preferences", "Categories") |
| `sectionHeaderFont` | Font for section headers |
| `primaryTextColor` | Color for row titles |
| `primaryTextFont` | Font for row titles |
| `secondaryTextColor` | Color for captions and descriptions |
| `secondaryTextFont` | Font for captions and descriptions |
| `toggleTintColor` | Tint for toggles when ON |
| `accentColor` | Tint for action buttons ("Enable", etc.) |
| `destructiveColor` | Color for destructive buttons ("Disable") |
| `permissionAuthorizedColor` | Status icon color when authorized |
| `permissionDeniedColor` | Status icon color when denied |
| `permissionProvisionalColor` | Status icon color when provisional |
| `permissionUnknownColor` | Status icon color when unknown |
| `permissionTitleFont` | Font for "Push Notifications" title |
| `loadingColor` | Spinner color |
| `errorIconColor` | Error state icon color |
| `errorTitleColor` | Error state title color |
| `datePickerTintColor` | Tint for time pickers |

#### Customize the Disable Alert

```swift
CopyLab.disableNotificationsAlertConfig = CopyLab.DisableNotificationsAlertConfig(
    title: "Turn off notifications?",
    message: "You'll stop receiving updates from us.",
    cancelTitle: "Keep",
    confirmTitle: "Open Settings"
)
```

### Option 2: Programmatic Preference API

For fully custom UIs, use `getPreferences()` and `setPreference()` to read and write preference state directly.

#### Get all preferences

```swift
let preferences = CopyLab.getPreferences()

for pref in preferences {
    print("\(pref.title): enabled=\(pref.enabled)")

    // Some preferences have a configurable time
    if let time = pref.time {
        print("  Scheduled at: \(time)")
    }
}
```

#### Get a specific preference

```swift
if let reminder = CopyLab.getPreferences("daily_nomi_reminders").first {
    print("Reminders enabled: \(reminder.enabled)")
    print("Reminder time: \(reminder.time ?? "default")")
}
```

#### Update a preference

```swift
// Toggle a preference on/off
CopyLab.setPreference("community_posts", enabled: false) { result in
    switch result {
    case .success:
        print("Preference updated")
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Update a preference with a time (for preferences that have a schedule parameter)
CopyLab.setPreference("daily_nomi_reminders", enabled: true, time: "08:30") { result in
    // ...
}
```

#### Async/await

```swift
// Set a preference
try await CopyLab.setPreference("daily_nomi_reminders", enabled: true, time: "08:30")
```

#### The UserPreference model

Each `UserPreference` returned by `getPreferences()` contains:

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Preference identifier |
| `title` | `String` | Display title |
| `description` | `String` | Display description |
| `enabledByDefault` | `Bool` | The app-level default |
| `enabled` | `Bool` | The user's current state (falls back to `enabledByDefault`) |
| `time` | `String?` | Current time in "HH:mm" format (nil if no schedule parameter) |
| `parameters` | `PreferenceParameters?` | Config metadata (e.g., schedule with default_time) |

## Topics

Manage user subscriptions to notification topics/categories.

```swift
// Subscribe
CopyLab.subscribeToTopic("community_updates")

// Unsubscribe
CopyLab.unsubscribeFromTopic("community_updates")
```

## User Attributes

Set user attributes that are used as fallback template variables when generating notification content:

```swift
CopyLab.setUserAttributes([
    "user_name": "Nick",
    "favorite_color": "blue"
])
```

These are merged with any existing attributes on the server.

## Subscription Status

Track in-app purchase subscription status for segmentation and analytics:

```swift
// User purchased a subscription
CopyLab.updateSubscriptionStatus(
    isSubscribed: true,
    tier: "premium",
    expiresAt: expirationDate
)

// Subscription expired
CopyLab.updateSubscriptionStatus(isSubscribed: false)
```

## Low-Level API

For advanced use cases, the SDK also exposes lower-level methods:

```swift
// Fetch raw notification preferences from the server
CopyLab.getNotificationPreferences { result in
    switch result {
    case .success(let prefs):
        print(prefs.osPermission)   // "authorized"
        print(prefs.topics)         // ["topic_1", "topic_2"]
        print(prefs.schedules)      // ["morning": true]
        print(prefs.scheduleTimes)  // ["morning": "09:00"]
        print(prefs.preferences)    // ["marketing": false]
    case .failure(let error):
        print(error)
    }
}

// Fetch the preference center config (sections, items)
CopyLab.getPreferenceCenterConfig { result in ... }

// Access cached data (no network call)
let cachedPrefs = CopyLab.getCachedNotificationPreferences()
let cachedConfig = CopyLab.getCachedPreferenceCenterConfig()

// Async/await versions
let prefs = try await CopyLab.getNotificationPreferences()
let config = try await CopyLab.getPreferenceCenterConfig()
```

## Updating

To update to the latest SDK version in Xcode:

1. Go to **File > Packages > Update to Latest Package Versions**.
2. Xcode will fetch the newest version matching your dependency rule.
