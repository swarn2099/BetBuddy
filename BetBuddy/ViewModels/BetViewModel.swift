import Foundation

@Observable
final class BetViewModel {
    var bet: Bet?
    var wagers: [Wager] = []
    var wagerProfiles: [UUID: Profile] = [:]
    var isLoading = false
    var errorMessage: String?
    var selectedSide: String?
    var wagerAmount: Int = 0
    var isPlacingWager = false
    var isSettling = false

    private let betService = BetService()
    private let profileService = ProfileService()
    private let authService = AuthService()
    private let notificationService = NotificationService()

    var currentUserId: UUID? {
        get async { await authService.currentUserId }
    }

    func loadBet(betId: UUID) async {
        isLoading = true
        do {
            bet = try await betService.fetchBet(betId: betId)
            wagers = try await betService.fetchWagers(betId: betId)
            await loadWagerProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadWagerProfiles() async {
        // Load creator profile
        if let bet, wagerProfiles[bet.creatorId] == nil {
            if let profile = try? await profileService.fetchProfile(userId: bet.creatorId) {
                wagerProfiles[bet.creatorId] = profile
            }
        }
        // Load wager profiles
        let uniqueUserIds = Set(wagers.map(\.userId))
        for userId in uniqueUserIds where wagerProfiles[userId] == nil {
            if let profile = try? await profileService.fetchProfile(userId: userId) {
                wagerProfiles[userId] = profile
            }
        }
    }

    func poolForSide(_ side: String) -> Int {
        wagers.filter { $0.side == side }.reduce(0) { $0 + $1.amount }
    }

    func percentageForSide(_ side: String) -> Double {
        guard let bet, bet.pool > 0 else { return 0 }
        return Double(poolForSide(side)) / Double(bet.pool) * 100
    }

    func wagersForSide(_ side: String) -> [Wager] {
        wagers.filter { $0.side == side }
    }

    func placeWager() async {
        guard let bet,
              let side = selectedSide,
              wagerAmount > 0,
              let userId = await authService.currentUserId else { return }
        isPlacingWager = true
        errorMessage = nil
        do {
            try await betService.placeWager(betId: bet.id, userId: userId, amount: wagerAmount, side: side)
            // Notify bet creator
            if bet.creatorId != userId {
                await notificationService.sendPushNotification(
                    type: "wager_placed",
                    userIds: [bet.creatorId.uuidString],
                    title: bet.title,
                    body: "Someone bet $\(wagerAmount) on \"\(side)\"",
                    metadata: ["bet_id": bet.id.uuidString]
                )
            }
            await loadBet(betId: bet.id)
            selectedSide = nil
            wagerAmount = 0
        } catch {
            errorMessage = error.localizedDescription
        }
        isPlacingWager = false
    }

    func settleBet(winner: String) async {
        guard let bet,
              let userId = await authService.currentUserId else { return }
        isSettling = true
        errorMessage = nil
        do {
            try await betService.settleBet(betId: bet.id, userId: userId, winner: winner)
            // Notify winners
            let winners = wagers.filter { $0.side == winner && $0.userId != userId }
            let winnerIds = Array(Set(winners.map { $0.userId })).map { $0.uuidString }
            if !winnerIds.isEmpty {
                await notificationService.sendPushNotification(
                    type: "bet_settled",
                    userIds: winnerIds,
                    title: "You Won! 🎉",
                    body: "\"\(winner)\" won in \"\(bet.title)\"",
                    metadata: ["bet_id": bet.id.uuidString, "winner": winner]
                )
            }
            // Notify losers
            let losers = wagers.filter { $0.side != winner && $0.userId != userId }
            let loserIds = Array(Set(losers.map { $0.userId })).map { $0.uuidString }
            if !loserIds.isEmpty {
                await notificationService.sendPushNotification(
                    type: "bet_settled",
                    userIds: loserIds,
                    title: "Better luck next time",
                    body: "\"\(winner)\" won in \"\(bet.title)\"",
                    metadata: ["bet_id": bet.id.uuidString, "winner": winner]
                )
            }
            await loadBet(betId: bet.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSettling = false
    }

    func deleteBet() async -> Bool {
        guard let bet,
              let userId = await authService.currentUserId else { return false }
        do {
            // Notify participants before deleting
            let participantIds = Array(Set(wagers.map { $0.userId }.filter { $0 != userId })).map { $0.uuidString }
            try await betService.deleteBet(betId: bet.id, userId: userId)
            if !participantIds.isEmpty {
                await notificationService.sendPushNotification(
                    type: "bet_created",
                    userIds: participantIds,
                    title: "Bet Deleted",
                    body: "\"\(bet.title)\" was deleted. All wagers refunded.",
                    metadata: ["bet_id": bet.id.uuidString]
                )
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
