import Foundation
import Supabase

final class BalanceHistoryService {
    private let client = SupabaseManager.client

    func fetchHistory(userId: UUID, since: Date? = nil) async throws -> [BalanceHistoryEntry] {
        var query = client
            .from("balance_history")
            .select()
            .eq("user_id", value: userId.uuidString)

        if let since {
            query = query.gte("created_at", value: ISO8601DateFormatter().string(from: since))
        }

        let result: [BalanceHistoryEntry] = try await query
            .order("created_at", ascending: true)
            .execute()
            .value
        return result
    }
}
