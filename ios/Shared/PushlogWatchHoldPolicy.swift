import Foundation

enum PushlogWatchHoldAction: Equatable {
  case togglePause
  case none
  case end
}

/// Makes release-at-threshold deterministic. The visual animation and the
/// asynchronous completion timer can finish on adjacent run-loop turns, so
/// the release path must also decide from elapsed time instead of cancelling
/// a timer that was just about to send the end command.
struct PushlogWatchHoldPolicy {
  static let holdDuration: TimeInterval = 3
  static let tapMaximumDuration: TimeInterval = 0.65

  func action(for elapsed: TimeInterval) -> PushlogWatchHoldAction {
    if elapsed >= Self.holdDuration {
      return .end
    }
    if elapsed < Self.tapMaximumDuration {
      return .togglePause
    }
    return .none
  }
}

struct PushlogWatchHoldCompletion {
  private(set) var didComplete = false

  mutating func reset() {
    didComplete = false
  }

  mutating func completeIfNeeded() -> Bool {
    guard !didComplete else { return false }
    didComplete = true
    return true
  }
}
