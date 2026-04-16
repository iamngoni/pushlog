import Combine
import Foundation

@MainActor
final class FriendsService: ObservableObject {
    @Published var friends: [FriendEntry] = []

    init() {
        // Seed with sample data until a real backend is wired up
        friends = [
            FriendEntry(id: UUID(), name: "Leila Nkosi",    todayCount: 203, isMe: false),
            FriendEntry(id: UUID(), name: "John Doe",       todayCount: 142, isMe: false),
            FriendEntry(id: UUID(), name: "Sarah Adams",    todayCount: 87,  isMe: false),
            FriendEntry(id: UUID(), name: "Mike Chen",      todayCount: 34,  isMe: false),
        ]
    }

    /// Returns a merged, sorted leaderboard that always includes the user's own entry.
    /// `myName` and `myCount` come from the store at render time.
    func leaderboard(myName: String, myCount: Int) -> [FriendEntry] {
        let me = FriendEntry(id: .zero, name: myName, todayCount: myCount, isMe: true)
        return ([me] + friends).sorted { $0.todayCount > $1.todayCount }
    }
}

private extension UUID {
    static let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}
