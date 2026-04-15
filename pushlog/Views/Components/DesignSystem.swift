import SwiftUI

enum PushlogTab {
    case today
    case history
    case settings
}

struct AppTheme {
    let background: Color
    let surface: Color
    let ink: Color
    let secondaryInk: Color
    let divider: Color
    let accent: Color
    let accentInk: Color
    let accentStroke: Color

    static func resolve(for colorScheme: ColorScheme) -> AppTheme {
        switch colorScheme {
        case .dark:
            return .init(
                background: Color(hex: 0x0A0908),
                surface: Color(hex: 0x141210),
                ink: Color(hex: 0xF8F5F0),
                secondaryInk: Color(hex: 0x706D68),
                divider: Color(hex: 0x282522),
                accent: Color(hex: 0xD7FF1F),
                accentInk: Color(hex: 0xD7FF1F),
                accentStroke: Color(hex: 0xF8F5F0, alpha: 0.16)
            )
        default:
            return .init(
                background: Color(hex: 0xFAFAF8),
                surface: Color.white.opacity(0.6),
                ink: Color(hex: 0x0A0908),
                secondaryInk: Color(hex: 0x9A9590),
                divider: Color(hex: 0xD5D2CE),
                accent: Color(hex: 0xD7FF1F),
                accentInk: Color(hex: 0x718500),
                accentStroke: Color(hex: 0x0A0908, alpha: 0.14)
            )
        }
    }
}

extension Font {
    static func pressDisplay(_ size: CGFloat) -> Font {
        .custom("HelveticaNeue-CondensedBlack", size: size)
    }

    static func pressMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct WordmarkHeader: View {
    let trailingText: String
    let theme: AppTheme

    var body: some View {
        HStack {
            Text("PUSHLOG")
                .font(.pressMono(10))
                .tracking(3)
            Spacer()
            Text(trailingText)
                .font(.pressMono(10))
                .tracking(1.5)
        }
        .foregroundStyle(theme.secondaryInk)
    }
}

struct BottomTabBar: View {
    @Binding var selectedTab: PushlogTab
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 0) {
            tabButton(title: "TODAY", tab: .today)
            tabButton(title: "HISTORY", tab: .history)
            tabButton(title: "SETTINGS", tab: .settings)
        }
        .frame(height: 64)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
        }
        .background(theme.background)
    }

    private func tabButton(title: String, tab: PushlogTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.pressMono(11))
                .tracking(2)
                .foregroundStyle(selectedTab == tab ? theme.ink : theme.secondaryInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ActionCell: View {
    let title: String
    let subtitle: String?
    let emphasized: Bool
    let isEnabled: Bool
    let theme: AppTheme
    let action: () -> Void

    init(
        title: String,
        subtitle: String?,
        emphasized: Bool,
        isEnabled: Bool = true,
        theme: AppTheme,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.emphasized = emphasized
        self.isEnabled = isEnabled
        self.theme = theme
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.pressDisplay(30))
                    .foregroundStyle(emphasized ? Color(hex: 0x0A0908) : theme.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(.pressMono(8))
                        .tracking(1.5)
                        .foregroundStyle(emphasized ? Color(hex: 0x0A0908) : theme.secondaryInk)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(emphasized ? theme.accent : theme.background)
            .overlay {
                if emphasized {
                    Rectangle()
                        .stroke(theme.accentStroke, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.36)
    }
}

struct ActionStrip<Content: View>: View {
    let theme: AppTheme
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .frame(height: 88)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
        }
    }
}

struct DayStripView: View {
    let summary: [DaySummary]
    let theme: AppTheme

    private var maxCount: Int {
        summary.map(\.count).max() ?? 1
    }

    private func barHeight(for count: Int) -> CGFloat {
        let minH: CGFloat = 3
        let maxH: CGFloat = 28
        guard maxCount > 0, count > 0 else { return minH }
        return minH + (maxH - minH) * CGFloat(count) / CGFloat(maxCount)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(summary) { day in
                RoundedRectangle(cornerRadius: 2)
                    .fill(day.isToday ? theme.accent : day.count > 0 ? theme.ink : theme.divider)
                    .frame(width: day.isToday ? 10 : 8, height: barHeight(for: day.count))
                    .overlay {
                        if day.isToday {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(theme.accentStroke, lineWidth: 1)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatColumn: View {
    let value: String
    let label: String
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.pressMono(20, weight: .medium))
            Text(label)
                .font(.pressMono(8))
                .tracking(1.3)
                .foregroundStyle(theme.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    let title: String
    let theme: AppTheme

    var body: some View {
        Text(title)
            .font(.pressMono(10))
            .tracking(2)
            .foregroundStyle(theme.secondaryInk)
    }
}

struct SessionSourceBadge: View {
    let source: WorkoutSource
    let theme: AppTheme

    var body: some View {
        Text(source == .live ? "LIVE" : "LOG")
            .font(.pressMono(9))
            .tracking(1.6)
            .foregroundStyle(source == .live ? Color(hex: 0x0A0908) : theme.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(source == .live ? theme.accent : theme.surface)
            .clipShape(Capsule())
    }
}

struct UndoStrip: View {
    let reps: Int
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("LAST LOG")
                    .font(.pressMono(8))
                    .tracking(1.6)
                    .foregroundStyle(theme.secondaryInk)
                Text("+\(reps)")
                    .font(.pressDisplay(34))
                    .foregroundStyle(theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Rectangle()
                .fill(theme.divider)
                .frame(width: 1)

            Button(action: action) {
                Text("UNDO")
                    .font(.pressDisplay(32))
                    .foregroundStyle(Color(hex: 0x0A0908))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.accent)
                    .overlay {
                        Rectangle()
                            .stroke(theme.accentStroke, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .frame(height: 76)
        .background(theme.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
        }
    }
}
