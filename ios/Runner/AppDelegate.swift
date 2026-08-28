import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let healthStore = HKHealthStore()
  private let watchSessionManager = PushlogWatchSessionManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Firebase's swizzled proxy already forwards this token internally (that
  // existing mechanism is what getAPNSToken() has always relied on) and is
  // specifically designed to keep doing so even when the app implements
  // this method itself. This override exists only to log whether iOS ever
  // calls it at all — if APNs registration is failing outright,
  // didFailToRegisterForRemoteNotifications fires instead; if neither ever
  // fires, iOS never attempted registration in the first place.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    NSLog("[Pushlog] APNs device token received (%d bytes)", deviceToken.count)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[Pushlog] APNs registration FAILED: %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    registerHealthChannel(messenger)
    registerWatchChannels(messenger)
  }

  private func registerHealthChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "pushlog/health", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }

      switch call.method {
      case "authorizationStatus":
        result(self.authorizationStatusLabel())
      case "requestAuthorization":
        self.requestHealthAuthorization(result)
      case "saveLiveSession":
        self.saveLiveSession(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerWatchChannels(_ messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "pushlog/watch",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.watchSessionManager.handle(call, result: result)
    }

    let eventChannel = FlutterEventChannel(
      name: "pushlog/watch/events",
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(watchSessionManager)
  }

  private func authorizationStatusLabel() -> String {
    guard HKHealthStore.isHealthDataAvailable() else {
      return "unavailable"
    }

    switch healthStore.authorizationStatus(for: HKObjectType.workoutType()) {
    case .sharingAuthorized:
      return "authorized"
    case .sharingDenied:
      return "denied"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "unavailable"
    }
  }

  private func requestHealthAuthorization(_ result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }

    var shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
    if #available(iOS 18.0, *),
       let effortType = HKObjectType.quantityType(forIdentifier: .workoutEffortScore) {
      shareTypes.insert(effortType)
    }

    healthStore.requestAuthorization(
      toShare: shareTypes,
      read: [HKObjectType.workoutType()]
    ) { [weak self] success, _ in
      DispatchQueue.main.async {
        guard let self else {
          result(false)
          return
        }
        result(success && self.authorizationStatusLabel() == "authorized")
      }
    }
  }

  private func saveLiveSession(_ arguments: Any?, result: @escaping FlutterResult) {
    guard authorizationStatusLabel() == "authorized" else {
      result(false)
      return
    }
    guard
      let payload = arguments as? [String: Any],
      let repsValue = payload["reps"] as? NSNumber,
      let durationMicroseconds = payload["durationMicroseconds"] as? NSNumber,
      let manualAdjustments = payload["manualAdjustments"] as? NSNumber,
      let endedAtEpochMilliseconds = payload["endedAtEpochMilliseconds"] as? NSNumber,
      let externalId = payload["externalId"] as? String,
      repsValue.intValue > 0
    else {
      NSLog("[Pushlog] HealthKit export rejected an invalid session payload")
      result(false)
      return
    }

    let endedAt = Date(
      timeIntervalSince1970: endedAtEpochMilliseconds.doubleValue / 1_000
    )
    let reps = repsValue.intValue
    let effortScore = (payload["effortScore"] as? NSNumber)?.intValue

    Task {
      let duration = max(durationMicroseconds.doubleValue / 1_000_000, 1)
      let startedAt = endedAt.addingTimeInterval(-duration)
      let configuration = HKWorkoutConfiguration()
      configuration.activityType = .functionalStrengthTraining

      let builder = HKWorkoutBuilder(
        healthStore: healthStore,
        configuration: configuration,
        device: .local()
      )

      do {
        try await builder.beginCollection(at: startedAt)
        try await builder.addMetadata([
          "PushlogRepCount": reps,
          "PushlogManualAdjustments": manualAdjustments.intValue,
          "PushlogExternalSessionID": externalId
        ])
        try await builder.endCollection(at: endedAt)
        let workout = try await finish(builder)
        if #available(iOS 18.0, *),
           let effortScore,
           (1...10).contains(effortScore) {
          do {
            try await saveEffortScore(effortScore, for: workout)
          } catch {
            NSLog(
              "[Pushlog] Workout saved without effort score: %@",
              error.localizedDescription
            )
          }
        }
        result(true)
      } catch {
        builder.discardWorkout()
        NSLog("[Pushlog] HealthKit export FAILED: %@", error.localizedDescription)
        result(false)
      }
    }
  }

  private func finish(_ builder: HKWorkoutBuilder) async throws -> HKWorkout {
    try await withCheckedThrowingContinuation { continuation in
      builder.finishWorkout { workout, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        if let workout {
          continuation.resume(returning: workout)
          return
        }
        continuation.resume(
          throwing: NSError(domain: "PushlogHealthKit", code: -1)
        )
      }
    }
  }

  @available(iOS 18.0, *)
  private func saveEffortScore(_ score: Int, for workout: HKWorkout) async throws {
    guard let effortType = HKObjectType.quantityType(forIdentifier: .workoutEffortScore) else {
      return
    }
    let sample = HKQuantitySample(
      type: effortType,
      quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: Double(score)),
      start: workout.startDate,
      end: workout.endDate
    )
    try await healthStore.save(sample)
    _ = try await healthStore.relateWorkoutEffortSample(
      sample,
      with: workout,
      activity: nil
    )
  }
}
