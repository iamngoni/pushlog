// At-a-glance Pushlog totals when no phone workout is active.

import SwiftUI

private let ink = Color(hex: 0xF8F5F0)
private let secondary = Color(hex: 0x706D68)
private let accent = Color(hex: 0xD7FF1F)
private let surface = Color(hex: 0x141210)


private func formatLarge(_ value: Int) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fm", Double(value) / 1_000_000)
    } else if value >= 1_000 {
        return String(format: "%.1fk", Double(value) / 1_000)
    }
    return "\(value)"
}

struct WatchTodayView: View {
    @EnvironmentObject var session: WatchSessionManager

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd MMM"
        return formatter.string(from: Date()).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PUSHLOG")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(secondary)
                Spacer()
                Text(dateString)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(secondary)
            }

            Spacer()

            // Big count
            Text("\(session.todayCount)")
                .font(.custom("HelveticaNeue-CondensedBlack", size: 64))
                .foregroundStyle(ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("TODAY")
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(secondary)

            Spacer().frame(height: 8)

            // Stats row
            HStack(spacing: 12) {
                WatchStatCell(value: "\(session.streak)", label: "STREAK")
                WatchStatCell(value: "\(session.bestDay)", label: "BEST")
                WatchStatCell(value: formatLarge(session.allTime), label: "ALL TIME")
            }

            Spacer()

            // Action buttons
            HStack(spacing: 6) {
                Button {
                    session.addReps(1)
                } label: {
                    Text("+1")
                        .font(.custom("HelveticaNeue-CondensedBlack", size: 18))
                        .foregroundStyle(Color(hex: 0x0A0908))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    session.addReps(10)
                } label: {
                    Text("+10")
                        .font(.custom("HelveticaNeue-CondensedBlack", size: 18))
                        .foregroundStyle(ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: 0x0A0908))
    }
}

private struct WatchStatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(hex: 0xF8F5F0))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 7, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(hex: 0x706D68))
        }
        .frame(maxWidth: .infinity)
    }
}
