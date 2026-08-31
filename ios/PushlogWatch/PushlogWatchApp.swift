// Pushlog's Apple Watch companion entry point.

import HealthKit
import SwiftUI
import WatchKit

@MainActor
final class WatchExtensionDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        // HealthKit launches the app in the background and calls this delegate
        // before SwiftUI is guaranteed to appear. Start the handoff here so
        // the Watch can create its HKWorkoutSession and acknowledge the phone.
        WatchRuntime.shared.handle(workoutConfiguration)
    }
}

@MainActor
final class WatchRuntime {
    static let shared = WatchRuntime()

    let sessionManager: WatchSessionManager
    let workoutManager: WatchWorkoutManager

    private init() {
        let sessionManager = WatchSessionManager()
        let workoutManager = WatchWorkoutManager()
        self.sessionManager = sessionManager
        self.workoutManager = workoutManager
        sessionManager.workoutManager = workoutManager
        workoutManager.watchSessionManager = sessionManager
        workoutManager.requestAuthorization()
    }

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        sessionManager.handleWorkoutConfigurationLaunch(workoutConfiguration)
    }

    func handleForegroundLaunch() {
        sessionManager.handleWorkoutConfigurationLaunch()
    }
}

@main
struct PushlogWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchExtensionDelegate.self) private var extensionDelegate
    @StateObject private var sessionManager: WatchSessionManager
    @StateObject private var workoutManager: WatchWorkoutManager

    init() {
        let runtime = WatchRuntime.shared
        _sessionManager = StateObject(wrappedValue: runtime.sessionManager)
        _workoutManager = StateObject(wrappedValue: runtime.workoutManager)
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(sessionManager)
                .environmentObject(workoutManager)
                .onAppear {
                    // A normal manual launch must recover the phone's pending
                    // workout too, not only launches initiated by HealthKit.
                    WatchRuntime.shared.handleForegroundLaunch()
                }
        }
    }
}
