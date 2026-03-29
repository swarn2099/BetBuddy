import Foundation

struct Bet: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    let creatorId: UUID
    var title: String
    var emoji: String
    var imageUrl: String?
    var creatorCanBet: Bool
    var outcomes: [String]
    var deadline: Date?
    var pool: Int
    var status: String
    var winner: String?
    var category: String?
    var template: String?
    var recurringBetId: UUID?
    var instanceNumber: Int?
    var reminderCount: Int?
    var forceSettle: Bool?
    let createdAt: Date
    var settledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, emoji, outcomes, deadline, pool, status, winner, category, template
        case imageUrl = "image_url"
        case creatorCanBet = "creator_can_bet"
        case groupId = "group_id"
        case creatorId = "creator_id"
        case createdAt = "created_at"
        case settledAt = "settled_at"
        case recurringBetId = "recurring_bet_id"
        case instanceNumber = "instance_number"
        case reminderCount = "reminder_count"
        case forceSettle = "force_settle"
    }

    var isActive: Bool { status == "active" }
    var isSettled: Bool { status == "settled" }
    var isPastDeadline: Bool {
        guard let deadline else { return false }
        return deadline <= Date()
    }
    var isRecurring: Bool { recurringBetId != nil }
    var canForceSettle: Bool { forceSettle == true && isActive }
}
