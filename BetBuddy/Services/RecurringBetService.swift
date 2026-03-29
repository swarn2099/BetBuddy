import Foundation
import Supabase

final class RecurringBetService {
    private let client = SupabaseManager.client

    func createRecurringBet(groupId: UUID, creatorId: UUID, title: String, emoji: String, outcomes: [String], frequency: String, dayOfWeek: Int?, creatorCanBet: Bool) async throws -> RecurringBet {
        var params: [String: AnyJSON] = [
            "group_id": .string(groupId.uuidString),
            "creator_id": .string(creatorId.uuidString),
            "title": .string(title),
            "emoji": .string(emoji),
            "outcomes": .array(outcomes.map { .string($0) }),
            "frequency": .string(frequency),
            "creator_can_bet": .bool(creatorCanBet)
        ]
        if let dayOfWeek {
            params["day_of_week"] = .integer(dayOfWeek)
        }

        let recurring: RecurringBet = try await client
            .from("recurring_bets")
            .insert(params)
            .select()
            .single()
            .execute()
            .value
        return recurring
    }

    func deactivate(recurringBetId: UUID) async throws {
        try await client
            .from("recurring_bets")
            .update(["is_active": false])
            .eq("id", value: recurringBetId.uuidString)
            .execute()
    }

    func fetchRecurringBets(groupId: UUID) async throws -> [RecurringBet] {
        try await client
            .from("recurring_bets")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .eq("is_active", value: "true")
            .execute()
            .value
    }
}
