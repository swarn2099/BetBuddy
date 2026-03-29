import Foundation

@Observable
final class SideBetViewModel {
    var sideBet: SideBet?
    var creatorProfile: Profile?
    var opponentProfile: Profile?
    var votes: [SideBetVote] = []
    var isLoading = false
    var errorMessage: String?

    private let sideBetService = SideBetService()
    private let profileService = ProfileService()
    private let authService = AuthService()
    private let notificationService = NotificationService()

    var currentUserId: UUID? {
        get async { await authService.currentUserId }
    }

    func loadSideBet(sideBetId: UUID) async {
        isLoading = true
        do {
            sideBet = try await sideBetService.fetchSideBet(sideBetId: sideBetId)
            if let sb = sideBet {
                creatorProfile = try? await profileService.fetchProfile(userId: sb.creatorId)
                opponentProfile = try? await profileService.fetchProfile(userId: sb.opponentId)
                if sb.isDeclaring && sb.opponentConfirms == false {
                    votes = (try? await sideBetService.fetchVotes(sideBetId: sb.id)) ?? []
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func acceptSideBet() async {
        guard let sb = sideBet, let userId = await authService.currentUserId else { return }
        do {
            try await sideBetService.acceptSideBet(sideBetId: sb.id, userId: userId)
            await notificationService.sendPushNotification(
                type: "side_bet_accepted", userIds: [sb.creatorId.uuidString],
                title: "Side Bet Accepted!", body: "\(opponentProfile?.username ?? "Opponent") accepted your challenge: \"\(sb.title)\"",
                metadata: ["side_bet_id": sb.id.uuidString]
            )
            await loadSideBet(sideBetId: sb.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineSideBet() async {
        guard let sb = sideBet, let userId = await authService.currentUserId else { return }
        do {
            try await sideBetService.declineSideBet(sideBetId: sb.id, userId: userId)
            await notificationService.sendPushNotification(
                type: "side_bet_declined", userIds: [sb.creatorId.uuidString],
                title: "Side Bet Declined", body: "\(opponentProfile?.username ?? "Opponent") declined: \"\(sb.title)\"",
                metadata: ["side_bet_id": sb.id.uuidString]
            )
            await loadSideBet(sideBetId: sb.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declareWinner(_ winner: String) async {
        guard let sb = sideBet, let userId = await authService.currentUserId else { return }
        let otherUserId = userId == sb.creatorId ? sb.opponentId : sb.creatorId
        do {
            try await sideBetService.declareWinner(sideBetId: sb.id, userId: userId, winner: winner)
            await notificationService.sendPushNotification(
                type: "side_bet_declaring", userIds: [otherUserId.uuidString],
                title: "Side Bet — Confirm Result", body: "A winner was declared for \"\(sb.title)\". Confirm or dispute.",
                metadata: ["side_bet_id": sb.id.uuidString]
            )
            await loadSideBet(sideBetId: sb.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmWinner() async {
        guard let sb = sideBet, let userId = await authService.currentUserId else { return }
        do {
            try await sideBetService.confirmWinner(sideBetId: sb.id, userId: userId)
            await notificationService.sendPushNotification(
                type: "side_bet_confirmed", userIds: [sb.creatorId.uuidString, sb.opponentId.uuidString],
                title: "Side Bet Settled!", body: "\"\(sb.title)\" has been settled.",
                metadata: ["side_bet_id": sb.id.uuidString]
            )
            await loadSideBet(sideBetId: sb.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disputeResult() async {
        guard let sb = sideBet, let userId = await authService.currentUserId else { return }
        do {
            try await sideBetService.disputeSideBet(sideBetId: sb.id, userId: userId)
            await loadSideBet(sideBetId: sb.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func castVote(_ vote: String) async {
        guard let sb = sideBet, let userId = await authService.currentUserId else { return }
        do {
            try await sideBetService.castVote(sideBetId: sb.id, voterId: userId, vote: vote)
            await loadSideBet(sideBetId: sb.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
