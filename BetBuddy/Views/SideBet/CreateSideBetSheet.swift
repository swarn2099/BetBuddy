import SwiftUI

struct CreateSideBetSheet: View {
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var emoji = "🤝"
    @State private var amount = 0
    @State private var selectedOpponent: Profile?
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let sideBetService = SideBetService()
    private let notificationService = NotificationService()

    static let emojiOptions = ["🤝", "🎲", "💪", "🏀", "🌮", "😂", "🔥", "🎯"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Opponent picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CHALLENGE")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)

                        ForEach(groupVM.members.filter { $0.id != authVM.currentUser?.id }) { member in
                            Button {
                                selectedOpponent = member
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(name: member.username, size: 40, imageURL: member.avatarUrl)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.username)
                                            .font(.button15)
                                            .foregroundStyle(Color.textPrimary)
                                        Text("$\(member.balance)")
                                            .font(.cardMeta)
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                    Spacer()
                                    if selectedOpponent?.id == member.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentPrimary)
                                            .font(.system(size: 22))
                                    }
                                }
                                .padding(12)
                                .background(selectedOpponent?.id == member.id ? Color.accentPrimary.opacity(0.08) : Color.bgSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedOpponent?.id == member.id ? Color.accentPrimary : Color.borderPrimary, lineWidth: 1)
                                )
                            }
                        }
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WHAT'S THE BET?")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        TextField("e.g. I can beat you at chess", text: $title)
                            .font(.body15)
                            .padding()
                            .background(Color.bgInput)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )
                    }

                    // Emoji
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EMOJI")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        HStack(spacing: 8) {
                            ForEach(Self.emojiOptions, id: \.self) { e in
                                Button {
                                    emoji = e
                                } label: {
                                    Text(e)
                                        .font(.system(size: 24))
                                        .frame(width: 40, height: 40)
                                        .background(emoji == e ? Color.accentPrimary.opacity(0.2) : Color.bgEmoji)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            emoji == e ? RoundedRectangle(cornerRadius: 10).stroke(Color.accentPrimary, lineWidth: 2) : nil
                                        )
                                }
                            }
                        }
                    }

                    // Amount
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AMOUNT (EACH)")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        HStack(spacing: 8) {
                            ForEach([10, 25, 50, 100], id: \.self) { a in
                                Button {
                                    amount = a
                                } label: {
                                    Text("$\(a)")
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(amount == a ? Color.accentPrimary.opacity(0.2) : Color.bgSurface)
                                        .foregroundStyle(amount == a ? Color.accentPrimary : Color.textSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(amount == a ? Color.accentPrimary : Color.borderPrimary, lineWidth: 1)
                                        )
                                }
                            }
                        }
                        TextField("Custom", value: $amount, format: .number)
                            .keyboardType(.numberPad)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .padding()
                            .background(Color.bgInput)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )
                    }

                    if let error = errorMessage {
                        Text(error).font(.cardMeta).foregroundStyle(Color.accentDanger)
                    }

                    // Create button
                    Button {
                        Task { await create() }
                    } label: {
                        Group {
                            if isCreating {
                                ProgressView().tint(.white)
                            } else {
                                Text("Send Challenge")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(colors: [Color.accentPrimary, Color.accentViolet], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                    }
                    .disabled(selectedOpponent == nil || title.isEmpty || amount <= 0 || isCreating)
                    .opacity(selectedOpponent != nil && !title.isEmpty && amount > 0 ? 1 : 0.5)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.topPadding)
                .padding(.bottom, 40)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Side Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func create() async {
        guard let opponent = selectedOpponent,
              let userId = authVM.currentUser?.id,
              let groupId = groupVM.selectedGroup?.id else { return }
        isCreating = true
        errorMessage = nil
        do {
            let _ = try await sideBetService.createSideBet(
                groupId: groupId, creatorId: userId, opponentId: opponent.id,
                title: title, emoji: emoji, amount: amount
            )
            await notificationService.sendPushNotification(
                type: "side_bet_created", userIds: [opponent.id.uuidString],
                title: "🤝 Side Bet Challenge!",
                body: "\(authVM.currentUser?.username ?? "Someone") challenged you: \"\(title)\" for $\(amount)",
                metadata: ["group_id": groupId.uuidString]
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }
}
