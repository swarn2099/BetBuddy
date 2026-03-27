import SwiftUI

struct GroupSettingsView: View {
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(\.dismiss) private var dismiss
    let group: BetGroup
    @State private var showRemoveAlert = false
    @State private var memberToRemove: Profile?
    @State private var showLeaveAlert = false
    @State private var showDeleteGroupAlert = false
    @State private var currentUserId: UUID?

    private var isLeader: Bool {
        currentUserId == group.leaderId
    }

    var body: some View {
        List {
            // Invite Code Section
            Section {
                VStack(spacing: 12) {
                    Text(group.inviteCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentPrimary)
                        .tracking(4)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = group.inviteCode
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.cardMeta)
                        }

                        ShareLink(item: "Join my BetBuddy group! Code: \(group.inviteCode)") {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.cardMeta)
                        }
                    }
                }
            } header: {
                Text("Invite Code")
            }

            // Members Section
            Section {
                ForEach(groupVM.members) { member in
                    HStack(spacing: 12) {
                        AvatarView(name: member.username, size: 36, imageURL: member.avatarUrl)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.username)
                                .font(.button15)
                                .foregroundStyle(Color.textPrimary)
                            if member.id == group.leaderId {
                                Text("Leader")
                                    .font(.label11)
                                    .foregroundStyle(Color.accentWarning)
                                    .textCase(.uppercase)
                            }
                        }
                        Spacer()
                        BalanceView(amount: member.balance, font: .poolAmount)
                    }
                    .swipeActions(edge: .trailing) {
                        if isLeader && member.id != group.leaderId {
                            Button(role: .destructive) {
                                memberToRemove = member
                                showRemoveAlert = true
                            } label: {
                                Label("Remove", systemImage: "person.crop.circle.badge.minus")
                            }
                        }
                    }
                }
            } header: {
                Text("Members (\(groupVM.members.count))")
            }

            // Actions
            Section {
                if !isLeader {
                    Button(role: .destructive) {
                        showLeaveAlert = true
                    } label: {
                        Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                if isLeader {
                    Button(role: .destructive) {
                        showDeleteGroupAlert = true
                    } label: {
                        Label("Delete Group", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove Member", isPresented: $showRemoveAlert, presenting: memberToRemove) { member in
            Button("Remove", role: .destructive) {
                Task { await groupVM.removeMember(groupId: group.id, targetId: member.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { member in
            Text("Remove \(member.username) from the group? Their active wagers will be forfeited.")
        }
        .alert("Leave Group", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) {
                Task {
                    await groupVM.leaveGroup(groupId: group.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to leave this group?")
        }
        .alert("Delete Group", isPresented: $showDeleteGroupAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await groupVM.deleteGroup(groupId: group.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Permanently delete this group and all its bets? This cannot be undone.")
        }
        .task {
            currentUserId = await groupVM.currentUserId
            await groupVM.loadMembers(groupId: group.id)
        }
    }
}
