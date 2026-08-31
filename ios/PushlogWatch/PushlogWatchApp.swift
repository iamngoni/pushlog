// Pushlog's Apple Watch companion entry point.

import HealthKit
import SwiftUI
import WatchKit

extension Notification.Name {
    static let pushlogWorkoutConfigurationReceived = Notification.Name("pushlogWorkoutConfigurationReceived")
}

final class WatchExtensionDelegate: NSObject, WKApplicationDelegate {
    private let pendingLaunchLock = NSLock()
    private var hasPendingWorkoutConfiguration = false

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        pendingLaunchLock.lock()
        hasPendingWorkoutConfiguration = true
        pendingLaunchLock.unlock()
        NotificationCenter.default.post(name: .pushlogWorkoutConfigurationReceived, object: nil)
    }

    func consumePendingWorkoutConfiguration() -> Bool {
        pendingLaunchLock.lock()
        defer { pendingLaunchLock.unlock() }
        let wasPending = hasPendingWorkoutConfiguration
        hasPendingWorkoutConfiguration = false
        return wasPending
    }
}

@main
struct PushlogWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchExtensionDelegate.self) private var extensionDelegate
    @StateObject private var sessionManager = WatchSessionManager()
    @StateObject private var workoutManager = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(sessionManager)
                .environmentObject(workoutManager)
                .onAppear {
                    sessionManager.workoutManager = workoutManager
                    workoutManager.watchSessionManager = sessionManager
                    workoutManager.requestAuthorization()
                    // A normal manual launch must recover the phone's pending
                    // workout too, not only launches initiated by HealthKit.
                    sessionManager.handleWorkoutConfigurationLaunch()
                    _ = extensionDelegate.consumePendingWorkoutConfiguration()
                }
                .onReceive(NotificationCenter.default.publisher(for: .pushlogWorkoutConfigurationReceived)) { _ in
                    _ = extensionDelegate.consumePendingWorkoutConfiguration()
                    sessionManager.handleWorkoutConfigurationLaunch()
                }
        }
    }
}
