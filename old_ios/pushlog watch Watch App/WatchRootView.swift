//
//  WatchRootView.swift
//  pushlog watch Watch App
//

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        Group {
            if session.isLiveActive {
                WatchLiveView()
            } else {
                WatchTodayView()
            }
        }
        .animation(.easeInOut, value: session.isLiveActive)
    }
}
