import SwiftUI
import UserNotifications

@main
struct BetBuddyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authVM = AuthViewModel()
    @State private var groupVM = GroupViewModel()
    @State private var homeVM = HomeViewModel()
    @State private var pendingInviteCode: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isLoading {
                    SplashView()
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
                // Check for invite link: betbuddys.io/join/{code}
                if url.host == "betbuddys.io" || url.host == "www.betbuddys.io",
                   url.pathComponents.count >= 3,
                   url.pathComponents[1] == "join" {
                    pendingInviteCode = url.pathComponents[2]
                } else {
                    // Magic link callback
                    Task {
                        await authVM.handleDeepLink(url: url)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { pendingInviteCode != nil },
                set: { if !$0 { pendingInviteCode = nil } }
            )) {
                JoinGroupView(initialCode: pendingInviteCode)
            }
            .task {
                authVM.startAuthListener()
                await authVM.checkSession()
                // Request push notification permission after auth
                if authVM.isAuthenticated {
                    await requestPushPermission()
                }
            }
        }
    }

    private func requestPushPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        if granted == true {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

// MARK: - AppDelegate for push token handling
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            let authService = AuthService()
            if let userId = await authService.currentUserId {
                let profileService = ProfileService()
                try? await profileService.updatePushToken(userId: userId, token: token)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Push registration failed: \(error.localizedDescription)")
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // Handle notification tap — could deep link to relevant bet
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
