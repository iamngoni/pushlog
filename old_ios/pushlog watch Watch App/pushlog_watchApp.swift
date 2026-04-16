//
//  pushlog_watchApp.swift
//  pushlog watch Watch App
//
//  Created by Ngonidzashe  Mangudya on 2026/04/15.
//

import HealthKit
import SwiftUI
import WatchKit

extension Notification.Name {
    static let pushlogWorkoutConfigurationReceived = Notification.Name("pushlogWorkoutConfigurationReceived")
}

final class WatchExtensionDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        NotificationCenter.default.post(name: .pushlogWorkoutConfigurationReceived, object: nil)
    }
}

@main
struct pushlog_watch_Watch_AppApp: App {
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
                }
                .onReceive(NotificationCenter.default.publisher(for: .pushlogWorkoutConfigurationReceived)) { _ in
                    sessionManager.handleWorkoutConfigurationLaunch()
                }
        }
    }
}
