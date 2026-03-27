import Foundation

struct Wager: Codable, Identifiable {
    let id: UUID
    let betId: UUID
    let userId: UUID
    let amount: Int
    let side: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, amount, side
        case betId = "bet_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
