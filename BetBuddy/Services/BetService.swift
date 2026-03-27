import Foundation
import Supabase

final class BetService {
    private let client = SupabaseManager.client

    func fetchBets(groupId: UUID) async throws -> [Bet] {
        try await client
            .from("bets")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchBet(betId: UUID) async throws -> Bet {
        try await client
            .from("bets")
            .select()
            .eq("id", value: betId.uuidString)
            .single()
            .execute()
            .value
    }

    func createBet(groupId: UUID, creatorId: UUID, title: String, emoji: String, outcomes: [String], deadline: Date?, creatorCanBet: Bool = true) async throws -> Bet {
        var params: [String: AnyJSON] = [
            "group_id": .string(groupId.uuidString),
            "creator_id": .string(creatorId.uuidString),
            "title": .string(title),
            "emoji": .string(emoji),
            "outcomes": .array(outcomes.map { .string($0) }),
            "creator_can_bet": .bool(creatorCanBet)
        ]
        if let deadline {
            params["deadline"] = .string(ISO8601DateFormatter().string(from: deadline))
        }
        let bet: Bet = try await client
            .from("bets")
            .insert(params)
            .select()
            .single()
            .execute()
            .value
        return bet
    }

    func fetchWagers(betId: UUID) async throws -> [Wager] {
        try await client
            .from("wagers")
            .select()
            .eq("bet_id", value: betId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func placeWager(betId: UUID, userId: UUID, amount: Int, side: String) async throws {
        try await client.rpc("place_wager", params: [
            "p_bet_id": betId.uuidString,
            "p_user_id": userId.uuidString,
            "p_amount": "\(amount)",
            "p_side": side
        ]).execute()
    }

    struct SettleResult: Codable {
        let success: Bool
        let winner: String
        let results: [SettleUserResult]
    }

    struct SettleUserResult: Codable {
        let userId: String
        let payout: Int
        let profit: Int
        let won: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case payout, profit, won
        }
    }

    func settleBet(betId: UUID, userId: UUID, winner: String) async throws {
        try await client.rpc("settle_bet", params: [
            "p_bet_id": betId.uuidString,
            "p_user_id": userId.uuidString,
            "p_winner": winner
        ]).execute()
    }

    func deleteBet(betId: UUID, userId: UUID) async throws {
        try await client.rpc("delete_bet", params: [
            "p_bet_id": betId.uuidString,
            "p_user_id": userId.uuidString
        ]).execute()
    }

    func uploadBetImage(betId: UUID, imageData: Data) async throws -> String {
        let path = "\(betId.uuidString.lowercased())/image.jpg"
        try await client.storage.from("bet-images").upload(
            path,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let publicURL = try client.storage.from("bet-images").getPublicURL(path: path)
        try await client
            .from("bets")
            .update(["image_url": publicURL.absoluteString])
            .eq("id", value: betId.uuidString)
            .execute()
        return publicURL.absoluteString
    }
}
