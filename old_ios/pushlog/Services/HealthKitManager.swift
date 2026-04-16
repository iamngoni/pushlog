import Combine
import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    @Published private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined

    private let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var statusLabel: String {
        guard isAvailable else { return "UNAVAILABLE" }

        switch authorizationStatus {
        case .sharingAuthorized:
            return "AUTHORIZED"
        case .sharingDenied:
            return "DENIED"
        case .notDetermined:
            return "NOT ASKED"
        @unknown default:
            return "UNKNOWN"
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .sharingAuthorized
    }

    func refreshAuthorization() {
        guard isAvailable else {
            authorizationStatus = .sharingDenied
            return
        }

        authorizationStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        refreshAuthorization()

        if isAuthorized {
            return true
        }

        guard isAvailable else {
            return false
        }

        do {
            try await healthStore.requestAuthorization(
                toShare: [HKObjectType.workoutType()],
                read: [HKObjectType.workoutType()]
            )
            refreshAuthorization()
            return isAuthorized
        } catch {
            refreshAuthorization()
            return false
        }
    }

    func saveLiveSession(_ result: LiveSessionResult, endedAt: Date, externalID: UUID) async {
        guard isAuthorized, result.reps > 0 else { return }

        let duration = max(result.duration, 60)
        let start = endedAt.addingTimeInterval(-duration)
        let metadata: [String: Any] = [
            "PushlogRepCount": result.reps,
            "PushlogManualAdjustments": result.manualAdjustments,
            "PushlogExternalSessionID": externalID.uuidString
        ]

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        do {
            try await builder.beginCollection(at: start)
            try await builder.addMetadata(metadata)
            try await builder.endCollection(at: endedAt)
            _ = try await finish(builder: builder)
        } catch {
            builder.discardWorkout()
        }
    }

    
    private func finish(builder: HKWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: NSError(domain: "PushlogHealthKit", code: -1))
                }
            }
        }
    }
}
