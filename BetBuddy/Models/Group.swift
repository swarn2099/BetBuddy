import Foundation

struct BetGroup: Codable, Identifiable {
    let id: UUID
    var name: String
    var imageUrl: String?
    let inviteCode: String
    let leaderId: UUID
    let isGlobal: Bool
    var adminIds: [UUID]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case imageUrl = "image_url"
        case inviteCode = "invite_code"
        case leaderId = "leader_id"
        case isGlobal = "is_global"
        case adminIds = "admin_ids"
        case createdAt = "created_at"
    }
}
