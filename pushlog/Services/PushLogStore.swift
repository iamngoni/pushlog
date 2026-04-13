import Combine
import Foundation
import SwiftUI

struct DaySummary: Identifiable, Hashable {
    let date: Date
    let count: Int
    let isToday: Bool

    var id: String { PushLogStore.dayKey(for: date) }
}

struct MonthSummary {
    let total: Int
    let best: Int
    let average: Int
    let sessions: Int
    let liveSessions: Int
}

struct HistoryEntry: Identifiable, Hashable {
    let date: Date
    let count: Int
    let isToday: Bool

    var id: String { PushLogStore.dayKey(for: date) }
}

struct ReminderSettings: Codable, Hashable {
    var isEnabled = false
    var hour = 19
    var minute = 0
    var useSmartCopy = true
}

struct PushlogPreferences: Codable, Hashable {
    var reminders = ReminderSettings()
    var healthSyncEnabled = false
}

private struct StoredPushlogData: Codable {
    var dayTotals: [String: Int]
    var sessions: [WorkoutSessionRecord]
    var preferences: PushlogPreferences
    var updatedAt: Date

    init(
        dayTotals: [String: Int] = [:],
        sessions: [WorkoutSessionRecord] = [],
        preferences: PushlogPreferences = PushlogPreferences(),
        updatedAt: Date = .distantPast
    ) {
        self.dayTotals = dayTotals
        self.sessions = sessions
        self.preferences = preferences
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case dayTotals
        case sessions
        case preferences
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayTotals = try container.decodeIfPresent([String: Int].self, forKey: .dayTotals) ?? [:]
        sessions = try container.decodeIfPresent([WorkoutSessionRecord].self, forKey: .sessions) ?? []
        preferences = try container.decodeIfPresent(PushlogPreferences.self, forKey: .preferences) ?? PushlogPreferences()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }
}

@MainActor
final class PushLogStore: ObservableObject {
    @Published private(set) var dayTotals: [String: Int]
    @Published private(set) var sessions: [WorkoutSessionRecord]
    @Published private(set) var preferences: PushlogPreferences
    @Published private(set) var pendingUndo: PendingManualUndo?
    @Published private(set) var lastCloudSyncAt: Date?

    private let defaults: UserDefaults
    private let cloudStore: NSUbiquitousKeyValueStore
    private let localStorageKey = "com.modestnerd.pushlog.data"
    private let cloudStorageKey = "com.modestnerd.pushlog.data"
    private let calendar = Calendar.current
    private var lastUpdatedAt: Date
    private var cancellables: Set<AnyCancellable> = []

    init(
        defaults: UserDefaults = .standard,
        cloudStore: NSUbiquitousKeyValueStore = .default
    ) {
        self.defaults = defaults
        self.cloudStore = cloudStore

        cloudStore.synchronize()

        let localSnapshot = Self.decode(data: defaults.data(forKey: localStorageKey))
        let cloudSnapshot = Self.decode(data: cloudStore.data(forKey: cloudStorageKey))
        let chosenSnapshot = Self.preferredSnapshot(local: localSnapshot, cloud: cloudSnapshot)

        dayTotals = chosenSnapshot.dayTotals
        sessions = chosenSnapshot.sessions.sorted { $0.date > $1.date }
        preferences = chosenSnapshot.preferences
        lastUpdatedAt = chosenSnapshot.updatedAt
        lastCloudSyncAt = FileManager.default.ubiquityIdentityToken == nil ? nil : .now

        mirror(snapshot: chosenSnapshot)
        bindCloudChanges()
    }

    var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    var todayCount: Int {
        dayTotals[Self.dayKey(for: .now)] ?? 0
    }

    var streak: Int {
        var cursor = calendar.startOfDay(for: .now)

        if (dayTotals[Self.dayKey(for: cursor)] ?? 0) == 0,
           let previous = calendar.date(byAdding: .day, value: -1, to: cursor)
        {
            cursor = previous
        }

        var count = 0
        while (dayTotals[Self.dayKey(for: cursor)] ?? 0) > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return count
    }

    var bestDay: Int {
        dayTotals.values.max() ?? 0
    }

    var totalAllTime: Int {
        dayTotals.values.reduce(0, +)
    }

    var weekSummary: [DaySummary] {
        let today = calendar.startOfDay(for: .now)

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else {
                return nil
            }
            let key = Self.dayKey(for: date)
            return DaySummary(date: date, count: dayTotals[key] ?? 0, isToday: calendar.isDateInToday(date))
        }
    }

    var monthSummary: MonthSummary {
        let now = calendar.startOfDay(for: .now)
        let components = calendar.dateComponents([.year, .month], from: now)

        let counts = dayTotals.compactMap { key, value -> Int? in
            guard let date = Self.date(from: key) else { return nil }
            let dateComponents = calendar.dateComponents([.year, .month], from: date)
            guard dateComponents.year == components.year, dateComponents.month == components.month else {
                return nil
            }
            return value
        }

        let total = counts.reduce(0, +)
        let best = counts.max() ?? 0
        let average = counts.isEmpty ? 0 : Int((Double(total) / Double(counts.count)).rounded())
        let monthSessions = sessions.filter { session in
            let dateComponents = calendar.dateComponents([.year, .month], from: session.date)
            return dateComponents.year == components.year && dateComponents.month == components.month
        }

        return MonthSummary(
            total: total,
            best: best,
            average: average,
            sessions: monthSessions.count,
            liveSessions: monthSessions.filter { $0.source == .live }.count
        )
    }

    var historyEntries: [HistoryEntry] {
        dayTotals
            .compactMap { key, count in
                guard let date = Self.date(from: key) else { return nil }
                return HistoryEntry(date: date, count: count, isToday: calendar.isDateInToday(date))
            }
            .sorted { $0.date > $1.date }
    }

    var recentSessions: [WorkoutSessionRecord] {
        sessions.sorted { $0.date > $1.date }
    }

    func addManualReps(_ reps: Int, date: Date = .now) {
        guard reps > 0 else { return }

        let session = WorkoutSessionRecord(date: date, reps: reps, source: .manual)
        let key = Self.dayKey(for: date)

        dayTotals[key, default: 0] += reps
        sessions.insert(session, at: 0)
        pendingUndo = PendingManualUndo(sessionID: session.id, reps: reps, date: date)
        persist()
    }

    func undoLastManualEntry() {
        guard let pendingUndo else { return }

        guard let sessionIndex = sessions.firstIndex(where: { $0.id == pendingUndo.sessionID && $0.source == .manual }) else {
            self.pendingUndo = nil
            persist()
            return
        }

        sessions.remove(at: sessionIndex)
        adjustDayTotal(for: pendingUndo.date, delta: -pendingUndo.reps)

        self.pendingUndo = nil
        persist()
    }

    func saveLiveSession(_ result: LiveSessionResult, date: Date = .now) {
        guard result.reps > 0 else { return }

        let key = Self.dayKey(for: date)
        dayTotals[key, default: 0] += result.reps
        sessions.insert(
            WorkoutSessionRecord(
                date: date,
                reps: result.reps,
                source: .live,
                duration: result.duration,
                averageRepDuration: result.averageRepDuration,
                manualAdjustments: result.manualAdjustments
            ),
            at: 0
        )
        pendingUndo = nil
        persist()
    }

    func setRemindersEnabled(_ isEnabled: Bool) {
        preferences.reminders.isEnabled = isEnabled
        persist()
    }

    func setReminderTime(date: Date) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        preferences.reminders.hour = components.hour ?? preferences.reminders.hour
        preferences.reminders.minute = components.minute ?? preferences.reminders.minute
        persist()
    }

    func setSmartReminderCopyEnabled(_ isEnabled: Bool) {
        preferences.reminders.useSmartCopy = isEnabled
        persist()
    }

    func setHealthSyncEnabled(_ isEnabled: Bool) {
        preferences.healthSyncEnabled = isEnabled
        persist()
    }

    func exportData() throws -> Data {
        try exportSnapshot()
    }

    func resetAllData() {
        apply(snapshot: StoredPushlogData())
        persist()
    }

    func updateSessionReps(_ reps: Int, for sessionID: UUID) {
        guard reps > 0 else {
            deleteSession(sessionID)
            return
        }

        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) else { return }

        let existingSession = sessions[sessionIndex]
        guard existingSession.reps != reps else { return }

        sessions[sessionIndex] = existingSession.updatingReps(to: reps)
        adjustDayTotal(for: existingSession.date, delta: reps - existingSession.reps)
        clearPendingUndoIfNeeded(for: sessionID)
        persist()
    }

    func deleteSession(_ sessionID: UUID) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) else { return }

        let session = sessions.remove(at: sessionIndex)
        adjustDayTotal(for: session.date, delta: -session.reps)
        clearPendingUndoIfNeeded(for: sessionID)
        persist()
    }

    func syncFromICloud() {
        cloudStore.synchronize()
        guard let snapshot = Self.decode(data: cloudStore.data(forKey: cloudStorageKey)) else { return }
        guard snapshot.updatedAt > lastUpdatedAt else { return }
        apply(snapshot: snapshot)
        mirror(snapshot: snapshot)
    }

    func flushToICloud() {
        cloudStore.synchronize()
    }

    private func bindCloudChanges() {
        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self else { return }
            guard self.relevantCloudChange(notification) else { return }
            self.syncFromICloud()
        }
        .store(in: &cancellables)
    }

    private func relevantCloudChange(_ notification: Notification) -> Bool {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return true
        }
        return changedKeys.contains(cloudStorageKey)
    }

    private func adjustDayTotal(for date: Date, delta: Int) {
        guard delta != 0 else { return }

        let key = Self.dayKey(for: date)
        let updatedCount = max(0, (dayTotals[key] ?? 0) + delta)

        if updatedCount == 0 {
            dayTotals.removeValue(forKey: key)
        } else {
            dayTotals[key] = updatedCount
        }
    }

    private func clearPendingUndoIfNeeded(for sessionID: UUID) {
        guard pendingUndo?.sessionID == sessionID else { return }
        pendingUndo = nil
    }

    private func exportSnapshot() throws -> Data {
        let snapshot = StoredPushlogData(
            dayTotals: dayTotals,
            sessions: sessions,
            preferences: preferences,
            updatedAt: lastUpdatedAt
        )
        return try JSONEncoder.exportEncoder.encode(snapshot)
    }

    private func persist() {
        let snapshot = StoredPushlogData(
            dayTotals: dayTotals,
            sessions: sessions,
            preferences: preferences,
            updatedAt: .now
        )
        lastUpdatedAt = snapshot.updatedAt
        mirror(snapshot: snapshot)
    }

    private func apply(snapshot: StoredPushlogData) {
        dayTotals = snapshot.dayTotals
        sessions = snapshot.sessions.sorted { $0.date > $1.date }
        preferences = snapshot.preferences
        pendingUndo = nil
        lastUpdatedAt = snapshot.updatedAt
    }

    private func mirror(snapshot: StoredPushlogData) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        defaults.set(data, forKey: localStorageKey)
        cloudStore.set(data, forKey: cloudStorageKey)
        cloudStore.synchronize()
        lastCloudSyncAt = iCloudAvailable ? .now : nil
    }

    private static func preferredSnapshot(
        local: StoredPushlogData?,
        cloud: StoredPushlogData?
    ) -> StoredPushlogData {
        switch (local, cloud) {
        case let (local?, cloud?):
            return local.updatedAt >= cloud.updatedAt ? local : cloud
        case let (local?, nil):
            return local
        case let (nil, cloud?):
            return cloud
        case (nil, nil):
            return StoredPushlogData()
        }
    }

    private static func decode(data: Data?) -> StoredPushlogData? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(StoredPushlogData.self, from: data)
    }

    static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        dayFormatter.date(from: key)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension JSONEncoder {
    static let exportEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
