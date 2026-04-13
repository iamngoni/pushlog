import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var store: PushLogStore
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: PushlogTab
    @State private var editingSession: WorkoutSessionRecord?

    private var theme: AppTheme {
        AppTheme.resolve(for: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                monthBlock
                Divider()
                    .overlay(theme.divider)
                    .padding(.top, 18)
                historyBody
                    .padding(.top, 20)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomTabBar(selectedTab: $selectedTab, theme: theme)
                .background(theme.background)
        }
        .sheet(item: $editingSession) { session in
            SessionCorrectionSheet(session: session, theme: theme) { reps in
                store.updateSessionReps(reps, for: session.id)
            } onDelete: {
                store.deleteSession(session.id)
            }
        }
    }

    private var header: some View {
        WordmarkHeader(
            trailingText: DateFormatter.historyMonth.string(from: .now).uppercased(),
            theme: theme
        )
        .padding(.top, 8)
    }

    private var monthBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(store.monthSummary.total)")
                .font(.pressDisplay(120))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 18) {
                StatColumn(value: "\(store.monthSummary.best)", label: "BEST", theme: theme)
                StatColumn(value: "\(store.monthSummary.average)", label: "AVG", theme: theme)
                StatColumn(value: "\(store.monthSummary.liveSessions)", label: "LIVE", theme: theme)
            }
        }
        .padding(.top, 18)
    }

    private var historyBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if store.historyEntries.isEmpty {
                    emptyState
                } else {
                    SectionLabel(title: "DAYS", theme: theme)
                    dailyList

                    if !store.recentSessions.isEmpty {
                        SectionLabel(title: "SESSIONS", theme: theme)
                            .padding(.top, 28)
                        sessionList
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var dailyList: some View {
        LazyVStack(spacing: 0) {
            ForEach(store.historyEntries) { entry in
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(HistoryCopy.rowTitle(for: entry.date))
                            .font(.pressMono(11))
                            .tracking(1.6)
                            .foregroundStyle(entry.isToday ? theme.accentInk : theme.secondaryInk)

                        Spacer()

                        Text("\(entry.count)")
                            .font(.pressDisplay(42))
                            .foregroundStyle(entry.isToday ? theme.accentInk : theme.ink)
                    }
                    .padding(.vertical, 14)

                    Rectangle()
                        .fill(theme.divider)
                        .frame(height: 1)
                }
            }
        }
        .padding(.top, 10)
    }

    private var sessionList: some View {
        LazyVStack(spacing: 0) {
            ForEach(store.recentSessions.prefix(12)) { session in
                SessionRow(session: session, theme: theme) {
                    editingSession = session
                }
            }
        }
        .padding(.top, 10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NO LOGS YET")
                .font(.pressDisplay(42))
                .foregroundStyle(theme.ink)
            Text("ADD REPS FROM TODAY OR START A LIVE SESSION.")
                .font(.pressMono(10))
                .tracking(1.5)
                .foregroundStyle(theme.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }
}

private struct SessionRow: View {
    let session: WorkoutSessionRecord
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        SessionSourceBadge(source: session.source, theme: theme)

                        Text(HistoryCopy.sessionHeadline(for: session))
                            .font(.pressMono(10))
                            .tracking(1.2)
                            .foregroundStyle(theme.ink)

                        Text(HistoryCopy.sessionMeta(for: session))
                            .font(.pressMono(9))
                            .tracking(1.0)
                            .foregroundStyle(theme.secondaryInk)
                            .lineSpacing(4)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(session.reps)")
                            .font(.pressDisplay(42))
                            .foregroundStyle(theme.ink)

                        Text("EDIT")
                            .font(.pressMono(9))
                            .tracking(1.6)
                            .foregroundStyle(theme.secondaryInk)
                    }
                }
                .padding(.vertical, 14)

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SessionCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSessionRecord
    let theme: AppTheme
    let onSave: (Int) -> Void
    let onDelete: () -> Void

    @State private var reps: Int
    @State private var showDeleteConfirmation = false

    init(
        session: WorkoutSessionRecord,
        theme: AppTheme,
        onSave: @escaping (Int) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.session = session
        self.theme = theme
        self.onSave = onSave
        self.onDelete = onDelete
        _reps = State(initialValue: session.reps)
    }

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                WordmarkHeader(trailingText: "EDIT LOG", theme: theme)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    SessionSourceBadge(source: session.source, theme: theme)

                    Text(HistoryCopy.sessionHeadline(for: session))
                        .font(.pressMono(10))
                        .tracking(1.6)
                        .foregroundStyle(theme.secondaryInk)

                    Text("\(reps)")
                        .font(.pressDisplay(120))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 12) {
                        Text(deltaLabel)
                            .font(.pressMono(10))
                            .tracking(1.5)
                            .foregroundStyle(isDirty ? theme.accentInk : theme.secondaryInk)

                        Text(HistoryCopy.sessionMeta(for: session))
                            .font(.pressMono(9))
                            .tracking(1.0)
                            .foregroundStyle(theme.secondaryInk)
                    }
                }
                .padding(.top, 24)

                Divider()
                    .overlay(theme.divider)
                    .padding(.top, 18)

                SectionLabel(title: "CORRECT", theme: theme)
                    .padding(.top, 22)

                correctionStrips
                    .padding(.top, 12)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
                .background(theme.background)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("DELETE THIS LOG?", isPresented: $showDeleteConfirmation) {
            Button("DELETE", role: .destructive) {
                onDelete()
                dismiss()
            }

            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("THIS WILL REMOVE \(session.reps) REPS FROM \(HistoryCopy.rowTitle(for: session.date)).")
        }
    }

    private var correctionStrips: some View {
        VStack(spacing: 0) {
            adjustmentStrip(values: [-25, -10, -1])
            adjustmentStrip(values: [1, 10, 25], emphasizedValue: 1)
        }
        .overlay {
            Rectangle()
                .stroke(theme.divider, lineWidth: 1)
        }
    }

    private var actionBar: some View {
        ActionStrip(theme: theme) {
            ActionCell(title: "DELETE", subtitle: nil, emphasized: false, theme: theme) {
                showDeleteConfirmation = true
            }
            divider
            ActionCell(title: "CANCEL", subtitle: nil, emphasized: false, theme: theme) {
                dismiss()
            }
            divider
            ActionCell(
                title: "SAVE",
                subtitle: nil,
                emphasized: true,
                isEnabled: isDirty,
                theme: theme
            ) {
                onSave(reps)
                dismiss()
            }
        }
    }

    private var isDirty: Bool {
        reps != session.reps
    }

    private var deltaLabel: String {
        let delta = reps - session.reps

        if delta == 0 {
            return "UNCHANGED"
        }

        return delta > 0 ? "+\(delta) CORRECTION" : "\(delta) CORRECTION"
    }

    @ViewBuilder
    private func adjustmentStrip(values: [Int], emphasizedValue: Int? = nil) -> some View {
        ActionStrip(theme: theme) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                ActionCell(
                    title: value > 0 ? "+\(value)" : "\(value)",
                    subtitle: nil,
                    emphasized: emphasizedValue == value,
                    isEnabled: canApply(value),
                    theme: theme
                ) {
                    apply(value)
                }

                if index < values.count - 1 {
                    divider
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.divider)
            .frame(width: 1)
    }

    private func canApply(_ delta: Int) -> Bool {
        reps + delta >= 1
    }

    private func apply(_ delta: Int) {
        reps = max(1, reps + delta)
    }
}

private enum HistoryCopy {
    private static let calendar = Calendar.current

    static func rowTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "TODAY"
        }

        return DateFormatter.historyRow.string(from: date).uppercased()
    }

    static func sessionHeadline(for session: WorkoutSessionRecord) -> String {
        let timeLabel = DateFormatter.sessionTime.string(from: session.date).uppercased()
        let dayLabel = rowTitle(for: session.date)
        return "\(dayLabel) · \(timeLabel)"
    }

    static func sessionMeta(for session: WorkoutSessionRecord) -> String {
        switch session.source {
        case .manual:
            return "MANUAL ENTRY"
        case .live:
            var segments: [String] = ["LIVE TRACK"]

            if let duration = session.duration {
                let minutes = Int(duration) / 60
                let seconds = Int(duration) % 60
                segments.append(String(format: "%02d:%02d", minutes, seconds))
            }

            if let averageRepDuration = session.averageRepDuration {
                segments.append(String(format: "%.1FS PACE", averageRepDuration))
            }

            if session.manualAdjustments > 0 {
                segments.append("+\(session.manualAdjustments) ADJUST")
            }

            return segments.joined(separator: " · ")
        }
    }
}

private extension DateFormatter {
    static let historyRow: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE dd MMM"
        return formatter
    }()

    static let historyMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let sessionTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
