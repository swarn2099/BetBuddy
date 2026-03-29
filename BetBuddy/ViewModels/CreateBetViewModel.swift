import Foundation

@Observable
final class CreateBetViewModel {
    var selectedGroupId: UUID?
    var emoji = "🎲"
    var title = ""
    var outcomes = ["", ""]
    var creatorCanBet = true
    var hasDeadline = false
    var deadline = Date().addingTimeInterval(86400)
    var imageData: Data?
    var selectedTemplate: BetTemplate?
    var selectedCategory: BetCategory?
    var isRecurring = false
    var frequency = "weekly"
    var dayOfWeek = Calendar.current.component(.weekday, from: Date()) - 1
    var isCreating = false
    var errorMessage: String?

    private let betService = BetService()
    private let authService = AuthService()
    private let recurringBetService = RecurringBetService()
    private let notificationService = NotificationService()
    private let groupService = GroupService()

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

    func applyTemplate(_ template: BetTemplate) {
        selectedTemplate = template
        emoji = template.emoji
        outcomes = template.outcomes
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
            // If recurring, create the recurring bet definition first
            if isRecurring {
                let _ = try await recurringBetService.createRecurringBet(
                    groupId: groupId, creatorId: userId,
                    title: title.trimmingCharacters(in: .whitespaces),
                    emoji: emoji, outcomes: validOutcomes,
                    frequency: frequency, dayOfWeek: dayOfWeek,
                    creatorCanBet: creatorCanBet
                )
            }

            let bet = try await betService.createBet(
                groupId: groupId,
                creatorId: userId,
                title: title.trimmingCharacters(in: .whitespaces),
                emoji: emoji,
                outcomes: validOutcomes,
                deadline: hasDeadline ? deadline : nil,
                creatorCanBet: creatorCanBet,
                category: selectedCategory?.rawValue,
                template: selectedTemplate?.rawValue
            )
            if let imgData = imageData {
                _ = try? await betService.uploadBetImage(betId: bet.id, imageData: imgData)
            }
            do {
                let members = try await groupService.fetchGroupMembers(groupId: groupId)
                let otherUserIds = members.filter { $0.id != userId }.map { $0.id.uuidString }
                if !otherUserIds.isEmpty {
                    await notificationService.sendPushNotification(
                        type: "bet_created",
                        userIds: otherUserIds,
                        title: "New Bet",
                        body: "\(bet.emoji) \(bet.title)",
                        metadata: ["bet_id": bet.id.uuidString, "group_id": groupId.uuidString]
                    )
                }
            } catch { /* notification failure is non-fatal */ }
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
        selectedTemplate = nil
        selectedCategory = nil
        errorMessage = nil
    }
}
