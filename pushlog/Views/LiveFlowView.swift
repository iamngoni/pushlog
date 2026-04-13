import SwiftUI
import UIKit

struct LiveFlowView: View {
    @EnvironmentObject private var store: PushLogStore
    @Environment(\.colorScheme) private var colorScheme

    @Binding var isPresented: Bool
    @State private var step: Step = .setup
    @State private var completedSession: LiveSessionResult?
    @StateObject private var tracker = FaceTrackingSessionController()

    private enum Step {
        case setup
        case tracking
        case summary
    }

    var body: some View {
        Group {
            switch step {
            case .setup:
                LiveSetupScreen(
                    tracker: tracker,
                    dismiss: { isPresented = false },
                    start: {
                        step = .tracking
                        tracker.startTracking()
                    }
                )
            case .tracking:
                LiveTrackingScreen(
                    tracker: tracker,
                    end: {
                        completedSession = tracker.finishSession()
                        step = .summary
                    }
                )
            case .summary:
                if let completedSession {
                    LiveSummaryScreen(
                        result: completedSession,
                        dismiss: { isPresented = false },
                        retry: {
                            self.completedSession = nil
                            step = .setup
                        },
                        save: {
                            store.saveLiveSession(completedSession)
                            isPresented = false
                        }
                    )
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .onDisappear {
            tracker.resetForNewSession()
        }
    }
}

private struct LiveSetupScreen: View {
    @ObservedObject var tracker: FaceTrackingSessionController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    let dismiss: () -> Void
    let start: () -> Void

    private var theme: AppTheme {
        AppTheme.resolve(for: colorScheme)
    }

    private var primaryActionTitle: String {
        guard tracker.isSupported else { return "UNAVAILABLE" }
        return tracker.cameraAccess == .denied ? "SETTINGS" : "START"
    }

    private var canTriggerPrimaryAction: Bool {
        tracker.isSupported || tracker.cameraAccess == .denied
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                topBar
                content
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ActionStrip(theme: theme) {
                ActionCell(title: "EXIT", subtitle: nil, emphasized: false, theme: theme, action: dismiss)
                Rectangle().fill(theme.divider).frame(width: 1)
                ActionCell(
                    title: primaryActionTitle,
                    subtitle: nil,
                    emphasized: tracker.canStartSession,
                    isEnabled: canTriggerPrimaryAction,
                    theme: theme
                ) {
                    if tracker.cameraAccess == .denied {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    } else {
                        start()
                    }
                }
            }
            .background(theme.background)
        }
    }

    private var topBar: some View {
        WordmarkHeader(trailingText: "GUIDED LIVE", theme: theme)
            .padding(.top, 8)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LIVE")
                .font(.pressDisplay(132))
                .foregroundStyle(theme.ink)
                .padding(.top, 22)

            Text(tracker.setupTitle)
                .font(.pressMono(10))
                .tracking(1.6)
                .foregroundStyle(tracker.canStartSession ? theme.secondaryInk : theme.accent)

            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)

            RoundedRectangle(cornerRadius: 28)
                .stroke(theme.divider, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 28).fill(theme.surface))
                .frame(height: 286)
                .overlay(alignment: .topLeading) {
                    Text("CAM CHECK")
                        .font(.pressMono(10))
                        .tracking(1.8)
                        .foregroundStyle(theme.secondaryInk)
                        .padding(18)
                }
                .overlay {
                    VStack(spacing: 16) {
                        Circle()
                            .stroke(theme.ink, lineWidth: 2)
                            .frame(width: 90, height: 90)

                        Rectangle()
                            .fill(theme.ink)
                            .frame(width: 184, height: 2)
                    }
                }

            Text(tracker.setupChecklist)
                .font(.pressMono(11))
                .tracking(1.1)
                .foregroundStyle(tracker.cameraAccess == .denied || !tracker.isSupported ? theme.accent : theme.ink)
                .lineSpacing(6)
                .padding(.top, 2)

            Text(tracker.setupFootnote)
                .font(.pressMono(10))
                .tracking(1.0)
                .foregroundStyle(theme.secondaryInk)
                .lineSpacing(5)
                .padding(.top, 6)
        }
    }
}

private struct LiveTrackingScreen: View {
    @ObservedObject var tracker: FaceTrackingSessionController
    @Environment(\.colorScheme) private var colorScheme

    let end: () -> Void

    private var theme: AppTheme {
        AppTheme.resolve(for: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                topBar
                trackingContent
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ActionStrip(theme: theme) {
                ActionCell(title: tracker.phase == .paused ? "RESUME" : "PAUSE", subtitle: nil, emphasized: false, theme: theme) {
                    tracker.togglePause()
                }
                Rectangle().fill(theme.divider).frame(width: 1)
                ActionCell(title: "+1", subtitle: nil, emphasized: false, theme: theme) {
                    tracker.addManualRep()
                }
                Rectangle().fill(theme.divider).frame(width: 1)
                ActionCell(title: "END", subtitle: nil, emphasized: true, theme: theme, action: end)
            }
            .background(theme.background)
        }
    }

    private var topBar: some View {
        WordmarkHeader(trailingText: "AUTO LIVE", theme: theme)
            .padding(.top, 8)
    }

    private var trackingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tracker.statusLabel)
                .font(.pressMono(10))
                .tracking(2.2)
                .foregroundStyle(tracker.phase == .locked ? theme.accent : theme.secondaryInk)
                .padding(.top, 22)

            Text("\(tracker.repCount)")
                .font(.pressDisplay(188))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("FRONT CAMERA FACE DISTANCE · REAL TIME PUSH-UP COUNT")
                .font(.pressMono(10))
                .tracking(1.2)
                .foregroundStyle(theme.secondaryInk)

            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(theme.divider, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 28).fill(theme.surface))

                FaceTrackingCameraView(controller: tracker)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .opacity(tracker.isSupported ? 1 : 0)

                VStack(spacing: 18) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 92, height: 92)
                    Rectangle()
                        .fill(theme.accent)
                        .frame(width: 2, height: 86)
                    Text(tracker.actionTitle)
                        .font(.pressDisplay(48))
                        .foregroundStyle(theme.ink)
                }
                .padding(.top, 36)

                if let overlayTitle = tracker.overlayTitle, let overlayDetail = tracker.overlayDetail {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.54 : 0.34))
                        .overlay {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(overlayTitle)
                                    .font(.pressDisplay(48))
                                    .foregroundStyle(Color.white)
                                Text(overlayDetail.uppercased())
                                    .font(.pressMono(10))
                                    .tracking(1.4)
                                    .foregroundStyle(Color.white.opacity(0.88))
                                    .lineSpacing(6)
                            }
                            .padding(26)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                }
            }
            .frame(height: 320)
            .overlay(alignment: .topLeading) {
                Text("TRUEDEPTH LOCK")
                    .font(.pressMono(10))
                    .tracking(1.8)
                    .foregroundStyle(theme.secondaryInk)
                    .padding(18)
            }

            Text(tracker.metricsLine)
                .font(.pressMono(11))
                .tracking(1.1)
                .foregroundStyle(theme.ink)
                .padding(.top, 2)
        }
    }
}

private struct LiveSummaryScreen: View {
    @Environment(\.colorScheme) private var colorScheme

    let result: LiveSessionResult
    let dismiss: () -> Void
    let retry: () -> Void
    let save: () -> Void

    private var theme: AppTheme {
        AppTheme.resolve(for: colorScheme)
    }

    private var saveEnabled: Bool {
        !result.isEmpty
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                WordmarkHeader(trailingText: "LIVE SUMMARY", theme: theme)
                    .padding(.top, 32)

                content
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ActionStrip(theme: theme) {
                ActionCell(title: "DISCARD", subtitle: nil, emphasized: false, theme: theme, action: dismiss)
                Rectangle().fill(theme.divider).frame(width: 1)
                ActionCell(title: "RETRY", subtitle: nil, emphasized: false, theme: theme, action: retry)
                Rectangle().fill(theme.divider).frame(width: 1)
                ActionCell(title: "SAVE", subtitle: nil, emphasized: true, isEnabled: saveEnabled, theme: theme, action: save)
            }
            .background(theme.background)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SESSION")
                .font(.pressMono(10))
                .tracking(2.2)
                .foregroundStyle(theme.secondaryInk)
                .padding(.top, 28)

            Text("\(result.reps)")
                .font(.pressDisplay(188))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("REPS")
                .font(.pressMono(10))
                .tracking(1.6)
                .foregroundStyle(theme.secondaryInk)

            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)

            HStack(spacing: 18) {
                StatColumn(value: durationString, label: "DURATION", theme: theme)
                StatColumn(value: paceString, label: "PACE", theme: theme)
                StatColumn(value: "\(result.manualAdjustments)", label: "ADJUST", theme: theme)
            }
            .padding(.top, 12)

            Text(saveEnabled ? "SAVE THIS LIVE SESSION TO TODAY'S COUNT." : "ZERO REP SESSIONS WON'T CHANGE YOUR HISTORY.")
                .font(.pressMono(10))
                .tracking(1.0)
                .foregroundStyle(saveEnabled ? theme.secondaryInk : theme.accent)
                .lineSpacing(5)
                .padding(.top, 18)
        }
    }

    private var durationString: String {
        let minutes = Int(result.duration) / 60
        let seconds = Int(result.duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var paceString: String {
        guard let averageRepDuration = result.averageRepDuration else { return "--" }
        return String(format: "%.1fs", averageRepDuration)
    }
}
