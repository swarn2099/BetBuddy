import Foundation

struct Group: Codable, Identifiable {
    let id: UUID
    var name: String
    var imageUrl: String?
    let inviteCode: String
    let leaderId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case imageUrl = "image_url"
        case inviteCode = "invite_code"
        case leaderId = "leader_id"
        case createdAt = "created_at"
    }
}
