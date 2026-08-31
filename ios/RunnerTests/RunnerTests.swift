import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testActiveSessionToleratesBriefTrackingLossDuringRep() {
    let policy = PushlogTrackingLossPolicy()

    XCTAssertTrue(policy.shouldWarn(anchorAge: 1.5))
    XCTAssertFalse(policy.shouldAutoPause(anchorAge: 2.0, sessionStarted: true))
  }

  func testActiveSessionAutoPausesAfterSustainedTrackingLoss() {
    let policy = PushlogTrackingLossPolicy()

    XCTAssertFalse(policy.shouldAutoPause(anchorAge: 3.9, sessionStarted: true))
    XCTAssertTrue(policy.shouldAutoPause(anchorAge: 4.1, sessionStarted: true))
  }

  func testSetupAutoPauseThresholdIsShorterThanLiveSessionThreshold() {
    let policy = PushlogTrackingLossPolicy()

    XCTAssertTrue(policy.shouldAutoPause(anchorAge: 2.5, sessionStarted: false))
    XCTAssertFalse(policy.shouldAutoPause(anchorAge: 2.5, sessionStarted: true))
  }

  func testWatchIntentRemainsPendingWhileConnectivityActivates() {
    let policy = PushlogWatchHandoffPolicy()

    XCTAssertTrue(policy.shouldRequestWatch(preferWatch: true))
    XCTAssertFalse(
      policy.canLaunchWatch(
        preferWatch: true,
        activationState: .notActivated,
        isPaired: false,
        isWatchAppInstalled: false
      )
    )
  }

  func testWatchLaunchBeginsOnlyAfterConnectivityIsReady() {
    let policy = PushlogWatchHandoffPolicy()

    XCTAssertTrue(
      policy.canLaunchWatch(
        preferWatch: true,
        activationState: .activated,
        isPaired: true,
        isWatchAppInstalled: true
      )
    )
    XCTAssertFalse(
      policy.canLaunchWatch(
        preferWatch: false,
        activationState: .activated,
        isPaired: true,
        isWatchAppInstalled: true
      )
    )
  }

}
