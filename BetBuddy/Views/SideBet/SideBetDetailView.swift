import SwiftUI

struct SideBetDetailView: View {
    let sideBetId: UUID
    @State private var vm = SideBetViewModel()
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var showDeclareSheet = false
    @State private var activeToast: ToastType?

    private var isCreator: Bool {
        authVM.currentUser?.id == vm.sideBet?.creatorId
    }
    private var isOpponent: Bool {
        authVM.currentUser?.id == vm.sideBet?.opponentId
    }
    private var isParticipant: Bool { isCreator || isOpponent }

    var body: some View {
        ScrollView {
            if let sb = vm.sideBet {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Text(sb.emoji)
                            .font(.system(size: 56))

                        // VS avatars
                        HStack(spacing: 20) {
                            VStack(spacing: 6) {
                                AvatarView(name: vm.creatorProfile?.username ?? "?", size: 56, imageURL: vm.creatorProfile?.avatarUrl)
                                Text(vm.creatorProfile?.username ?? "?")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Text("vs")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(Color.textMuted)
                            VStack(spacing: 6) {
                                AvatarView(name: vm.opponentProfile?.username ?? "?", size: 56, imageURL: vm.opponentProfile?.avatarUrl)
                                Text(vm.opponentProfile?.username ?? "?")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }

                        Text(sb.title)
                            .font(.heading2)
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("$\(sb.amount) each · $\(sb.amount * 2) total")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.accentSuccess)
                    }
                    .frame(maxWidth: .infinity)

                    // Status-dependent actions
                    if sb.isPending && isOpponent {
                        VStack(spacing: 10) {
                            Button {
                                Task {
                                    await vm.acceptSideBet()
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            } label: {
                                Text("Accept Challenge")
                                    .font(.system(size: 17, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(colors: [Color.accentSuccess, Color(hex: 0x10B981)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                            }
                            Button {
                                Task { await vm.declineSideBet(); dismiss() }
                            } label: {
                                Text("Decline")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(Color.accentDanger)
                            }
                        }
                    } else if sb.isPending && isCreator {
                        HStack {
                            Image(systemName: "hourglass")
                            Text("Waiting for \(vm.opponentProfile?.username ?? "opponent") to accept")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .glassCard()
                    } else if sb.isActive && isParticipant {
                        Button {
                            showDeclareSheet = true
                        } label: {
                            Text("Declare Winner")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [Color.accentPrimary, Color.accentViolet], startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                        }
                    } else if sb.isDeclaring && isParticipant {
                        let declarerName = sb.creatorDeclaresWinner == "creator" ? vm.creatorProfile?.username : vm.opponentProfile?.username
                        VStack(spacing: 12) {
                            Text("\(declarerName ?? "?") declared as winner")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.textPrimary)

                            if sb.opponentConfirms == nil || sb.opponentConfirms == true {
                                HStack(spacing: 12) {
                                    Button {
                                        Task { await vm.confirmWinner() }
                                    } label: {
                                        Text("Confirm")
                                            .font(.system(size: 16, weight: .bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.accentSuccess)
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                                    }
                                    Button {
                                        Task { await vm.disputeResult() }
                                    } label: {
                                        Text("Dispute")
                                            .font(.system(size: 16, weight: .bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.accentDanger.opacity(0.15))
                                            .foregroundStyle(Color.accentDanger)
                                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                                    }
                                }
                            } else {
                                // Disputed — show vote tallies
                                VStack(spacing: 8) {
                                    Text("DISPUTED — Group Vote")
                                        .font(.label11)
                                        .foregroundStyle(Color.accentWarning)
                                        .tracking(0.5)
                                    Text("Creator votes: \(vm.votes.filter { $0.vote == "creator" }.count)")
                                        .font(.button15)
                                        .foregroundStyle(Color.textPrimary)
                                    Text("Opponent votes: \(vm.votes.filter { $0.vote == "opponent" }.count)")
                                        .font(.button15)
                                        .foregroundStyle(Color.textPrimary)

                                    if !isParticipant {
                                        HStack(spacing: 12) {
                                            Button { Task { await vm.castVote("creator") } } label: {
                                                Text("Vote Creator")
                                                    .font(.button15)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(Color.bgSurface)
                                                    .foregroundStyle(Color.textPrimary)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderPrimary))
                                            }
                                            Button { Task { await vm.castVote("opponent") } } label: {
                                                Text("Vote Opponent")
                                                    .font(.button15)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(Color.bgSurface)
                                                    .foregroundStyle(Color.textPrimary)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderPrimary))
                                            }
                                        }
                                    }
                                }
                                .padding(16)
                                .glassCard()
                            }
                        }
                    } else if sb.isSettled {
                        let winnerName = sb.settledWinner == "creator" ? vm.creatorProfile?.username : vm.opponentProfile?.username
                        VStack(spacing: 8) {
                            Text("🏆 \(winnerName ?? "?") wins!")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.accentSuccess)
                            Text("+$\(sb.amount)")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentSuccess)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .glassCard()
                    } else if sb.isCancelled {
                        Text("This side bet was cancelled")
                            .font(.body15)
                            .foregroundStyle(Color.textSecondary)
                    }

                    if let error = vm.errorMessage {
                        Text(error).font(.cardMeta).foregroundStyle(Color.accentDanger)
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.topPadding)
                .padding(.bottom, 40)
            } else if vm.isLoading {
                LoadingView().frame(height: 300)
            }
        }
        .background(Color.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeclareSheet) {
            if let sb = vm.sideBet {
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("Who won?")
                            .font(.heading2)
                            .foregroundStyle(Color.textPrimary)
                            .padding(.top, 20)

                        Button {
                            Task { await vm.declareWinner("creator"); showDeclareSheet = false }
                        } label: {
                            HStack {
                                AvatarView(name: vm.creatorProfile?.username ?? "?", size: 32, imageURL: vm.creatorProfile?.avatarUrl)
                                Text(vm.creatorProfile?.username ?? "Creator")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderPrimary))
                        }

                        Button {
                            Task { await vm.declareWinner("opponent"); showDeclareSheet = false }
                        } label: {
                            HStack {
                                AvatarView(name: vm.opponentProfile?.username ?? "?", size: 32, imageURL: vm.opponentProfile?.avatarUrl)
                                Text(vm.opponentProfile?.username ?? "Opponent")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderPrimary))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.screenH)
                    .background(Color.bgPrimary)
                    .navigationTitle("Declare Winner")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cancel") { showDeclareSheet = false }
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .toast($activeToast)
        .task {
            await vm.loadSideBet(sideBetId: sideBetId)
        }
    }
}
