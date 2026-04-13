import Combine
import Foundation
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ReminderManager: ObservableObject {
    enum CopyMode {
        case curated
        case smart
        case unavailable
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var scheduledCount = 0
    @Published private(set) var nextReminderDate: Date?
    @Published private(set) var copyMode: CopyMode = .curated

    private let center: UNUserNotificationCenter
    private let calendar = Calendar.current

    private static let requestPrefix = "pushlog.daily-reminder."
    private static let scheduledReminderCount = 30

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    var statusLabel: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "AUTHORIZED"
        case .denied:
            return "DENIED"
        case .notDetermined:
            return "NOT ASKED"
        @unknown default:
            return "UNKNOWN"
        }
    }

    var smartCopyLabel: String {
        switch copyMode {
        case .curated:
            return "CURATED"
        case .smart:
            return "SMART"
        case .unavailable:
            return "UNAVAILABLE"
        }
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        let requests = await pendingReminderRequests()
        scheduledCount = requests.count
        nextReminderDate = requests
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
            .sorted()
            .first
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshStatus()

        if isAuthorized {
            return true
        }

        guard authorizationStatus == .notDetermined else {
            return false
        }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshStatus()
        return granted && isAuthorized
    }

    func syncSchedule(using settings: ReminderSettings) async {
        if !settings.isEnabled {
            center.removePendingNotificationRequests(withIdentifiers: await reminderIdentifiers())
            copyMode = .curated
            await refreshStatus()
            return
        }

        guard await requestAuthorizationIfNeeded() else {
            copyMode = .unavailable
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: await reminderIdentifiers())

        let messages = await reminderMessages(
            count: Self.scheduledReminderCount,
            useSmartCopy: settings.useSmartCopy
        )
        let dates = scheduledDates(
            hour: settings.hour,
            minute: settings.minute,
            count: Self.scheduledReminderCount
        )

        for (index, date) in dates.enumerated() {
            let message = messages[index % messages.count]
            let content = UNMutableNotificationContent()
            content.title = "PUSHLOG"
            content.body = message
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(Self.requestPrefix)\(index)",
                content: content,
                trigger: trigger
            )

            try? await add(request)
        }

        await refreshStatus()
    }

    private func pendingReminderRequests() async -> [UNNotificationRequest] {
        let requests = await center.pendingNotificationRequests()
        return requests.filter { $0.identifier.hasPrefix(Self.requestPrefix) }
    }

    private func reminderIdentifiers() async -> [String] {
        await pendingReminderRequests().map(\.identifier)
    }

    private func scheduledDates(hour: Int, minute: Int, count: Int) -> [Date] {
        var dates: [Date] = []
        let now = Date()
        var searchStart = now

        while dates.count < count,
              let date = calendar.nextDate(
                after: searchStart,
                matching: DateComponents(hour: hour, minute: minute),
                matchingPolicy: .nextTime,
                direction: .forward
              )
        {
            dates.append(date)
            searchStart = date.addingTimeInterval(60)
        }

        return dates
    }

    private func reminderMessages(count: Int, useSmartCopy: Bool) async -> [String] {
        let curated = curatedMessages.shuffled().prefix(max(count, 1))

        guard useSmartCopy else {
            copyMode = .curated
            return Array(curated)
        }

        if #available(iOS 26.0, *),
           let generated = try? await generateSmartMessages(count: count),
           !generated.isEmpty
        {
            copyMode = .smart
            return generated
        }

        copyMode = smartCopyAvailable ? .curated : .unavailable
        return Array(curated)
    }

    private var smartCopyAvailable: Bool {
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }

        return false
    }

    @available(iOS 26.0, *)
    private func generateSmartMessages(count: Int) async throws -> [String] {
        guard SystemLanguageModel.default.isAvailable else {
            return []
        }

        let session = LanguageModelSession(
            model: .default,
            instructions: """
            You write short notification copy for a minimalist push-up tracker called Pushlog.
            Keep each reminder under 70 characters.
            No emojis.
            No numbering.
            No quotation marks.
            Make the tone varied: sharp, playful, insistent, but not hostile.
            """
        )

        let response = try await session.respond(
            to: "Write \(count) distinct daily push-up reminders, one per line."
        )

        let lines = response.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^\d+[\).\-\s]*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }

        if lines.count >= count {
            return Array(lines.prefix(count))
        }

        return lines + curatedMessages.prefix(max(0, count - lines.count))
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private let curatedMessages: [String] = [
        "Your floor has been suspiciously quiet.",
        "Do the reps before the excuses warm up.",
        "Pushlog is ready. Your chest should be too.",
        "One clean set changes the whole day.",
        "The streak is easier to keep than rebuild.",
        "Drop and give today some structure.",
        "You only need the floor and a decision.",
        "This takes minutes. Avoiding it takes longer.",
        "Your future shoulders filed a complaint.",
        "Start with ten. Pride will handle the rest."
    ]
}
