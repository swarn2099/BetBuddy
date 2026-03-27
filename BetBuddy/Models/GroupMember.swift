import Foundation

struct GroupMember: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}
