import Foundation

struct BalanceHistoryEntry: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let amount: Int
    let change: Int
    let reason: String
    let betId: UUID?
    let sideBetId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, amount, change, reason
        case userId = "user_id"
        case betId = "bet_id"
        case sideBetId = "side_bet_id"
        case createdAt = "created_at"
    }
}
