import SwiftUI

struct BetDetailView: View {
    let betId: UUID
    @State private var betVM = BetViewModel()
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var showSettleConfirm = false
    @State private var settleOutcome = ""
    @State private var showDeleteConfirm = false

    private var isCreator: Bool {
        betVM.bet?.creatorId == authVM.currentUser?.id
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
        ScrollView {
            if let bet = betVM.bet {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    // Header with optional image
                    ZStack {
                        if let url = bet.imageUrl, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.bgSurface
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                                    .fill(.black.opacity(0.4))
                            )
                        }

                        VStack(spacing: 12) {
                            Text(bet.emoji)
                                .font(.system(size: 48))
                            Text(bet.title)
                                .font(.heading2)
                                .foregroundStyle(bet.imageUrl != nil ? .white : Color.textPrimary)
                                .multilineTextAlignment(.center)
                            StatusPillView(status: bet.status, deadline: bet.deadline)
                        }
                        .padding(.vertical, bet.imageUrl != nil ? 20 : 0)
                    }
                    .frame(maxWidth: .infinity)

                    // CTA button if active
                    if bet.isActive && !bet.isPastDeadline {
                        Button {
                            withAnimation {
                                scrollProxy.scrollTo("placeBetSection", anchor: .top)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                Text("Place a Bet")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color.accentPrimary, Color.accentViolet], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                        }
                        .buttonStyle(.scale)
                    }

                    // Stats row
                    HStack {
                        statItem(label: "POOL", value: "$\(bet.pool)", color: Color.accentPrimary)
                        Spacer()
                        statItem(label: "DEADLINE", value: bet.deadline?.betDeadlineText ?? "Open", color: Color.textSecondary)
                        Spacer()
                        statItem(label: "WAGERS", value: "\(betVM.wagers.count)", color: Color.accentWarning)
                    }
                    .padding()
                    .glassCard()

                    // Outcomes breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("RESULTS")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)

                        ForEach(Array(bet.outcomes.enumerated()), id: \.offset) { index, outcome in
                            outcomeRow(bet: bet, outcome: outcome, index: index)
                        }
                    }

                    // Wagers list
                    if !betVM.wagers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ALL WAGERS")
                                .font(.label11)
                                .foregroundStyle(Color.textLabel)
                                .tracking(0.5)

                            ForEach(betVM.wagers) { wager in
                                wagerRow(wager: wager, bet: bet)
                            }
                        }
                    }

                    // Actions
                    if bet.isActive {
                        actionSection(bet: bet)
                            .id("placeBetSection")
                    }

                    if let error = betVM.errorMessage {
                        Text(error)
                            .font(.cardMeta)
                            .foregroundStyle(Color.accentDanger)
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.topPadding)
                .padding(.bottom, 40)
            } else if betVM.isLoading {
                LoadingView()
                    .frame(height: 300)
            }
        }
        } // ScrollViewReader
        .background(Color.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Settle Bet", isPresented: $showSettleConfirm) {
            Button("Confirm", role: .destructive) {
                Task { await betVM.settleBet(winner: settleOutcome) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Declare \"\(settleOutcome)\" as the winner? This cannot be undone.")
        }
        .alert("Delete Bet", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    if await betVM.deleteBet() {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete this bet and refund all wagers?")
        }
        .task {
            await betVM.loadBet(betId: betId)
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.label11)
                .foregroundStyle(Color.textLabel)
                .tracking(0.5)
            Text(value)
                .font(.statValue)
                .foregroundStyle(color)
        }
    }

    // MARK: - Outcome row (bold, large, clear)
    private func outcomeRow(bet: Bet, outcome: String, index: Int) -> some View {
        let pool = betVM.poolForSide(outcome)
        let pct = betVM.percentageForSide(outcome)
        let isWinner = bet.winner == outcome
        let chipColor = OutcomeColor.forIndex(index).color

        return VStack(spacing: 10) {
            HStack(alignment: .center) {
                Circle()
                    .fill(chipColor)
                    .frame(width: 14, height: 14)
                Text(outcome)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                if isWinner {
                    Text("WINNER")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentSuccess)
                        .clipShape(Capsule())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(pool)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(chipColor)
                    Text(String(format: "%.0f%%", pct))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.bgSurface)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(chipColor)
                        .frame(width: max(0, geo.size.width * pct / 100), height: 10)
                        .animation(.spring, value: pct)
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(isWinner ? Color.accentSuccess.opacity(0.08) : Color.clear)
        .glassCard()
        .overlay(
            isWinner ?
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .stroke(Color.accentSuccess, lineWidth: 2) : nil
        )
    }

    // MARK: - Wager row
    private func wagerRow(wager: Wager, bet: Bet) -> some View {
        let profile = betVM.wagerProfiles[wager.userId]
        let outcomeIndex = bet.outcomes.firstIndex(of: wager.side) ?? 0

        return HStack(spacing: 10) {
            AvatarView(name: profile?.username ?? "?", size: 32, imageURL: profile?.avatarUrl)
            Text(profile?.username ?? "...")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text("$\(wager.amount)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
            OutcomeChipView(outcome: wager.side, index: outcomeIndex)
        }
        .padding(12)
        .glassCard()
    }

    // MARK: - Action section (big bold bet buttons)
    @ViewBuilder
    private func actionSection(bet: Bet) -> some View {
        if !bet.isPastDeadline {
            VStack(alignment: .leading, spacing: 16) {
                Text("PLACE YOUR BET")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.textLabel)
                    .tracking(1)

                // Big outcome selector buttons
                VStack(spacing: 10) {
                    ForEach(Array(bet.outcomes.enumerated()), id: \.offset) { index, outcome in
                        let isSelected = betVM.selectedSide == outcome
                        let chipColor = OutcomeColor.forIndex(index).color

                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                betVM.selectedSide = outcome
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(chipColor)
                                    .frame(width: 16, height: 16)
                                Text(outcome)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(isSelected ? .white : Color.textPrimary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(16)
                            .background(isSelected ? chipColor : Color.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                    .stroke(isSelected ? chipColor : Color.borderPrimary, lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .buttonStyle(.scale)
                    }
                }

                if betVM.selectedSide != nil {
                    // Amount quick picks
                    HStack(spacing: 8) {
                        ForEach([10, 25, 50, 100], id: \.self) { amount in
                            Button {
                                betVM.wagerAmount = amount
                            } label: {
                                Text("$\(amount)")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(betVM.wagerAmount == amount ? Color.accentPrimary.opacity(0.2) : Color.bgSurface)
                                    .foregroundStyle(betVM.wagerAmount == amount ? Color.accentPrimary : Color.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(betVM.wagerAmount == amount ? Color.accentPrimary : Color.borderPrimary, lineWidth: 1)
                                    )
                            }
                        }
                    }

                    TextField("Custom amount", value: $betVM.wagerAmount, format: .number)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .padding()
                        .background(Color.bgInput)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                .stroke(Color.borderPrimary, lineWidth: 1)
                        )

                    if let balance = authVM.currentUser?.balance {
                        Text("Balance: $\(balance)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Button {
                        Task {
                            await betVM.placeWager()
                            if betVM.errorMessage == nil {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                    } label: {
                        Group {
                            if betVM.isPlacingWager {
                                ProgressView().tint(.white)
                            } else {
                                Text("Bet $\(betVM.wagerAmount) on \"\(betVM.selectedSide ?? "")\"")
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
                    .disabled(betVM.wagerAmount <= 0 || betVM.isPlacingWager)
                }
            }
        } else {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                Text("Betting is closed — waiting for settlement")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(16)
            .glassCard()
        }

        if isCreator {
            VStack(spacing: 12) {
                Text("SETTLE THIS BET")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.textLabel)
                    .tracking(1)

                ForEach(Array(bet.outcomes.enumerated()), id: \.offset) { index, outcome in
                    Button {
                        settleOutcome = outcome
                        showSettleConfirm = true
                    } label: {
                        HStack {
                            Circle()
                                .fill(OutcomeColor.forIndex(index).color)
                                .frame(width: 14, height: 14)
                            Text("\"\(outcome)\" Wins")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.bgSurface)
                        .foregroundStyle(Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                .stroke(Color.borderPrimary, lineWidth: 1)
                        )
                    }
                    .disabled(betVM.isSettling)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Bet", systemImage: "trash")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.accentDanger)
                }
            }
        }
    }
}
