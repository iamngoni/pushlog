import SwiftUI

struct RootView: View {
    @State private var selectedTab: PushlogTab = .today
    @State private var isPresentingLive = false

    var body: some View {
        Group {
            switch selectedTab {
            case .today:
                TodayScreen(selectedTab: $selectedTab, isPresentingLive: $isPresentingLive)
            case .history:
                HistoryScreen(selectedTab: $selectedTab)
            }
        }
        .fullScreenCover(isPresented: $isPresentingLive) {
            LiveFlowView(isPresented: $isPresentingLive)
        }
    }
}
