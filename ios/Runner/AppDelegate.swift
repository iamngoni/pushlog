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

    healthStore.requestAuthorization(
      toShare: [HKObjectType.workoutType()],
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
      let reps = payload["reps"] as? Int,
      let durationMicroseconds = payload["durationMicroseconds"] as? Int,
      let manualAdjustments = payload["manualAdjustments"] as? Int,
      let endedAtRaw = payload["endedAt"] as? String,
      let externalId = payload["externalId"] as? String,
      reps > 0
    else {
      result(false)
      return
    }

    let formatter = ISO8601DateFormatter()
    guard let endedAt = formatter.date(from: endedAtRaw) else {
      result(false)
      return
    }

    Task {
      let duration = max(Double(durationMicroseconds) / 1_000_000, 60)
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
          "PushlogManualAdjustments": manualAdjustments,
          "PushlogExternalSessionID": externalId
        ])
        try await builder.endCollection(at: endedAt)
        _ = try await finish(builder)
        result(true)
      } catch {
        builder.discardWorkout()
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
}
