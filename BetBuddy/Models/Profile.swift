import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    var username: String
    var firstName: String
    var lastName: String
    var avatarUrl: String?
    var balance: Int
    var totalWon: Int
    var totalLost: Int
    var pushToken: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, username, balance
        case firstName = "first_name"
        case lastName = "last_name"
        case avatarUrl = "avatar_url"
        case totalWon = "total_won"
        case totalLost = "total_lost"
        case pushToken = "push_token"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
