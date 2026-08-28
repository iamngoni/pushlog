// Live workout metrics and controls on Apple Watch.

import SwiftUI

private func formatElapsed(_ seconds: Double) -> String {
    let total = Int(seconds)
    let mm = total / 60
    let ss = total % 60
    return String(format: "%02d:%02d", mm, ss)
}

private func formatCalories(_ calories: Double) -> String {
    guard calories > 0 else { return "--" }
    return "\(Int(calories.rounded()))"
}

struct WatchLiveView: View {
    @EnvironmentObject private var session: WatchSessionManager
    @EnvironmentObject private var workout: WatchWorkoutManager

    private let ink = Color(hex: 0xF8F5F0)
    private let secondary = Color(hex: 0x706D68)
    private let accent = Color(hex: 0xD7FF1F)
    private let danger = Color(hex: 0xFF4D45)

    private var bpmText: String {
        let bpm = max(session.currentHeartRate, workout.heartRate)
        return bpm > 0 ? "\(Int(bpm.rounded()))" : "--"
    }

    private var statusText: String {
        if session.isPaused || workout.isPaused {
            return "PAUSED"
        }
        return session.trackingState.isEmpty ? "TRACKING" : session.trackingState
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(statusText)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(session.isPaused || workout.isPaused ? danger : accent)

                Spacer()

                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)

                Text("LIVE")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(secondary)
            }

            Spacer(minLength: 8)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(formatElapsed(session.elapsed(at: context.date)))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
            }

            Text("WORKOUT TIME")
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(secondary)
                .padding(.top, 1)

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                MetricPill(
                    value: formatCalories(workout.activeCalories),
                    label: "CAL",
                    accent: accent,
                    ink: ink,
                    secondary: secondary
                )

                MetricPill(
                    value: bpmText,
                    label: "BPM",
                    accent: danger,
                    ink: ink,
                    secondary: secondary
                )
            }

            Spacer(minLength: 8)

            PauseEndControl(accent: accent, danger: danger, ink: ink, secondary: secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color(hex: 0x0A0908))
    }
}

private struct MetricPill: View {
    let value: String
    let label: String
    let accent: Color
    let ink: Color
    let secondary: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(value == "--" ? secondary : ink)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.07))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

struct WatchEffortView: View {
    @EnvironmentObject private var session: WatchSessionManager

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)
    private let ink = Color(hex: 0xF8F5F0)
    private let secondary = Color(hex: 0x706D68)
    private let accent = Color(hex: 0xD7FF1F)

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("SESSION EFFORT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(secondary)

                Text(session.effortScore.map { "\($0) / 10" } ?? "HOW HARD?")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(ink)

                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(1...10, id: \.self) { score in
                        Button {
                            session.setEffort(score)
                        } label: {
                            Text("\(score)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(session.effortScore == score ? Color.black : ink)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(session.effortScore == score ? accent : Color.white.opacity(0.09))
                        )
                    }
                }

                Text("Finish saving on iPhone")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .background(Color(hex: 0x0A0908))
    }
}

private struct PauseEndControl: View {
    @EnvironmentObject private var session: WatchSessionManager
    @EnvironmentObject private var workout: WatchWorkoutManager

    let accent: Color
    let danger: Color
    let ink: Color
    let secondary: Color

    @State private var holdProgress: CGFloat = 0
    @State private var holdStartedAt: Date?
    @State private var holdCompleted = false
    @State private var holdTask: Task<Void, Never>?

    private var isPaused: Bool {
        session.isPaused || workout.isPaused
    }

    private var title: String {
        isPaused ? "RESUME" : "PAUSE"
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.10))

            Capsule()
                .fill(danger)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: holdProgress, y: 1, anchor: .leading)

            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(ink)

                Text("HOLD END")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(holdProgress > 0.15 ? ink.opacity(0.72) : secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 36)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    beginHoldIfNeeded()
                }
                .onEnded { _ in
                    finishPress()
                }
        )
        .onDisappear {
            cancelHold(animated: false)
        }
    }

    private func beginHoldIfNeeded() {
        guard holdTask == nil else { return }

        holdStartedAt = Date()
        holdCompleted = false

        withAnimation(.linear(duration: 3.0)) {
            holdProgress = 1
        }

        holdTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                holdCompleted = true
                session.requestEndFromWatch()
            }
        }
    }

    private func finishPress() {
        let elapsed = holdStartedAt.map { Date().timeIntervalSince($0) } ?? 0

        if !holdCompleted, elapsed < 0.65 {
            session.togglePauseFromWatch()
        }

        cancelHold(animated: true)
    }

    private func cancelHold(animated: Bool) {
        holdTask?.cancel()
        holdTask = nil
        holdStartedAt = nil

        let reset = {
            holdProgress = 0
            holdCompleted = false
        }

        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                reset()
            }
        } else {
            reset()
        }
    }
}
