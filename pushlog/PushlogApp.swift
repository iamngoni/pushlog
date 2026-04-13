import SwiftUI

@main
struct PushlogApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = PushLogStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                store.syncFromICloud()
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
