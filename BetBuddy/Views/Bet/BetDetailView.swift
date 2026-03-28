import SwiftUI

struct BetDetailView: View {
    let betId: UUID
    @State private var betVM = BetViewModel()
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var showPlaceBetSheet = false
    @State private var showManageBetSheet = false
    @State private var showSettleConfirm = false
    @State private var settleOutcome = ""
    @State private var showDeleteConfirm = false
    @State private var activeToast: ToastType?

    private var isCreator: Bool {
        betVM.bet?.creatorId == authVM.currentUser?.id
    }

    private var userAlreadyBet: Bool {
        guard let userId = authVM.currentUser?.id else { return false }
        return betVM.wagers.contains { $0.userId == userId }
    }

    private var creatorBlocked: Bool {
        guard let bet = betVM.bet, let userId = authVM.currentUser?.id else { return false }
        return bet.creatorId == userId && !bet.creatorCanBet
    }

    private var canPlaceBet: Bool {
        guard let bet = betVM.bet else { return false }
        return bet.isActive && !bet.isPastDeadline && !userAlreadyBet && !creatorBlocked
    }

    var body: some View {
        ScrollView {
            if let bet = betVM.bet {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    // Header — Apple Music style
                    if let url = bet.imageUrl, let imageURL = URL(string: url) {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.bgSurface
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .clipped()

                            // Blurred text area at bottom
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(bet.emoji)
                                        .font(.system(size: 20))
                                    StatusPillView(status: bet.status, deadline: bet.deadline)
                                }
                                Text(bet.title)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                if let creator = betVM.wagerProfiles[bet.creatorId] {
                                    Text("by \(creator.username)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .environment(\.colorScheme, .dark)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                    } else {
                        VStack(spacing: 12) {
                            Text(bet.emoji)
                                .font(.system(size: 48))
                            Text(bet.title)
                                .font(.heading2)
                                .foregroundStyle(Color.textPrimary)
                                .multilineTextAlignment(.center)
                            if let creator = betVM.wagerProfiles[bet.creatorId] {
                                Text("by \(creator.username)")
                                    .font(.cardMeta)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            StatusPillView(status: bet.status, deadline: bet.deadline)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        if canPlaceBet {
                            Button {
                                showPlaceBetSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Place a Bet")
                                        .font(.system(size: 16, weight: .bold))
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
                        } else if userAlreadyBet && bet.isActive {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentSuccess)
                                Text("Bet placed")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassCard()
                        }

                        if isCreator && bet.isActive {
                            Button {
                                showManageBetSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 16))
                                    Text("Manage")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .frame(maxWidth: canPlaceBet ? nil : .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal, canPlaceBet ? 20 : 0)
                                .background(Color.bgSurface)
                                .foregroundStyle(Color.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                        .stroke(Color.borderPrimary, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.scale)
                        }
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
        .background(Color.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPlaceBetSheet) {
            if let bet = betVM.bet {
                PlaceBetSheet(bet: bet, betVM: betVM, authVM: authVM, onSuccess: { side, amount in
                    activeToast = .betPlaced(side: side, amount: amount)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                })
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showManageBetSheet) {
            if let bet = betVM.bet {
                ManageBetSheet(
                    bet: bet,
                    betVM: betVM,
                    settleOutcome: $settleOutcome,
                    showSettleConfirm: $showSettleConfirm,
                    showDeleteConfirm: $showDeleteConfirm,
                    showManageBetSheet: $showManageBetSheet
                )
                .presentationDetents([.medium])
            }
        }
        .alert("Settle Bet", isPresented: $showSettleConfirm) {
            Button("Confirm", role: .destructive) {
                Task {
                    await betVM.settleBet(winner: settleOutcome)
                    if betVM.errorMessage == nil {
                        activeToast = .betSettled
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
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
        .toast($activeToast)
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
}

// MARK: - Place Bet Bottom Sheet
struct PlaceBetSheet: View {
    let bet: Bet
    @Bindable var betVM: BetViewModel
    let authVM: AuthViewModel
    var onSuccess: ((String, Int) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Pick your side")
                        .font(.heading2)
                        .foregroundStyle(Color.textPrimary)

                    // Outcome selector
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
                        // Quick picks
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
                                    let side = betVM.selectedSide ?? ""
                                    let amount = betVM.wagerAmount
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    await authVM.refreshProfile()
                                    dismiss()
                                    onSuccess?(side, amount)
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

                        if let error = betVM.errorMessage {
                            Text(error)
                                .font(.cardMeta)
                                .foregroundStyle(Color.accentDanger)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.topPadding)
                .padding(.bottom, 40)
            }
            .background(Color.bgPrimary)
            .navigationTitle(bet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - Manage Bet Bottom Sheet
struct ManageBetSheet: View {
    let bet: Bet
    @Bindable var betVM: BetViewModel
    @Binding var settleOutcome: String
    @Binding var showSettleConfirm: Bool
    @Binding var showDeleteConfirm: Bool
    @Binding var showManageBetSheet: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("SETTLE — Pick the winner")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.textLabel)
                    .tracking(1)

                ForEach(Array(bet.outcomes.enumerated()), id: \.offset) { index, outcome in
                    Button {
                        settleOutcome = outcome
                        showManageBetSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showSettleConfirm = true
                        }
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
                    .buttonStyle(.scale)
                }

                Divider()
                    .background(Color.borderPrimary)

                Button(role: .destructive) {
                    showManageBetSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Label("Delete Bet & Refund All", systemImage: "trash")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.accentDanger)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.topPadding)
            .background(Color.bgPrimary)
            .navigationTitle("Manage Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showManageBetSheet = false }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}
