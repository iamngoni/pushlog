import Foundation

/// Values exchanged between Flutter, iPhone, and Apple Watch are application
/// identifiers. They are deliberately opaque strings rather than Foundation
/// UUIDs: Flutter's current generator emits 32 hexadecimal characters without
/// UUID separators.
enum PushlogWatchProtocol {
  static func sessionID(in message: [String: Any]) -> String? {
    let value = (message["sessionID"] ?? message["sessionId"]) as? String
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  static func matches(sessionID: String, message: [String: Any]) -> Bool {
    guard let messageSessionID = PushlogWatchProtocol.sessionID(in: message) else {
      return true
    }
    return messageSessionID == sessionID
  }
}
