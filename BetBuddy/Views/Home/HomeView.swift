import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(HomeViewModel.self) private var homeVM
    @State private var showGroupSelector = false
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var showCreateBet = false

    var body: some View {
        NavigationStack {
            Group {
                if groupVM.groups.isEmpty {
                    emptyState
                } else if let group = groupVM.selectedGroup {
                    betFeed(group: group)
                } else {
                    LoadingView()
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("")
            .toolbar {
                if let group = groupVM.selectedGroup {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showGroupSelector = true
                        } label: {
                            HStack(spacing: 8) {
                                AvatarView(name: group.name, size: 28, imageURL: group.imageUrl)
                                Text(group.name)
                                    .font(.button15)
                                    .foregroundStyle(Color.textPrimary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            NavigationLink {
                                GroupSettingsView(group: group)
                            } label: {
                                Image(systemName: "gearshape")
                                    .foregroundStyle(Color.textSecondary)
                            }
                            NavigationLink {
                                LeaderboardView(groupId: group.id)
                            } label: {
                                Image(systemName: "trophy")
                                    .foregroundStyle(Color.accentWarning)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showGroupSelector) {
                GroupSelectorSheet(
                    showCreateGroup: $showCreateGroup,
                    showJoinGroup: $showJoinGroup
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView()
            }
            .sheet(isPresented: $showJoinGroup) {
                JoinGroupView()
            }
            .fullScreenCover(isPresented: $showCreateBet) {
                CreateBetView()
            }
            .navigationDestination(for: Bet.self) { bet in
                BetDetailView(betId: bet.id)
            }
        }
        .task {
            await groupVM.loadGroups()
        }
        .onChange(of: groupVM.selectedGroup?.id) { _, newId in
            if let id = newId {
                Task {
                    await homeVM.loadBets(groupId: id)
                    await homeVM.subscribeToBets(groupId: id)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🎲")
                .font(.system(size: 64))
            Text("Join or create a group to start betting")
                .font(.heading2)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Button {
                    showCreateGroup = true
                } label: {
                    Text("Create Group")
                        .font(.button15)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [Color.accentPrimary, Color.accentViolet], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                }
                Button {
                    showJoinGroup = true
                } label: {
                    Text("Join Group")
                        .font(.button15)
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
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    @ViewBuilder
    private func betFeed(group: BetGroup) -> some View {
        ScrollView {
            LazyVStack(spacing: Spacing.cardGap) {
                if homeVM.bets.isEmpty && !homeVM.isLoading {
                    EmptyGroupView(onCreateBet: { showCreateBet = true })
                        .padding(.top, 60)
                } else {
                    ForEach(homeVM.bets) { bet in
                        NavigationLink(value: bet) {
                            BetCardView(bet: bet)
                        }
                        .buttonStyle(.scale)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.topPadding)
        }
        .refreshable {
            await homeVM.loadBets(groupId: group.id)
        }
        .overlay {
            if homeVM.isLoading && homeVM.bets.isEmpty {
                LoadingView()
            }
        }
    }
}
