// Root navigation for the companion watch app.

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        Group {
            if session.isLiveActive {
                WatchLiveView()
            } else if session.isAwaitingEffort {
                WatchEffortView()
            } else {
                WatchTodayView()
            }
        }
        .animation(.easeInOut, value: session.isLiveActive)
    }
}
