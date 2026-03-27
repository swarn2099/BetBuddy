import Foundation

@Observable
final class HomeViewModel {
    var bets: [Bet] = []
    var isLoading = false
    var errorMessage: String?

    private let betService = BetService()
    private let realtimeService = RealtimeService()

    func loadBets(groupId: UUID) async {
        isLoading = true
        do {
            bets = try await betService.fetchBets(groupId: groupId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
            }
        )
    }

    func unsubscribe() async {
        await realtimeService.unsubscribeFromBets()
    }
}
