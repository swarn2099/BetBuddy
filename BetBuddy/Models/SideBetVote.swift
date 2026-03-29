import Foundation

struct SideBetVote: Codable, Identifiable {
    let id: UUID
    let sideBetId: UUID
    let voterId: UUID
    let vote: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, vote
        case sideBetId = "side_bet_id"
        case voterId = "voter_id"
        case createdAt = "created_at"
    }
}
