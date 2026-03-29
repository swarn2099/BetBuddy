import SwiftUI

struct BetHistoryView: View {
    let groupId: UUID
    @State private var vm = BetHistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                // Stats cards
                if !vm.stats.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HIGHLIGHTS")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(vm.stats) { stat in
                                VStack(spacing: 6) {
                                    Text(stat.icon)
                                        .font(.system(size: 24))
                                    Text(stat.title)
                                        .font(.label11)
                                        .foregroundStyle(Color.textLabel)
                                        .textCase(.uppercase)
                                    Text(stat.value)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .glassCard()
                            }
                        }
                    }
                }

                // Settled bets
                VStack(alignment: .leading, spacing: 12) {
                    Text("SETTLED BETS (\(vm.entries.count))")
                        .font(.label11)
                        .foregroundStyle(Color.textLabel)
                        .tracking(0.5)

                    if vm.entries.isEmpty && !vm.isLoading {
                        Text("No settled bets yet")
                            .font(.body15)
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }

                    ForEach(vm.entries) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(entry.bet.emoji)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.bet.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(1)
                                    if let winner = entry.bet.winner {
                                        Text("Winner: \(winner)")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.accentSuccess)
                                    }
                                }
                                Spacer()
                                if let badge = entry.badge {
                                    Text(badge)
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentWarning.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }

                            // Participants
                            HStack(spacing: -6) {
                                ForEach(Array(entry.wagers.prefix(6).enumerated()), id: \.offset) { _, wager in
                                    let profile = vm.profiles[wager.userId]
                                    AvatarView(name: profile?.username ?? "?", size: 24, imageURL: profile?.avatarUrl)
                                        .overlay(Circle().stroke(Color.bgCard, lineWidth: 2))
                                }
                            }

                            Text("$\(entry.bet.pool) pool · \(entry.wagers.count) wagers")
                                .font(.cardMeta)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(14)
                        .glassCard()
                    }
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.topPadding)
            .padding(.bottom, 40)
        }
        .background(Color.bgPrimary)
        .navigationTitle("Bet History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading { LoadingView() }
        }
        .task {
            await vm.loadHistory(groupId: groupId)
        }
    }
}
