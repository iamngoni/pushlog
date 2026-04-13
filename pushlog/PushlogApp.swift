import SwiftUI

@main
struct PushlogApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = PushLogStore()
    @StateObject private var reminderManager = ReminderManager()
    @StateObject private var healthKitManager = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(reminderManager)
                .environmentObject(healthKitManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                store.syncFromICloud()
                Task {
                    await reminderManager.refreshStatus()
                    if store.preferences.reminders.isEnabled {
                        await reminderManager.syncSchedule(using: store.preferences.reminders)
                    }
                }
                healthKitManager.refreshAuthorization()
            case .background:
                store.flushToICloud()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
