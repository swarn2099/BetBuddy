import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GroupViewModel.self) private var groupVM
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let user = authVM.currentUser {
                    VStack(spacing: Spacing.sectionGap) {
                        // Avatar + name
                        VStack(spacing: 12) {
                            NavigationLink {
                                EditProfileView()
                            } label: {
                                AvatarView(name: user.username, size: 56, imageURL: user.avatarUrl)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.accentPrimary)
                                            .background(Circle().fill(Color.bgPrimary).padding(-2))
                                    }
                            }
                            Text("@\(user.username)")
                                .font(.button15)
                                .foregroundStyle(Color.textPrimary)
                            Text("\(user.firstName) \(user.lastName)")
                                .font(.body15)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.top, 20)

                        // Balance card
                        VStack(spacing: 8) {
                            Text("BALANCE")
                                .font(.label11)
                                .foregroundStyle(Color.textLabel)
                                .tracking(0.5)
                            BalanceView(amount: user.balance)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal, Spacing.screenH)

                        // Stats grid
                        HStack(spacing: Spacing.cardGap) {
                            statCard(label: "TOTAL WON", amount: user.totalWon, color: Color.accentSuccess)
                            statCard(label: "TOTAL LOST", amount: user.totalLost, color: Color.accentDanger)
                        }
                        .padding(.horizontal, Spacing.screenH)

                        // Groups
                        VStack(alignment: .leading, spacing: 12) {
                            Text("YOUR GROUPS")
                                .font(.label11)
                                .foregroundStyle(Color.textLabel)
                                .tracking(0.5)
                                .padding(.horizontal, Spacing.screenH)

                            ForEach(groupVM.groups) { group in
                                HStack(spacing: 12) {
                                    AvatarView(name: group.name, size: 36, imageURL: group.imageUrl)
                                    Text(group.name)
                                        .font(.button15)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    if group.leaderId == user.id {
                                        Text("Leader")
                                            .font(.label11)
                                            .foregroundStyle(Color.accentWarning)
                                            .textCase(.uppercase)
                                    }
                                }
                                .padding(12)
                                .glassCard()
                            }
                            .padding(.horizontal, Spacing.screenH)
                        }

                        // Sign out
                        Button(role: .destructive) {
                            showSignOutAlert = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.button15)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(Color.accentDanger)
                        }
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 40)
                    }
                } else {
                    LoadingView()
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await authVM.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func statCard(label: String, amount: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.label11)
                .foregroundStyle(Color.textLabel)
                .tracking(0.5)
            Text("$\(amount)")
                .font(.statValue)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard()
    }
}
