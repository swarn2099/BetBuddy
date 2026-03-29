import Foundation
import Supabase

final class SideBetService {
    private let client = SupabaseManager.client

    func fetchSideBets(groupId: UUID) async throws -> [SideBet] {
        try await client
            .from("side_bets")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchSideBet(sideBetId: UUID) async throws -> SideBet {
        try await client
            .from("side_bets")
            .select()
            .eq("id", value: sideBetId.uuidString)
            .single()
            .execute()
            .value
    }

    func createSideBet(groupId: UUID, creatorId: UUID, opponentId: UUID, title: String, emoji: String, amount: Int) async throws -> SideBet {
        try await client.rpc("create_side_bet", params: [
            "p_group_id": groupId.uuidString,
            "p_creator_id": creatorId.uuidString,
            "p_opponent_id": opponentId.uuidString,
            "p_title": title,
            "p_emoji": emoji,
            "p_amount": "\(amount)"
        ]).execute()

        // Fetch the created side bet (RPC returns jsonb, not the row)
        let bets: [SideBet] = try await client
            .from("side_bets")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .eq("creator_id", value: creatorId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        guard let bet = bets.first else { throw NSError(domain: "BetBuddy", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create side bet"]) }
        return bet
    }

    func acceptSideBet(sideBetId: UUID, userId: UUID) async throws {
        try await client.rpc("accept_side_bet", params: [
            "p_side_bet_id": sideBetId.uuidString,
            "p_user_id": userId.uuidString
        ]).execute()
    }

    func declineSideBet(sideBetId: UUID, userId: UUID) async throws {
        try await client.rpc("decline_side_bet", params: [
            "p_side_bet_id": sideBetId.uuidString,
            "p_user_id": userId.uuidString
        ]).execute()
    }

    func declareWinner(sideBetId: UUID, userId: UUID, winner: String) async throws {
        try await client.rpc("declare_side_bet_winner", params: [
            "p_side_bet_id": sideBetId.uuidString,
            "p_user_id": userId.uuidString,
            "p_winner": winner
        ]).execute()
    }

    func confirmWinner(sideBetId: UUID, userId: UUID) async throws {
        try await client.rpc("confirm_side_bet_winner", params: [
            "p_side_bet_id": sideBetId.uuidString,
            "p_user_id": userId.uuidString
        ]).execute()
    }

    func disputeSideBet(sideBetId: UUID, userId: UUID) async throws {
        try await client.rpc("dispute_side_bet", params: [
            "p_side_bet_id": sideBetId.uuidString,
            "p_user_id": userId.uuidString
        ]).execute()
    }

    func castVote(sideBetId: UUID, voterId: UUID, vote: String) async throws {
        try await client
            .from("side_bet_votes")
            .insert([
                "side_bet_id": sideBetId.uuidString,
                "voter_id": voterId.uuidString,
                "vote": vote
            ])
            .execute()
    }

    func fetchVotes(sideBetId: UUID) async throws -> [SideBetVote] {
        try await client
            .from("side_bet_votes")
            .select()
            .eq("side_bet_id", value: sideBetId.uuidString)
            .execute()
            .value
    }
}
