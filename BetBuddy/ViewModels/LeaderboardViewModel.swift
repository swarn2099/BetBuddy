import Foundation
import Supabase

@Observable
final class LeaderboardViewModel {
    var globalRankings: [Profile] = []
    var groupRankings: [Profile] = []
    var isLoading = false
    var scope: Scope = .global

    enum Scope {
        case global
        case group
    }

    private let client = SupabaseManager.client
    private let groupService = GroupService()

    func loadGlobalRankings() async {
        isLoading = true
        do {
            globalRankings = try await client
                .from("profiles")
                .select()
                .order("balance", ascending: false)
                .limit(50)
                .execute()
                .value
        } catch {
            // Non-fatal
        }
        isLoading = false
    }

    func loadGroupRankings(groupId: UUID) async {
        isLoading = true
        do {
            groupRankings = try await groupService.fetchGroupMembers(groupId: groupId)
            groupRankings.sort { $0.balance > $1.balance }
        } catch {
            // Non-fatal
        }
        isLoading = false
    }
}
