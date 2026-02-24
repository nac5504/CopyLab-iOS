#if canImport(UIKit)
import SwiftUI
import UserNotifications
import UIKit

// MARK: - PreferenceCenterStyle

/// Style configuration for the PreferenceCenterView.
/// All properties are optional — nil uses SwiftUI defaults.
///
/// Usage:
/// ```swift
/// // Global (applies to all PreferenceCenterView instances)
/// CopyLab.preferenceCenterStyle = PreferenceCenterStyle(
///     backgroundColor: .black,
///     primaryTextColor: .white,
///     toggleTintColor: .purple
/// )
///
/// // Per-instance
/// PreferenceCenterView(style: PreferenceCenterStyle(accentColor: .mint))
/// ```
@available(iOS 14.0, *)
public struct PreferenceCenterStyle {
    // MARK: - Navigation
    /// Navigation bar title text (default: "Notification Settings")
    public var navigationTitle: String

    // MARK: - Sheet / Page Background
    /// Background color of the entire sheet/page behind the list
    public var backgroundColor: Color?

    // MARK: - List / Section
    /// Background color of section/card rows (the grouped inset cards)
    public var sectionBackgroundColor: Color?
    /// Color of section header text ("Preferences", "Categories", etc.)
    public var sectionHeaderColor: Color?
    /// Font for section header text
    public var sectionHeaderFont: Font?

    // MARK: - Row Text
    /// Primary text color (row titles like "Push Notifications", topic names, etc.)
    public var primaryTextColor: Color?
    /// Font for primary row text
    public var primaryTextFont: Font?
    /// Secondary/description text color (status captions, contextual icons)
    public var secondaryTextColor: Color?
    /// Font for secondary/description text
    public var secondaryTextFont: Font?

    // MARK: - Toggle
    /// Tint color for toggles when ON
    public var toggleTintColor: Color?

    // MARK: - Buttons
    /// Accent/tint color for action buttons ("Enable", "Send Test Notification", etc.)
    public var accentColor: Color?
    /// Color for destructive buttons ("Disable")
    public var destructiveColor: Color?

    // MARK: - System Permission Card
    /// Override colors for permission status icons
    public var permissionAuthorizedColor: Color?
    public var permissionDeniedColor: Color?
    public var permissionProvisionalColor: Color?
    public var permissionUnknownColor: Color?
    /// Font for the permission card title ("Push Notifications")
    public var permissionTitleFont: Font?

    // MARK: - Loading & Error States
    /// Color of the loading spinner
    public var loadingColor: Color?
    /// Color of the error icon
    public var errorIconColor: Color?
    /// Color of the error title text
    public var errorTitleColor: Color?

    // MARK: - Date Picker
    /// Tint/accent color for the time pickers in schedule rows
    public var datePickerTintColor: Color?

    public init(
        navigationTitle: String = "Notification Settings",
        backgroundColor: Color? = nil,
        sectionBackgroundColor: Color? = nil,
        sectionHeaderColor: Color? = nil,
        sectionHeaderFont: Font? = nil,
        primaryTextColor: Color? = nil,
        primaryTextFont: Font? = nil,
        secondaryTextColor: Color? = nil,
        secondaryTextFont: Font? = nil,
        toggleTintColor: Color? = nil,
        accentColor: Color? = nil,
        destructiveColor: Color? = nil,
        permissionAuthorizedColor: Color? = nil,
        permissionDeniedColor: Color? = nil,
        permissionProvisionalColor: Color? = nil,
        permissionUnknownColor: Color? = nil,
        permissionTitleFont: Font? = nil,
        loadingColor: Color? = nil,
        errorIconColor: Color? = nil,
        errorTitleColor: Color? = nil,
        datePickerTintColor: Color? = nil
    ) {
        self.navigationTitle = navigationTitle
        self.backgroundColor = backgroundColor
        self.sectionBackgroundColor = sectionBackgroundColor
        self.sectionHeaderColor = sectionHeaderColor
        self.sectionHeaderFont = sectionHeaderFont
        self.primaryTextColor = primaryTextColor
        self.primaryTextFont = primaryTextFont
        self.secondaryTextColor = secondaryTextColor
        self.secondaryTextFont = secondaryTextFont
        self.toggleTintColor = toggleTintColor
        self.accentColor = accentColor
        self.destructiveColor = destructiveColor
        self.permissionAuthorizedColor = permissionAuthorizedColor
        self.permissionDeniedColor = permissionDeniedColor
        self.permissionProvisionalColor = permissionProvisionalColor
        self.permissionUnknownColor = permissionUnknownColor
        self.permissionTitleFont = permissionTitleFont
        self.loadingColor = loadingColor
        self.errorIconColor = errorIconColor
        self.errorTitleColor = errorTitleColor
        self.datePickerTintColor = datePickerTintColor
    }
}

// MARK: - Style Helper Extensions

@available(iOS 14.0, *)
private extension View {
    /// Applies toggle tint color. Uses `SwitchToggleStyle(tint:)` on iOS 14,
    /// `.tint()` on iOS 15+.
    @ViewBuilder
    func applyToggleTint(_ color: Color?) -> some View {
        if let color = color {
            if #available(iOS 15.0, *) {
                self.tint(color)
            } else {
                self.toggleStyle(SwitchToggleStyle(tint: color))
            }
        } else {
            self
        }
    }

    /// Applies tint to DatePicker.
    @ViewBuilder
    func applyDatePickerTint(_ color: Color?) -> some View {
        if let color = color {
            if #available(iOS 15.0, *) {
                self.tint(color)
            } else {
                self.accentColor(color)
            }
        } else {
            self
        }
    }

    /// Applies tint to ProgressView (loading spinner).
    @ViewBuilder
    func applyLoadingTint(_ color: Color?) -> some View {
        if let color = color {
            if #available(iOS 15.0, *) {
                self.tint(color)
            } else {
                self.accentColor(color)
            }
        } else {
            self
        }
    }

    /// Applies background color to a List, hiding the default system background.
    @ViewBuilder
    func applyListBackground(_ color: Color?) -> some View {
        if let color = color {
            if #available(iOS 16.0, *) {
                self.scrollContentBackground(.hidden)
                    .background(color)
            } else {
                self.background(color)
            }
        } else {
            self
        }
    }
}

// MARK: - PreferenceCenterView

/// A drop-in SwiftUI view for displaying and managing notification preferences.
///
/// Usage:
/// ```swift
/// NavigationView {
///     PreferenceCenterView()
/// }
///
/// // With custom style:
/// PreferenceCenterView(style: PreferenceCenterStyle(
///     backgroundColor: .black,
///     primaryTextColor: .white
/// ))
/// ```
@available(iOS 14.0, *)
public struct PreferenceCenterView: View {
    @StateObject private var viewModel = PreferenceCenterViewModel()
    @State private var showDisableAlert = false
    @State private var showDisableSmsAlert = false

    private let style: PreferenceCenterStyle

    /// Creates a PreferenceCenterView with the given style.
    /// - Parameter style: Optional style override. If nil, uses `CopyLab.preferenceCenterStyle`.
    public init(style: PreferenceCenterStyle? = nil) {
        self.style = style ?? CopyLab.preferenceCenterStyle
    }
    
    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading preferences...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .applyLoadingTint(style.loadingColor)
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(style.errorIconColor ?? .orange)
                    Text("Failed to load preferences")
                        .font(.headline)
                        .foregroundColor(style.errorTitleColor)
                    Text(error.localizedDescription)
                        .font(style.secondaryTextFont ?? .caption)
                        .foregroundColor(style.secondaryTextColor ?? .secondary)
                    Button("Retry") {
                        viewModel.loadData()
                    }
                    .foregroundColor(style.accentColor)
                }
                .padding()
            } else {
                List {
                    // System Permission Card
                    Section {
                        SystemPermissionCard(
                            status: viewModel.osPermissionStatus,
                            style: style,
                            onRequestPermissions: viewModel.requestSystemPermissions,
                            onDisablePermissions: {
                                showDisableAlert = true
                            },
                            onOpenSettings: viewModel.openSystemSettings
                        )
                        .listRowBackground(style.sectionBackgroundColor)
                    }

                    // SMS Card
                    Section {
                        SmsCard(
                            smsEnabled: $viewModel.smsEnabled,
                            selectedCountry: $viewModel.selectedCountry,
                            phoneDigits: $viewModel.phoneDigits,
                            isSaving: $viewModel.isSavingPhone,
                            savedNumber: viewModel.savedPhoneE164,
                            style: style,
                            onToggle: { enabled in
                                if !enabled {
                                    showDisableSmsAlert = true
                                } else {
                                    viewModel.toggleSms(true)
                                }
                            },
                            onSave: {
                                viewModel.savePhoneNumber()
                            }
                        )
                        .listRowBackground(style.sectionBackgroundColor)
                    }

                    // Preferences Section
                    if !viewModel.preferences.isEmpty {
                        Section(header: styledHeader("Preferences")) {
                            ForEach(viewModel.preferences) { preference in
                                PreferenceToggleRow(
                                    preference: preference,
                                    isEnabled: viewModel.isPreferenceEnabled(preference.id),
                                    style: style,
                                    selectedTime: viewModel.getScheduleTime(preference.id),
                                    onToggle: { enabled in
                                        viewModel.togglePreference(preference.id, enabled: enabled)
                                    },
                                    onTimeChange: { time in
                                        viewModel.updateScheduleTime(preference.id, time: time)
                                    }
                                )
                                .listRowBackground(style.sectionBackgroundColor)
                            }
                        }
                    }

                    // Topics Section - filtered by type
                    if !viewModel.visibleTopics.isEmpty {
                        Section(header: styledHeader("Categories")) {
                            ForEach(viewModel.visibleTopics) { topic in
                                TopicToggleRow(
                                    topic: topic,
                                    isSubscribed: viewModel.isSubscribedToTopic(topic.id),
                                    style: style,
                                    onToggle: { enabled in
                                        viewModel.toggleTopic(topic.id, enabled: enabled)
                                    }
                                )
                                .listRowBackground(style.sectionBackgroundColor)
                            }
                        }
                    }

                    // Schedules Section
                    if !viewModel.schedules.isEmpty {
                        Section(header: styledHeader("Schedules")) {
                            ForEach(viewModel.schedules) { schedule in
                                ScheduleToggleRow(
                                    schedule: schedule,
                                    isEnabled: viewModel.isScheduleEnabled(schedule.id),
                                    style: style,
                                    selectedTime: viewModel.getScheduleTime(schedule.id),
                                    onToggle: { enabled in
                                        viewModel.toggleSchedule(schedule.id, enabled: enabled)
                                    },
                                    onTimeChange: { time in
                                        viewModel.updateScheduleTime(schedule.id, time: time)
                                    }
                                )
                                .listRowBackground(style.sectionBackgroundColor)
                            }
                        }
                    }

                    // Developer Tools Section
                    #if DEBUG
                    Section(header: styledHeader("Developer Tools")) {
                        Button(action: {
                            viewModel.sendTestNotification()
                        }) {
                            HStack {
                                Text("Send Test Notification (Daily Craving)")
                                    .foregroundColor(style.primaryTextColor)
                                    .font(style.primaryTextFont ?? .body)
                                Spacer()
                                Image(systemName: "paperplane")
                                    .foregroundColor(style.accentColor)
                            }
                        }
                        .listRowBackground(style.sectionBackgroundColor)

                        Button(action: {
                            viewModel.sendTestSms()
                        }) {
                            HStack {
                                Text("Send Test SMS")
                                    .foregroundColor(style.primaryTextColor)
                                    .font(style.primaryTextFont ?? .body)
                                Spacer()
                                if viewModel.isSendingTestSms {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "message")
                                        .foregroundColor(style.accentColor)
                                }
                            }
                        }
                        .disabled(viewModel.savedPhoneE164 == nil || viewModel.isSendingTestSms)
                        .listRowBackground(style.sectionBackgroundColor)
                    }
                    #endif
                }
                .listStyle(InsetGroupedListStyle())
                .applyListBackground(style.backgroundColor)
            }
        }
        .navigationTitle(style.navigationTitle)
        .alert(isPresented: $showDisableAlert) {
            Alert(
                title: Text(CopyLab.disableNotificationsAlertConfig.title),
                message: Text(CopyLab.disableNotificationsAlertConfig.message),
                primaryButton: .destructive(Text(CopyLab.disableNotificationsAlertConfig.confirmTitle)) {
                    viewModel.openSystemSettings()
                },
                secondaryButton: .cancel(Text(CopyLab.disableNotificationsAlertConfig.cancelTitle))
            )
        }
        .alert(isPresented: $showDisableSmsAlert) {
            Alert(
                title: Text("Disable SMS?"),
                message: Text("You will no longer receive SMS notifications."),
                primaryButton: .destructive(Text("Disable")) {
                    viewModel.toggleSms(false)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private func styledHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(style.sectionHeaderColor)
            .font(style.sectionHeaderFont)
    }
}

// MARK: - System Permission Card

@available(iOS 14.0, *)
private struct SystemPermissionCard: View {
    let status: String
    let style: PreferenceCenterStyle
    let onRequestPermissions: () -> Void
    let onDisablePermissions: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Push Notifications")
                        .font(style.permissionTitleFont ?? .headline)
                        .foregroundColor(style.primaryTextColor)
                    Text(statusText)
                        .font(style.secondaryTextFont ?? .caption)
                        .foregroundColor(style.secondaryTextColor ?? .secondary)
                }

                Spacer()

                if status == "authorized" || status == "provisional" {
                    Button("Disable") {
                        onDisablePermissions()
                    }
                    .foregroundColor(style.destructiveColor ?? .red)
                } else if status == "notDetermined" {
                    Button("Enable") {
                        onRequestPermissions()
                    }
                    .foregroundColor(style.accentColor)
                } else if status == "denied" {
                    Button("Enable in Settings") {
                        onOpenSettings()
                    }
                    .foregroundColor(style.accentColor)
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
        case "authorized": return style.permissionAuthorizedColor ?? .green
        case "denied": return style.permissionDeniedColor ?? .red
        case "provisional": return style.permissionProvisionalColor ?? .orange
        default: return style.permissionUnknownColor ?? .gray
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

// MARK: - SMS Card

@available(iOS 14.0, *)
private struct SmsCard: View {
    @Binding var smsEnabled: Bool
    @Binding var selectedCountry: CountryCode
    @Binding var phoneDigits: String
    @Binding var isSaving: Bool
    let savedNumber: String?
    let style: PreferenceCenterStyle
    let onToggle: (Bool) -> Void
    let onSave: () -> Void

    @State private var showCountryPicker = false

    private var e164Number: String {
        "\(selectedCountry.dialCode)\(phoneDigits)"
    }

    private var isPhoneComplete: Bool {
        phoneDigits.count == selectedCountry.maxDigits
    }

    private var isAlreadySaved: Bool {
        guard let saved = savedNumber else { return false }
        return saved == e164Number && isPhoneComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row — mirrors SystemPermissionCard layout
            HStack {
                Image(systemName: smsEnabled ? "message.fill" : "message")
                    .foregroundColor(smsEnabled
                        ? (style.permissionAuthorizedColor ?? .green)
                        : (style.permissionUnknownColor ?? .gray))
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SMS Notifications")
                        .font(style.permissionTitleFont ?? .headline)
                        .foregroundColor(style.primaryTextColor)
                    Text(smsEnabled ? "SMS enabled" : "SMS disabled")
                        .font(style.secondaryTextFont ?? .caption)
                        .foregroundColor(style.secondaryTextColor ?? .secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { smsEnabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .applyToggleTint(style.toggleTintColor)
            }

            // Phone number input — shown only when SMS is enabled
            if smsEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    // Dial-code picker + formatted number field
                    HStack(spacing: 0) {
                        Button(action: { showCountryPicker = true }) {
                            HStack(spacing: 4) {
                                Text(selectedCountry.flag)
                                    .font(.body)
                                Text(selectedCountry.dialCode)
                                    .font(style.primaryTextFont ?? .body)
                                    .foregroundColor(style.primaryTextColor)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(style.secondaryTextColor ?? .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }

                        Divider().frame(height: 24)

                        TextField(
                            selectedCountry.formatPattern.replacingOccurrences(of: "#", with: "0"),
                            text: Binding(
                                get: { selectedCountry.format(phoneDigits) },
                                set: { newVal in
                                    let digits = newVal.filter { $0.isNumber }
                                    phoneDigits = String(digits.prefix(selectedCountry.maxDigits))
                                }
                            )
                        )
                        .keyboardType(.phonePad)
                        .font(style.primaryTextFont ?? .body)
                        .foregroundColor(style.primaryTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                (style.secondaryTextColor ?? .secondary).opacity(0.3),
                                lineWidth: 1
                            )
                    )

                    // Saved indicator + save button row
                    HStack {
                        if isAlreadySaved {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("Saved")
                                    .font(style.secondaryTextFont ?? .caption)
                            }
                            .foregroundColor(style.permissionAuthorizedColor ?? .green)
                        }
                        Spacer()
                        Button(action: onSave) {
                            if isSaving {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text("Save Number")
                                    .font(style.primaryTextFont ?? .body)
                                    .foregroundColor(isPhoneComplete
                                        ? (style.accentColor ?? .blue)
                                        : (style.secondaryTextColor ?? .secondary))
                            }
                        }
                        .disabled(!isPhoneComplete || isSaving || isAlreadySaved)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: smsEnabled)
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selectedCountry: $selectedCountry)
        }
    }
}

// MARK: - Country Picker Sheet

@available(iOS 14.0, *)
private struct CountryPickerSheet: View {
    @Binding var selectedCountry: CountryCode
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""

    private var filtered: [CountryCode] {
        guard !searchText.isEmpty else { return CountryCode.all }
        return CountryCode.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.dialCode.contains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            countryList
                .navigationTitle("Select Country")
                .navigationBarItems(trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                })
        }
    }

    @ViewBuilder
    private var countryList: some View {
        if #available(iOS 15.0, *) {
            List(filtered) { country in countryRow(country) }
                .searchable(text: $searchText, prompt: "Search country or dial code")
        } else {
            List(filtered) { country in countryRow(country) }
        }
    }

    private func countryRow(_ country: CountryCode) -> some View {
        Button(action: {
            selectedCountry = country
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Text(country.flag).font(.body)
                Text(country.name).foregroundColor(.primary)
                Spacer()
                Text(country.dialCode).foregroundColor(.secondary)
                if country == selectedCountry {
                    Image(systemName: "checkmark").foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Topic Toggle Row

@available(iOS 14.0, *)
private struct TopicToggleRow: View {
    let topic: PreferenceCenterItem
    let isSubscribed: Bool
    let style: PreferenceCenterStyle
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(topic.title)
                        .font(style.primaryTextFont ?? .body)
                        .foregroundColor(style.primaryTextColor)
                        .lineLimit(nil)
                    if topic.type == .contextual {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(style.secondaryTextColor ?? .secondary)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isSubscribed },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .applyToggleTint(style.toggleTintColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preference Toggle Row

@available(iOS 14.0, *)
private struct PreferenceToggleRow: View {
    let preference: PreferenceCenterItem
    let isEnabled: Bool
    let style: PreferenceCenterStyle
    let selectedTime: Date
    let onToggle: (Bool) -> Void
    let onTimeChange: (Date) -> Void

    init(preference: PreferenceCenterItem, isEnabled: Bool, style: PreferenceCenterStyle, selectedTime: Date = Date(), onToggle: @escaping (Bool) -> Void, onTimeChange: @escaping (Date) -> Void = { _ in }) {
        self.preference = preference
        self.isEnabled = isEnabled
        self.style = style
        self.selectedTime = selectedTime
        self.onToggle = onToggle
        self.onTimeChange = onTimeChange
    }

    private var hasScheduleParam: Bool {
        preference.parameters?.schedule != nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(preference.title)
                .font(style.primaryTextFont ?? .body)
                .foregroundColor(style.primaryTextColor)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

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
                .applyDatePickerTint(style.datePickerTintColor)
            }

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .applyToggleTint(style.toggleTintColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Schedule Toggle Row

@available(iOS 14.0, *)
private struct ScheduleToggleRow: View {
    let schedule: PreferenceCenterItem
    let isEnabled: Bool
    let style: PreferenceCenterStyle
    let selectedTime: Date
    let onToggle: (Bool) -> Void
    let onTimeChange: (Date) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(schedule.title)
                .font(style.primaryTextFont ?? .body)
                .foregroundColor(style.primaryTextColor)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

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
                .applyDatePickerTint(style.datePickerTintColor)
            }

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .applyToggleTint(style.toggleTintColor)
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

    // SMS state
    @Published var smsEnabled = false
    @Published var selectedCountry: CountryCode = .defaultCountry
    @Published var phoneDigits = ""
    @Published var isSavingPhone = false
    @Published var isSendingTestSms = false
    @Published var savedPhoneE164: String? = nil
    
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

        // Load SMS state from UserDefaults
        smsEnabled = UserDefaults.standard.bool(forKey: "copylab_sms_enabled")
        if let savedE164 = UserDefaults.standard.string(forKey: "copylab_sms_phone_e164") {
            savedPhoneE164 = savedE164
            if let (country, digits) = parseE164(savedE164) {
                selectedCountry = country
                phoneDigits = digits
            }
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
        // Send both the time AND the enabled state — if the schedule is enabled by
        // default the server may never have received the toggle, so we always confirm
        // it is enabled when the user is actively setting a time for it.
        let isEnabled = scheduleStates[scheduleId] ?? true
        CopyLab.updateNotificationPreferences(
            schedules: [scheduleId: isEnabled],
            scheduleTimes: [scheduleId: timeStr]
        ) { result in
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
    
    func requestSystemPermissions() {
        CopyLab.requestNotificationPermission { [weak self] granted, error in
            if let error = error {
                print("⚠️ CopyLab: Error requesting permissions: \(error.localizedDescription)")
            }
            // Status is automatically synced by the SDK, just refresh local state
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                DispatchQueue.main.async {
                    self?.osPermissionStatus = self?.mapAuthorizationStatus(settings.authorizationStatus) ?? "unknown"
                }
            }
        }
    }
    
    // MARK: - Actions
    
    func sendTestNotification() {
        print("🔍 CopyLab: Requesting test notification...")
        CopyLab.sendTestNotification(placementId: "daily_nomi_craving") { [weak self] result in
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
    
    func toggleSms(_ enabled: Bool) {
        smsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "copylab_sms_enabled")
    }

    func savePhoneNumber() {
        let e164 = selectedCountry.dialCode + phoneDigits
        guard phoneDigits.count == selectedCountry.maxDigits else { return }
        isSavingPhone = true
        // Optimistic update — persist locally then fire API in background
        UserDefaults.standard.set(e164, forKey: "copylab_sms_phone_e164")
        savedPhoneE164 = e164
        isSavingPhone = false
        CopyLab.registerPhoneNumber(e164)
    }

    func sendTestSms() {
        isSendingTestSms = true
        CopyLab.sendTestSms { [weak self] result in
            DispatchQueue.main.async {
                self?.isSendingTestSms = false
                if case .failure(let error) = result {
                    print("⚠️ CopyLab: Test SMS failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func parseE164(_ e164: String) -> (CountryCode, String)? {
        let matches = CountryCode.all.filter { e164.hasPrefix($0.dialCode) }
        guard let country = matches.max(by: { $0.dialCode.count < $1.dialCode.count }) else {
            return nil
        }
        let digits = String(e164.dropFirst(country.dialCode.count))
        return (country, digits)
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
