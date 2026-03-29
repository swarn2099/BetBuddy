import Foundation

struct SideBet: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    let creatorId: UUID
    let opponentId: UUID
    var title: String
    var emoji: String
    var amount: Int
    var status: String
    var creatorDeclaresWinner: String?
    var opponentConfirms: Bool?
    var settledWinner: String?
    let createdAt: Date
    var settledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, emoji, amount, status
        case groupId = "group_id"
        case creatorId = "creator_id"
        case opponentId = "opponent_id"
        case creatorDeclaresWinner = "creator_declares_winner"
        case opponentConfirms = "opponent_confirms"
        case settledWinner = "settled_winner"
        case createdAt = "created_at"
        case settledAt = "settled_at"
    }

    var isPending: Bool { status == "pending" }
    var isActive: Bool { status == "active" }
    var isDeclaring: Bool { status == "declaring" }
    var isSettled: Bool { status == "settled" }
    var isCancelled: Bool { status == "cancelled" }
}
