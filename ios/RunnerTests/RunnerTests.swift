import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
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

  func testWatchProtocolAcceptsFlutterOpaqueSessionIdentifier() {
    let identifier = "0123456789abcdef0123456789abcdef"

    XCTAssertNil(UUID(uuidString: identifier))
    XCTAssertEqual(
      PushlogWatchProtocol.sessionID(in: ["sessionID": identifier]),
      identifier
    )
    XCTAssertTrue(
      PushlogWatchProtocol.matches(
        sessionID: identifier,
        message: ["sessionID": identifier]
      )
    )
    XCTAssertFalse(
      PushlogWatchProtocol.matches(
        sessionID: identifier,
        message: ["sessionID": "another-session"]
      )
    )
  }

  func testWatchTransfersWaitForSessionActivation() {
    let policy = PushlogWatchHandoffPolicy()

    XCTAssertFalse(policy.canTransfer(activationState: .notActivated))
    XCTAssertFalse(policy.canTransfer(activationState: .inactive))
    XCTAssertTrue(policy.canTransfer(activationState: .activated))
  }

}
