import Foundation

@Observable
final class HomeViewModel {
    var bets: [Bet] = []
    var betParticipants: [UUID: [Profile]] = [:]
    var isLoading = false
    var errorMessage: String?

    private let betService = BetService()
    private let profileService = ProfileService()
    private let realtimeService = RealtimeService()

    func loadBets(groupId: UUID) async {
        isLoading = true
        do {
            bets = try await betService.fetchBets(groupId: groupId)
            await loadParticipants()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadParticipants() async {
        for bet in bets {
            guard betParticipants[bet.id] == nil else { continue }
            if let wagers = try? await betService.fetchWagers(betId: bet.id) {
                let uniqueIds = Array(Set(wagers.map(\.userId)))
                var profiles: [Profile] = []
                for userId in uniqueIds {
                    if let profile = try? await profileService.fetchProfile(userId: userId) {
                        profiles.append(profile)
                    }
                }
                betParticipants[bet.id] = profiles
            }
        }
    }

    func subscribeToBets(groupId: UUID) async {
        await realtimeService.subscribeToBets(
            groupId: groupId,
            onInsert: { [weak self] bet in
                guard let self else { return }
                if !self.bets.contains(where: { $0.id == bet.id }) {
                    self.bets.insert(bet, at: 0)
                }
            },
            onUpdate: { [weak self] bet in
                guard let self else { return }
                if let index = self.bets.firstIndex(where: { $0.id == bet.id }) {
                    self.bets[index] = bet
                }
            },
            onDelete: { [weak self] id in
                self?.bets.removeAll { $0.id == id }
                self?.betParticipants.removeValue(forKey: id)
            }
        )
    }

    func unsubscribe() async {
        await realtimeService.unsubscribeFromBets()
    }
}
