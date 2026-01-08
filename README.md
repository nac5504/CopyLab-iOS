# CopyLab iOS SDK

A Swift SDK for integrating CopyLab features into your iOS applications. This SDK handles analytics tracking, push open logging, and permission status synchronization.

## Installation

### Swift Package Manager (SPM)

1.  Open your project in Xcode.
2.  Go to **File** > **Add Packages...**
3.  In the search bar, enter the repository URL:
    ```
    https://github.com/nac5504/CopyLab-iOS
    ```
4.  Set the **Dependency Rule** to "Up to Next Major Version" (starting from `2.2.0`).
5.  Click **Add Package**.

## Usage

### 1. Initialization

Configure CopyLab in your `AppDelegate` or `App` entry point with your API Key.

```swift
import CopyLab

// 1. Configure in didFinishLaunching
CopyLab.shared.configure(apiKey: "cl_your_app_id_xxxx")

// 2. Identify the user after login
CopyLab.shared.identify(userId: "user_123")

// 3. (Optional) Call logout when they sign out
// CopyLab.shared.logout()
```

### 2. Track Notification Opens

Call `logPushOpen` when a user taps on a notification to track attribution.

```swift
// UNUserNotificationCenterDelegate
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    let userInfo = response.notification.request.content.userInfo
    
    // Log the event to CopyLab
    CopyLab.shared.logPushOpen(userInfo: userInfo)
}
```

### 3. Sync Permission Status

Keep track of whether users have enabled or disabled notifications. Call this on app launch or when the app enters the foreground.

```swift
CopyLab.shared.syncNotificationPermissionStatus()
```

### 4. Topic Subscriptions

Manage user subscriptions to specific notification topics.

```swift
// Subscribe
CopyLab.shared.subscribeToTopic("community_updates")

// Unsubscribe
CopyLab.shared.unsubscribeFromTopic("community_updates")
```

## Updating

To update the SDK to the latest version in Xcode:

1.  Select **File** > **Packages** > **Update to Latest Package Versions**.
2.  Xcode will check for newer versions matching your specific dependency rule (e.g., `2.x.x`).
