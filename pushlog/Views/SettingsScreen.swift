import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @EnvironmentObject private var store: PushLogStore
    @EnvironmentObject private var reminderManager: ReminderManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: PushlogTab

    @State private var reminderTime = Date()
    @State private var exportDocument: PushlogExportDocument?
    @State private var isExporting = false
    @State private var showResetConfirmation = false

    private var theme: AppTheme {
        AppTheme.resolve(for: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        syncSection
                        remindersSection
                            .padding(.top, 32)
                        healthSection
                            .padding(.top, 32)
                        dataSection
                            .padding(.top, 32)
                    }
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomTabBar(selectedTab: $selectedTab, theme: theme)
                .background(theme.background)
        }
        .task {
            reminderTime = reminderDate
            await reminderManager.refreshStatus()
            healthKitManager.refreshAuthorization()
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "pushlog-export"
        ) { _ in
            exportDocument = nil
        }
        .alert("RESET PUSHLOG?", isPresented: $showResetConfirmation) {
            Button("RESET", role: .destructive) {
                store.resetAllData()
                reminderTime = reminderDate
                Task {
                    await reminderManager.syncSchedule(using: store.preferences.reminders)
                    healthKitManager.refreshAuthorization()
                }
            }

            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("THIS CLEARS HISTORY, LIVE LOGS, REMINDERS, AND HEALTH SYNC PREFERENCES.")
        }
    }

    private var header: some View {
        WordmarkHeader(trailingText: "SETTINGS", theme: theme)
            .padding(.top, 8)
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "SYNC", theme: theme)
            settingsCard {
                settingsRow(
                    title: store.iCloudAvailable ? "ICLOUD BACKUP" : "LOCAL STORAGE",
                    detail: store.iCloudAvailable ? "AUTOMATIC" : "SIGNED OUT OF ICLOUD"
                )
                divider
                settingsRow(
                    title: "LAST SYNC",
                    detail: store.lastCloudSyncAt.map(Self.settingsDateFormatter.string(from:)) ?? "WAITING"
                )
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "REMINDERS", theme: theme)
            settingsCard {
                toggleRow(
                    title: "DAILY REMINDER",
                    detail: reminderManager.statusLabel,
                    isOn: Binding(
                        get: { store.preferences.reminders.isEnabled },
                        set: { value in
                            store.setRemindersEnabled(value)
                            Task {
                                if value {
                                    let granted = await reminderManager.requestAuthorizationIfNeeded()
                                    if granted {
                                        await reminderManager.syncSchedule(using: store.preferences.reminders)
                                    } else {
                                        store.setRemindersEnabled(false)
                                    }
                                } else {
                                    await reminderManager.syncSchedule(using: store.preferences.reminders)
                                }
                            }
                        }
                    )
                )
                divider
                VStack(alignment: .leading, spacing: 10) {
                    settingsRow(
                        title: "NEXT FIRE",
                        detail: reminderManager.nextReminderDate.map(Self.settingsDateFormatter.string(from:)) ?? "NONE SCHEDULED"
                    )

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { reminderTime },
                            set: { value in
                                reminderTime = value
                                store.setReminderTime(date: value)
                                Task {
                                    await reminderManager.syncSchedule(using: store.preferences.reminders)
                                }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .disabled(!store.preferences.reminders.isEnabled || !reminderManager.isAuthorized)
                    .colorScheme(colorScheme)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                divider
                toggleRow(
                    title: "SMART COPY",
                    detail: reminderManager.smartCopyLabel,
                    isOn: Binding(
                        get: { store.preferences.reminders.useSmartCopy },
                        set: { value in
                            store.setSmartReminderCopyEnabled(value)
                            Task {
                                await reminderManager.syncSchedule(using: store.preferences.reminders)
                            }
                        }
                    )
                )
            }
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "HEALTH", theme: theme)
            settingsCard {
                toggleRow(
                    title: "HEALTHKIT SYNC",
                    detail: healthKitManager.statusLabel,
                    isOn: Binding(
                        get: { store.preferences.healthSyncEnabled },
                        set: { value in
                            Task {
                                if value {
                                    let granted = await healthKitManager.requestAuthorizationIfNeeded()
                                    store.setHealthSyncEnabled(granted)
                                } else {
                                    store.setHealthSyncEnabled(false)
                                }
                            }
                        }
                    )
                )
                divider
                settingsRow(
                    title: "LIVE SESSION EXPORT",
                    detail: "SAVES AS FUNCTIONAL STRENGTH WORKOUTS"
                )
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "DATA", theme: theme)
            settingsCard {
                Button {
                    if let data = try? store.exportData() {
                        exportDocument = PushlogExportDocument(data: data)
                        isExporting = true
                    }
                } label: {
                    settingsRow(title: "EXPORT JSON", detail: "SHARE RAW PUSHLOG DATA")
                }
                .buttonStyle(.plain)
                divider
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    settingsRow(title: "RESET APP DATA", detail: "CLEAR HISTORY + PREFERENCES", accent: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reminderDate: Date {
        let components = DateComponents(
            calendar: Calendar.current,
            hour: store.preferences.reminders.hour,
            minute: store.preferences.reminders.minute
        )
        return Calendar.current.date(from: components) ?? .now
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.divider)
            .frame(height: 1)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(theme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(theme.divider, lineWidth: 1)
        }
        .padding(.top, 12)
    }

    private func settingsRow(title: String, detail: String, accent: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.pressMono(10))
                .tracking(1.8)
                .foregroundStyle(accent ? theme.accentInk : theme.ink)

            Spacer()

            Text(detail)
                .font(.pressMono(10))
                .tracking(1.2)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(accent ? theme.accentInk : theme.secondaryInk)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.pressMono(10))
                    .tracking(1.8)
                    .foregroundStyle(theme.ink)

                Text(detail)
                    .font(.pressMono(10))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryInk)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.accent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private static let settingsDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE dd MMM · HH:mm"
        return formatter
    }()
}

private struct PushlogExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
