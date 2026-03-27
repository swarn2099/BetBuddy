import Foundation

@Observable
final class CreateBetViewModel {
    var selectedGroupId: UUID?
    var emoji = "🎲"
    var title = ""
    var outcomes = ["", ""]
    var hasDeadline = false
    var deadline = Date().addingTimeInterval(86400)
    var isCreating = false
    var errorMessage: String?

    private let betService = BetService()
    private let authService = AuthService()

    static let emojiOptions = ["🎲", "🌮", "🌧️", "⏰", "📚", "☕", "🏀", "🎬", "🎵", "🍕", "🚗", "💪", "🎯", "🤔", "😂"]

    var isValid: Bool {
        selectedGroupId != nil
        && !title.trimmingCharacters(in: .whitespaces).isEmpty
        && validOutcomes.count >= 2
        && (!hasDeadline || deadline > Date())
    }

    var validOutcomes: [String] {
        outcomes.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func addOutcome() {
        guard outcomes.count < 8 else { return }
        outcomes.append("")
    }

    func removeOutcome(at index: Int) {
        guard outcomes.count > 2 else { return }
        outcomes.remove(at: index)
    }

    func createBet() async -> Bet? {
        guard let groupId = selectedGroupId,
              let userId = await authService.currentUserId else { return nil }
        isCreating = true
        errorMessage = nil
        do {
            let bet = try await betService.createBet(
                groupId: groupId,
                creatorId: userId,
                title: title.trimmingCharacters(in: .whitespaces),
                emoji: emoji,
                outcomes: validOutcomes,
                deadline: hasDeadline ? deadline : nil
            )
            isCreating = false
            return bet
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return nil
        }
    }

    func reset() {
        emoji = "🎲"
        title = ""
        outcomes = ["", ""]
        hasDeadline = false
        deadline = Date().addingTimeInterval(86400)
        errorMessage = nil
    }
}
