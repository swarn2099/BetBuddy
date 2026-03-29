import Foundation

struct BetHistoryStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: String // hex or name
}

struct SettledBetEntry: Identifiable {
    let id: UUID
    let bet: Bet
    let wagers: [Wager]
    var badge: String? // "🏆 Sweep!", "🎯 Upset!"
}

@Observable
final class BetHistoryViewModel {
    var entries: [SettledBetEntry] = []
    var stats: [BetHistoryStat] = []
    var isLoading = false

    private let betService = BetService()
    private let profileService = ProfileService()
    var profiles: [UUID: Profile] = [:]

    func loadHistory(groupId: UUID) async {
        isLoading = true
        do {
            let allBets = try await betService.fetchBets(groupId: groupId)
            let settled = allBets.filter { $0.isSettled }

            var results: [SettledBetEntry] = []
            for bet in settled {
                let wagers = try await betService.fetchWagers(betId: bet.id)
                // Load profiles
                for w in wagers where profiles[w.userId] == nil {
                    if let p = try? await profileService.fetchProfile(userId: w.userId) {
                        profiles[p.id] = p
                    }
                }

                var badge: String?
                if let winner = bet.winner {
                    let winnerPool = wagers.filter { $0.side == winner }.reduce(0) { $0 + $1.amount }
                    let totalPool = bet.pool
                    if totalPool > 0 {
                        let winnerPct = Double(winnerPool) / Double(totalPool)
                        if winnerPct <= 0.2 { badge = "🎯 Upset!" }
                        else if winnerPct >= 0.8 { badge = "🏆 Sweep!" }
                    }
                }
                results.append(SettledBetEntry(id: bet.id, bet: bet, wagers: wagers, badge: badge))
            }
            entries = results

            // Compute stats
            computeStats()
        } catch {
            // Non-fatal
        }
        isLoading = false
    }

    private func computeStats() {
        var userWins: [UUID: Int] = [:]
        var userLosses: [UUID: Int] = [:]
        var userWinCount: [UUID: Int] = [:]
        var userBetCount: [UUID: Int] = [:]
        var biggestWin: (UUID, Int) = (UUID(), 0)
        var worstLoss: (UUID, Int) = (UUID(), 0)

        for entry in entries {
            guard let winner = entry.bet.winner else { continue }
            for wager in entry.wagers {
                userBetCount[wager.userId, default: 0] += 1
                if wager.side == winner {
                    let winnerPool = entry.wagers.filter { $0.side == winner }.reduce(0) { $0 + $1.amount }
                    let loserPool = entry.wagers.filter { $0.side != winner }.reduce(0) { $0 + $1.amount }
                    let profit = winnerPool > 0 ? Int(Double(wager.amount) / Double(winnerPool) * Double(loserPool)) : 0
                    userWins[wager.userId, default: 0] += profit
                    userWinCount[wager.userId, default: 0] += 1
                    if profit > biggestWin.1 { biggestWin = (wager.userId, profit) }
                } else {
                    userLosses[wager.userId, default: 0] += wager.amount
                    if wager.amount > worstLoss.1 { worstLoss = (wager.userId, wager.amount) }
                }
            }
        }

        var result: [BetHistoryStat] = []

        if biggestWin.1 > 0 {
            let name = profiles[biggestWin.0]?.username ?? "?"
            result.append(BetHistoryStat(title: "Biggest Win", value: "\(name) +$\(biggestWin.1)", icon: "🤑", color: "green"))
        }
        if worstLoss.1 > 0 {
            let name = profiles[worstLoss.0]?.username ?? "?"
            result.append(BetHistoryStat(title: "Worst Beat", value: "\(name) -$\(worstLoss.1)", icon: "💀", color: "red"))
        }

        // Luckiest (highest win rate with min 2 bets)
        let lucky = userWinCount.filter { userBetCount[$0.key, default: 0] >= 2 }
            .max(by: { Double($0.value) / Double(userBetCount[$0.key]!) < Double($1.value) / Double(userBetCount[$1.key]!) })
        if let lucky {
            let name = profiles[lucky.key]?.username ?? "?"
            let rate = Int(Double(lucky.value) / Double(userBetCount[lucky.key]!) * 100)
            result.append(BetHistoryStat(title: "Luckiest", value: "\(name) \(rate)%", icon: "🍀", color: "green"))
        }

        // Most Active
        let active = userBetCount.max(by: { $0.value < $1.value })
        if let active {
            let name = profiles[active.key]?.username ?? "?"
            result.append(BetHistoryStat(title: "Most Active", value: "\(name) (\(active.value) bets)", icon: "🔥", color: "orange"))
        }

        stats = result
    }
}
