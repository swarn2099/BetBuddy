import Foundation

@Observable
final class HomeViewModel {
    var bets: [Bet] = []
    var sideBets: [SideBet] = []
    var sideBetProfiles: [UUID: Profile] = [:]
    var betParticipants: [UUID: [Profile]] = [:]
    var betCreators: [UUID: Profile] = [:]
    var isLoading = false
    var errorMessage: String?

    private let betService = BetService()
    private let sideBetService = SideBetService()
    private let profileService = ProfileService()
    private let realtimeService = RealtimeService()

    func loadBets(groupId: UUID) async {
        isLoading = true
        do {
            bets = try await betService.fetchBets(groupId: groupId)
            sideBets = (try? await sideBetService.fetchSideBets(groupId: groupId)) ?? []
            await loadCreatorsAndParticipants()
            await loadSideBetProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadCreatorsAndParticipants() async {
        for bet in bets {
            // Load creator
            if betCreators[bet.creatorId] == nil {
                if let profile = try? await profileService.fetchProfile(userId: bet.creatorId) {
                    betCreators[bet.creatorId] = profile
                }
            }
            // Load participants
            if betParticipants[bet.id] == nil {
                if let wagers = try? await betService.fetchWagers(betId: bet.id) {
                    let uniqueIds = Array(Set(wagers.map(\.userId)))
                    var profiles: [Profile] = []
                    for userId in uniqueIds {
                        let profile: Profile?
                        if let cached = betCreators[userId] {
                            profile = cached
                        } else {
                            profile = try? await profileService.fetchProfile(userId: userId)
                        }
                        if let profile {
                            profiles.append(profile)
                            betCreators[userId] = profile
                        }
                    }
                    betParticipants[bet.id] = profiles
                }
            }
        }
    }

    private func loadSideBetProfiles() async {
        for sb in sideBets {
            for userId in [sb.creatorId, sb.opponentId] where sideBetProfiles[userId] == nil {
                if let profile = try? await profileService.fetchProfile(userId: userId) {
                    sideBetProfiles[userId] = profile
                }
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
