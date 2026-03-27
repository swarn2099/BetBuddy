import SwiftUI

@main
struct BetBuddyApp: App {
    @State private var authVM = AuthViewModel()
    @State private var groupVM = GroupViewModel()
    @State private var homeVM = HomeViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isLoading {
                    LoadingView(message: "Loading...")
                } else if !authVM.isAuthenticated {
                    NavigationStack {
                        MagicLinkView()
                    }
                } else if !authVM.isOnboarded {
                    NavigationStack {
                        OnboardingView()
                    }
                } else {
                    MainTabView()
                }
            }
            .environment(authVM)
            .environment(groupVM)
            .environment(homeVM)
            .onOpenURL { url in
                Task {
                    await authVM.handleDeepLink(url: url)
                }
            }
            .task {
                authVM.startAuthListener()
                await authVM.checkSession()
            }
        }
    }
}

struct MainTabView: View {
    @Environment(GroupViewModel.self) private var groupVM
    @State private var selectedTab = 0
    @State private var showCreateBet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            Color.clear
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
        .tint(Color.accentPrimary)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 1 {
                if !groupVM.groups.isEmpty {
                    showCreateBet = true
                }
                selectedTab = 0
            }
        }
        .fullScreenCover(isPresented: $showCreateBet) {
            CreateBetView()
        }
    }
}
