import Foundation

struct Bet: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    let creatorId: UUID
    var title: String
    var emoji: String
    var imageUrl: String?
    var outcomes: [String]
    var deadline: Date?
    var pool: Int
    var status: String
    var winner: String?
    let createdAt: Date
    var settledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, emoji, outcomes, deadline, pool, status, winner
        case imageUrl = "image_url"
        case groupId = "group_id"
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case settledAt = "settled_at"
    }

    var isActive: Bool { status == "active" }
    var isSettled: Bool { status == "settled" }
    var isPastDeadline: Bool {
        guard let deadline else { return false }
        return deadline <= Date()
    }
}
