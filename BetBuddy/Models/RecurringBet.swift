import Foundation

struct RecurringBet: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let creatorId: UUID
    var title: String
    var emoji: String
    var outcomes: [String]
    var frequency: String
    var dayOfWeek: Int?
    var timeOfDay: String?
    var creatorCanBet: Bool
    var isActive: Bool
    var instanceCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, emoji, outcomes, frequency
        case groupId = "group_id"
        case creatorId = "creator_id"
        case dayOfWeek = "day_of_week"
        case timeOfDay = "time_of_day"
        case creatorCanBet = "creator_can_bet"
        case isActive = "is_active"
        case instanceCount = "instance_count"
        case createdAt = "created_at"
    }
}
