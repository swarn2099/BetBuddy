import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(HomeViewModel.self) private var homeVM
    @State private var showGroupSelector = false
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var showCreateBet = false
    @State private var showCreateSideBet = false
    @State private var selectedFilter: BetFilter = .all
    @State private var selectedCategory: BetCategory?

    enum BetFilter: String, CaseIterable {
        case all = "All"
        case live = "Live"
        case closingSoon = "Closing Soon"
        case settled = "Settled"
    }

    private var filteredBets: [Bet] {
        var result: [Bet]
        switch selectedFilter {
        case .all: result = homeVM.bets
        case .live: result = homeVM.bets.filter { $0.isActive && !$0.isPastDeadline }
        case .closingSoon:
            result = homeVM.bets.filter {
                guard let deadline = $0.deadline, $0.isActive else { return false }
                return deadline > Date() && deadline.timeIntervalSinceNow < 86400
            }
        case .settled: result = homeVM.bets.filter { $0.isSettled }
        }
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat.rawValue }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if groupVM.isLoading {
                    SplashView()
                } else if groupVM.groups.isEmpty {
                    emptyState
                } else if let group = groupVM.selectedGroup {
                    ZStack {
                        FloatingEmojisView()
                        betFeed(group: group)
                    }
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
                        HStack(spacing: 14) {
                            Button {
                                showCreateSideBet = true
                            } label: {
                                Image(systemName: "person.2.fill")
                                    .foregroundStyle(Color.accentViolet)
                                    .font(.system(size: 14))
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
            .sheet(isPresented: $showCreateSideBet) {
                CreateSideBetSheet()
            }
            .navigationDestination(for: Bet.self) { bet in
                BetDetailView(betId: bet.id)
            }
            .navigationDestination(for: SideBet.self) { sideBet in
                SideBetDetailView(sideBetId: sideBet.id)
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
            VStack(spacing: Spacing.cardGap) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BetFilter.allCases, id: \.self) { filter in
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedFilter = filter
                                }
                            } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.accentPrimary : Color.bgSurface)
                                    .foregroundStyle(selectedFilter == filter ? .white : Color.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        selectedFilter != filter ?
                                        Capsule().stroke(Color.borderPrimary, lineWidth: 1) : nil
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)
                }
                .padding(.top, 4)

                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(BetCategory.allCases) { cat in
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(cat.icon)
                                        .font(.system(size: 12))
                                    Text(cat.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategory == cat ? cat.color.opacity(0.2) : Color.bgSurface)
                                .foregroundStyle(selectedCategory == cat ? cat.color : Color.textMuted)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)
                }

                if homeVM.bets.isEmpty && !homeVM.isLoading {
                    EmptyGroupView(onCreateBet: { showCreateBet = true })
                        .padding(.top, 60)
                } else if filteredBets.isEmpty {
                    VStack(spacing: 8) {
                        Text("No \(selectedFilter.rawValue.lowercased()) bets")
                            .font(.button15)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 60)
                } else {
                    // Side bets
                    if !homeVM.sideBets.isEmpty && selectedFilter == .all {
                        ForEach(homeVM.sideBets) { sb in
                            NavigationLink(value: sb) {
                                SideBetCardView(
                                    sideBet: sb,
                                    creatorProfile: homeVM.sideBetProfiles[sb.creatorId],
                                    opponentProfile: homeVM.sideBetProfiles[sb.opponentId]
                                )
                            }
                            .buttonStyle(.scale)
                        }
                        .padding(.horizontal, Spacing.screenH)
                    }

                    // Regular bets
                    ForEach(filteredBets) { bet in
                        NavigationLink(value: bet) {
                            BetCardView(
                                bet: bet,
                                participantProfiles: homeVM.betParticipants[bet.id] ?? [],
                                creatorName: homeVM.betCreators[bet.creatorId]?.username
                            )
                        }
                        .buttonStyle(.scale)
                    }
                    .padding(.horizontal, Spacing.screenH)
                }
            }
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
