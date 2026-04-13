import SwiftUI

struct TodayScreen: View {
    @EnvironmentObject private var store: PushLogStore
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: PushlogTab
    @Binding var isPresentingLive: Bool

    private var theme: AppTheme {
        AppTheme.resolve(for: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                countBlock
                Divider()
                    .overlay(theme.divider)
                    .padding(.top, 18)
                DayStripView(summary: store.weekSummary, theme: theme)
                    .padding(.top, 14)
                Spacer()
                statsBlock
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let pendingUndo = store.pendingUndo {
                    UndoStrip(reps: pendingUndo.reps, theme: theme) {
                        store.undoLastManualEntry()
                    }
                }
                actionStrip
                BottomTabBar(selectedTab: $selectedTab, theme: theme)
            }
            .background(theme.background)
        }
        .preferredColorScheme(colorScheme)
    }

    private var header: some View {
        WordmarkHeader(trailingText: DateFormatter.todayLabel.string(from: .now), theme: theme)
            .padding(.top, 8)
    }

    private var countBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(store.todayCount)")
                .font(.pressDisplay(150))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("TODAY")
                .font(.pressMono(10))
                .tracking(1.6)
                .foregroundStyle(theme.secondaryInk)
                .padding(.top, -8)
        }
        .padding(.top, 18)
    }

    private var statsBlock: some View {
        HStack(spacing: 18) {
            StatColumn(value: twoDigit(store.streak), label: "STREAK", theme: theme)
            StatColumn(value: "\(store.bestDay)", label: "BEST", theme: theme)
            StatColumn(value: abbreviated(store.totalAllTime), label: "ALL TIME", theme: theme)
        }
        .padding(.bottom, 20)
    }

    private var actionStrip: some View {
        ActionStrip(theme: theme) {
            ActionCell(title: "+1", subtitle: "REP", emphasized: true, theme: theme) {
                store.addManualReps(1)
            }
            divider
            ActionCell(title: "+10", subtitle: "SET", emphasized: false, theme: theme) {
                store.addManualReps(10)
            }
            divider
            ActionCell(title: "+25", subtitle: "BIG", emphasized: false, theme: theme) {
                store.addManualReps(25)
            }
            divider
            ActionCell(title: "LIVE", subtitle: "AUTO", emphasized: false, theme: theme) {
                isPresentingLive = true
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.divider)
            .frame(width: 1)
    }

    private func twoDigit(_ value: Int) -> String {
        value.formatted(.number.precision(.integerLength(2...)))
    }

    private func abbreviated(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000.0)
        }
        return "\(value)"
    }
}

private extension DateFormatter {
    static let todayLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE dd MMM"
        return formatter
    }()
}
