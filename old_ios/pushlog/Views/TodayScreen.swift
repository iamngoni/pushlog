import SwiftUI

struct TodayScreen: View {
    @EnvironmentObject private var store: PushLogStore
    @EnvironmentObject private var friendsService: FriendsService
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
                leaderboardBlock
                    .padding(.top, 20)
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

    private var leaderboardBlock: some View {
        let entries = friendsService.leaderboard(myName: "Me", myCount: store.todayCount)
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "FRIENDS TODAY", theme: theme)
                .padding(.bottom, 10)
            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRow(rank: index + 1, entry: entry, theme: theme)
                    if index < min(entries.count, 5) - 1 {
                        Rectangle()
                            .fill(theme.divider)
                            .frame(height: 1)
                    }
                }
            }
        }
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

private struct LeaderboardRow: View {
    let rank: Int
    let entry: FriendEntry
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.pressMono(10))
                .foregroundStyle(theme.secondaryInk)
                .frame(width: 12, alignment: .trailing)

            ZStack {
                Circle()
                    .fill(entry.isMe ? theme.accent : theme.divider)
                    .frame(width: 22, height: 22)
                Text(entry.initials)
                    .font(.pressMono(8, weight: .medium))
                    .foregroundStyle(entry.isMe ? Color(hex: 0x0A0908) : theme.ink)
            }

            Text(entry.name.uppercased())
                .font(.pressMono(11))
                .tracking(0.4)
                .foregroundStyle(entry.isMe ? theme.ink : theme.secondaryInk)
                .lineLimit(1)

            Spacer()

            Text("\(entry.todayCount)")
                .font(.pressMono(13, weight: .medium))
                .foregroundStyle(entry.isMe ? theme.accentInk : theme.ink)
        }
        .padding(.vertical, 8)
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
