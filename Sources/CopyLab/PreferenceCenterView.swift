#if canImport(UIKit)
import SwiftUI
import UserNotifications
import UIKit

/// A drop-in SwiftUI view for displaying and managing notification preferences.
/// 
/// Usage:
/// ```swift
/// NavigationView {
///     PreferenceCenterView()
/// }
/// ```
@available(iOS 14.0, *)
public struct PreferenceCenterView: View {
    @StateObject private var viewModel = PreferenceCenterViewModel()
    
    public init() {}
    
    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading preferences...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Failed to load preferences")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        viewModel.loadData()
                    }
                }
                .padding()
            } else {
                List {
                    // System Permission Card
                    Section {
                        SystemPermissionCard(
                            status: viewModel.osPermissionStatus,
                            onOpenSettings: viewModel.openSystemSettings
                        )
                    }
                    
                    // Preferences Section (NEW - gates placements)
                    if !viewModel.preferences.isEmpty {
                        Section(header: Text("Preferences")) {
                            ForEach(viewModel.preferences) { preference in
                                PreferenceToggleRow(
                                    preference: preference,
                                    isEnabled: viewModel.isPreferenceEnabled(preference.id),
                                    selectedTime: viewModel.getScheduleTime(preference.id), // Reusing schedule time logic
                                    onToggle: { enabled in
                                        viewModel.togglePreference(preference.id, enabled: enabled)
                                    },
                                    onTimeChange: { time in
                                        viewModel.updateScheduleTime(preference.id, time: time) // Reuse schedule time update
                                    }
                                )
                            }
                        }
                    }
                    
                    // Topics Section - filtered by type
                    if !viewModel.visibleTopics.isEmpty {
                        Section(header: Text("Categories")) {
                            ForEach(viewModel.visibleTopics) { topic in
                                TopicToggleRow(
                                    topic: topic,
                                    isSubscribed: viewModel.isSubscribedToTopic(topic.id),
                                    onToggle: { enabled in
                                        viewModel.toggleTopic(topic.id, enabled: enabled)
                                    }
                                )
                            }
                        }
                    }
                    
                    // Schedules Section
                    if !viewModel.schedules.isEmpty {
                        Section(header: Text("Schedules")) {
                            ForEach(viewModel.schedules) { schedule in
                                ScheduleToggleRow(
                                    schedule: schedule,
                                    isEnabled: viewModel.isScheduleEnabled(schedule.id),
                                    selectedTime: viewModel.getScheduleTime(schedule.id),
                                    onToggle: { enabled in
                                        viewModel.toggleSchedule(schedule.id, enabled: enabled)
                                    },
                                    onTimeChange: { time in
                                        viewModel.updateScheduleTime(schedule.id, time: time)
                                    }
                                )
                            }
                        }
                    }
                    
                    // Developer Tools Section
                    Section(header: Text("Developer Tools")) {
                        Button(action: {
                            viewModel.sendTestNotification()
                        }) {
                            HStack {
                                Text("Send Test Notification (Daily Reminder)")
                                Spacer()
                                Image(systemName: "paperplane")
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("Notification Settings")
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - System Permission Card

@available(iOS 14.0, *)
private struct SystemPermissionCard: View {
    let status: String
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Push Notifications")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if status != "authorized" {
                    Button("Settings") {
                        onOpenSettings()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch status {
        case "authorized": return "bell.badge.fill"
        case "denied": return "bell.slash.fill"
        case "provisional": return "bell.fill"
        default: return "bell"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case "authorized": return .green
        case "denied": return .red
        case "provisional": return .orange
        default: return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case "authorized": return "Notifications are enabled"
        case "denied": return "Notifications are disabled"
        case "provisional": return "Quiet notifications enabled"
        case "notDetermined": return "Permission not requested"
        default: return "Unknown status"
        }
    }
}

// MARK: - Topic Toggle Row

@available(iOS 14.0, *)
private struct TopicToggleRow: View {
    let topic: PreferenceCenterItem
    let isSubscribed: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // Title on the left - wraps to multiple lines if needed
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(topic.title)
                        .font(.body)
                        .lineLimit(nil)
                    if topic.type == .contextual {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Toggle on the right
            Toggle("", isOn: Binding(
                get: { isSubscribed },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preference Toggle Row (NEW)

@available(iOS 14.0, *)
private struct PreferenceToggleRow: View {
    let preference: PreferenceCenterItem
    let isEnabled: Bool
    let selectedTime: Date
    let onToggle: (Bool) -> Void
    let onTimeChange: (Date) -> Void
    
    init(preference: PreferenceCenterItem, isEnabled: Bool, selectedTime: Date = Date(), onToggle: @escaping (Bool) -> Void, onTimeChange: @escaping (Date) -> Void = { _ in }) {
        self.preference = preference
        self.isEnabled = isEnabled
        self.selectedTime = selectedTime
        self.onToggle = onToggle
        self.onTimeChange = onTimeChange
    }
    
    private var hasScheduleParam: Bool {
        preference.parameters?.schedule != nil
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // Title on the left - wraps to multiple lines if needed
            Text(preference.title)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Optional time picker - grayed out and disabled if toggle is off
            if hasScheduleParam {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedTime },
                        set: { onTimeChange($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.4)
            }
            
            // Toggle on the right
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Schedule Toggle Row

@available(iOS 14.0, *)
private struct ScheduleToggleRow: View {
    let schedule: PreferenceCenterItem
    let isEnabled: Bool
    let selectedTime: Date
    let onToggle: (Bool) -> Void
    let onTimeChange: (Date) -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // Title on the left - wraps to multiple lines if needed
            Text(schedule.title)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Optional time picker - grayed out and disabled if toggle is off
            if schedule.timeConfigurable == true {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedTime },
                        set: { onTimeChange($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.4)
            }
            
            // Toggle on the right
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@available(iOS 14.0, *)
@MainActor
class PreferenceCenterViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var error: Error?
    @Published var osPermissionStatus = "unknown"
    @Published var subscribedTopics: Set<String> = []
    @Published var scheduleStates: [String: Bool] = [:]
    @Published var scheduleTimes: [String: Date] = [:]
    @Published var preferenceStates: [String: Bool] = [:] // NEW
    @Published var preferences: [PreferenceCenterItem] = [] // NEW
    @Published var topics: [PreferenceCenterItem] = []
    @Published var schedules: [PreferenceCenterItem] = []
    
    /// Returns topics that should be visible based on type and subscription status
    var visibleTopics: [PreferenceCenterItem] {
        topics.filter { topic in
            // Persistent topics are always shown
            if topic.type == .persistent || topic.type == nil {
                return true
            }
            // Contextual topics only shown when subscribed
            return subscribedTopics.contains(topic.id)
        }
    }
    
    func loadData() {
        print("🔍 CopyLab: loadData() called - using cached data only")
        isLoading = true
        error = nil
        
        // Load from cache ONLY (data was prefetched on configure/identify)
        if let cachedConfig = CopyLab.getCachedPreferenceCenterConfig() {
            print("💾 CopyLab: Loaded config from cache - \(cachedConfig.sections.count) sections")
            self.processConfig(cachedConfig)
        } else {
            print("⚠️ CopyLab: No cached config - config should have been fetched on configure()")
        }
        
        if let cachedPrefs = CopyLab.getCachedNotificationPreferences() {
            print("💾 CopyLab: Loaded preferences from cache - prefs: \(cachedPrefs.preferences), times: \(cachedPrefs.scheduleTimes)")
            self.updateViewModelWithPreferences(cachedPrefs)
        } else {
            print("⚠️ CopyLab: No cached preferences - preferences should have been fetched on identify()")
        }

        // Fetch current OS permission status
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.osPermissionStatus = self?.mapAuthorizationStatus(settings.authorizationStatus) ?? "unknown"
            }
        }
        
        self.isLoading = false
        print("🔍 CopyLab: loadData() complete - preferenceStates = \(self.preferenceStates)")
    }
    
    private func processConfig(_ config: PreferenceCenterConfig) {
        print("🔍 CopyLab: processConfig() called")
        for section in config.sections {
            switch section.type {
            case .preferences:
                preferences = section.items ?? []
                print("🔍 CopyLab: Found \(preferences.count) preference items")
                // Initialize preference states with defaults
                for pref in preferences {
                    if preferenceStates[pref.id] == nil {
                        preferenceStates[pref.id] = pref.enabledByDefault ?? true
                        print("🔍 CopyLab: Set DEFAULT preferenceStates[\(pref.id)] = \(pref.enabledByDefault ?? true)")
                    } else {
                        print("🔍 CopyLab: SKIPPED preferenceStates[\(pref.id)] - already set to \(preferenceStates[pref.id]!)")
                    }
                    // Initialize time if scheduled param exists
                    if let scheduleParam = pref.parameters?.schedule, let defaultTime = scheduleParam.defaultTime {
                        if scheduleTimes[pref.id] == nil {
                            scheduleTimes[pref.id] = parseTime(defaultTime)
                            print("🔍 CopyLab: Set DEFAULT scheduleTimes[\(pref.id)] = \(defaultTime)")
                        }
                    }
                }
            case .topics:
                topics = section.items ?? []
            case .schedules:
                schedules = section.items ?? []
                // Initialize schedule states with defaults
                for schedule in schedules {
                    if scheduleStates[schedule.id] == nil {
                        scheduleStates[schedule.id] = schedule.enabledByDefault ?? true
                    }
                    if scheduleTimes[schedule.id] == nil {
                        scheduleTimes[schedule.id] = parseTime(schedule.defaultTime ?? "09:00")
                    }
                }
            case .systemPermissionCard:
                break
            }
        }
    }
    
    private func updateViewModelWithPreferences(_ prefs: NotificationPreferences) {
        print("🔍 CopyLab: Applying preferences - schedules: \(prefs.schedules), times: \(prefs.scheduleTimes), preferences: \(prefs.preferences)")
        self.subscribedTopics = Set(prefs.topics)
        for (scheduleId, enabled) in prefs.schedules {
            self.scheduleStates[scheduleId] = enabled
        }
        for (scheduleId, timeStr) in prefs.scheduleTimes {
            self.scheduleTimes[scheduleId] = self.parseTime(timeStr)
        }
        for (prefId, enabled) in prefs.preferences {
            self.preferenceStates[prefId] = enabled
            print("🔍 CopyLab: Set preferenceStates[\(prefId)] = \(enabled)")
        }
        
        self.osPermissionStatus = prefs.osPermission
    }
    
    func isSubscribedToTopic(_ topicId: String) -> Bool {
        subscribedTopics.contains(topicId)
    }
    
    func isPreferenceEnabled(_ preferenceId: String) -> Bool {
        preferenceStates[preferenceId] ?? true
    }
    
    func togglePreference(_ preferenceId: String, enabled: Bool) {
        preferenceStates[preferenceId] = enabled
        // Persist to server via the new preferences endpoint
        CopyLab.updateUserPreferences(preferences: [preferenceId: enabled]) { result in
            if case .failure(let error) = result {
                print("⚠️ CopyLab: Error updating preference: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleTopic(_ topicId: String, enabled: Bool) {
        if enabled {
            subscribedTopics.insert(topicId)
            CopyLab.subscribeToTopic(topicId)
        } else {
            subscribedTopics.remove(topicId)
            CopyLab.unsubscribeFromTopic(topicId)
        }
    }
    
    func isScheduleEnabled(_ scheduleId: String) -> Bool {
        scheduleStates[scheduleId] ?? true
    }
    
    func getScheduleTime(_ scheduleId: String) -> Date {
        scheduleTimes[scheduleId] ?? parseTime("09:00")
    }
    
    func toggleSchedule(_ scheduleId: String, enabled: Bool) {
        scheduleStates[scheduleId] = enabled
        CopyLab.updateNotificationPreferences(schedules: [scheduleId: enabled]) { result in
            if case .failure(let error) = result {
                print("⚠️ CopyLab: Error updating schedule: \(error.localizedDescription)")
            }
        }
    }
    
    func updateScheduleTime(_ scheduleId: String, time: Date) {
        scheduleTimes[scheduleId] = time
        let timeStr = formatTime(time)
        CopyLab.updateNotificationPreferences(scheduleTimes: [scheduleId: timeStr]) { result in
            if case .failure(let error) = result {
                print("⚠️ CopyLab: Error updating schedule time: \(error.localizedDescription)")
            }
        }
    }
    
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Actions
    
    func sendTestNotification() {
        print("🔍 CopyLab: Requesting test notification...")
        CopyLab.sendTestNotification { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ CopyLab: Test notification request succeeded")
                    // Maybe show a toast or alert? for now just print
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
    
    private func mapAuthorizationStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
    
    private func parseTime(_ timeStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeStr) ?? Date()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct PreferenceCenterView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PreferenceCenterView()
        }
    }
}

#endif
