import Foundation

struct AppNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let type: String
    let title: String
    let body: String
    var metadata: [String: String]?
    var read: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, metadata, read
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
