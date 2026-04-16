import Foundation

enum WorkoutSource: String, Codable, Hashable {
    case manual
    case live
}

struct WorkoutSessionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let reps: Int
    let source: WorkoutSource
    let duration: TimeInterval?
    let averageRepDuration: TimeInterval?
    let manualAdjustments: Int

    init(
        id: UUID = UUID(),
        date: Date,
        reps: Int,
        source: WorkoutSource,
        duration: TimeInterval? = nil,
        averageRepDuration: TimeInterval? = nil,
        manualAdjustments: Int = 0
    ) {
        self.id = id
        self.date = date
        self.reps = reps
        self.source = source
        self.duration = duration
        self.averageRepDuration = averageRepDuration
        self.manualAdjustments = manualAdjustments
    }

    func updatingReps(to reps: Int) -> WorkoutSessionRecord {
        WorkoutSessionRecord(
            id: id,
            date: date,
            reps: reps,
            source: source,
            duration: duration,
            averageRepDuration: averageRepDuration,
            manualAdjustments: manualAdjustments
        )
    }
}

struct LiveSessionResult {
    let reps: Int
    let duration: TimeInterval
    let averageRepDuration: TimeInterval?
    let manualAdjustments: Int

    var isEmpty: Bool {
        reps == 0
    }
}

struct PendingManualUndo: Identifiable, Hashable {
    let sessionID: UUID
    let reps: Int
    let date: Date

    var id: UUID { sessionID }
}
