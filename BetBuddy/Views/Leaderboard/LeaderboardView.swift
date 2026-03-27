import SwiftUI

struct LeaderboardView: View {
    let groupId: UUID
    @State private var vm = LeaderboardViewModel()
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        VStack(spacing: 0) {
            // Scope toggle
            Picker("Scope", selection: $vm.scope) {
                Text("Global").tag(LeaderboardViewModel.Scope.global)
                Text("Group").tag(LeaderboardViewModel.Scope.group)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.screenH)
            .padding(.vertical, 12)

            ScrollView {
                LazyVStack(spacing: 8) {
                    let rankings = vm.scope == .global ? vm.globalRankings : vm.groupRankings
                    ForEach(Array(rankings.enumerated()), id: \.element.id) { index, profile in
                        leaderboardRow(rank: index + 1, profile: profile)
                    }
                }
                .padding(.horizontal, Spacing.screenH)
            }
            .overlay {
                if vm.isLoading {
                    LoadingView()
                }
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.loadGlobalRankings()
            await vm.loadGroupRankings(groupId: groupId)
        }
    }

    private func leaderboardRow(rank: Int, profile: Profile) -> some View {
        let isCurrentUser = profile.id == authVM.currentUser?.id
        return HStack(spacing: 12) {
            // Rank
            Group {
                switch rank {
                case 1: Text("🥇")
                case 2: Text("🥈")
                case 3: Text("🥉")
                default: Text("\(rank)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(width: 32)

            AvatarView(name: profile.username, size: 40, imageURL: profile.avatarUrl)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.username)
                    .font(.button15)
                    .foregroundStyle(Color.textPrimary)
                Text("\(profile.firstName) \(profile.lastName)")
                    .font(.cardMeta)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            BalanceView(amount: profile.balance, font: .poolAmount)
        }
        .padding(12)
        .glassCard()
        .overlay(
            isCurrentUser ?
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .stroke(Color.accentPrimary, lineWidth: 2) : nil
        )
    }
}
