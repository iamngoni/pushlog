import Foundation

struct FriendEntry: Identifiable, Hashable {
    let id: UUID
    let name: String
    let todayCount: Int
    let isMe: Bool

    var initials: String {
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
