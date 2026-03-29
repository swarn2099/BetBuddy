import SwiftUI
import PhotosUI

struct GroupSettingsView: View {
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(\.dismiss) private var dismiss
    let group: BetGroup
    @State private var showRemoveAlert = false
    @State private var memberToRemove: Profile?
    @State private var showLeaveAlert = false
    @State private var showDeleteGroupAlert = false
    @State private var currentUserId: UUID?
    @State private var editedName: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSavingName = false
    @State private var isSavingImage = false
    @State private var activeToast: ToastType?

    private var isLeader: Bool {
        currentUserId == group.leaderId
    }

    var body: some View {
        List {
            // Group header section (leader only)
            if isLeader {
                Section {
                    // Image picker
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let url = group.imageUrl, let imageURL = URL(string: url) {
                                AsyncImage(url: imageURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    imagePlaceholder
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(alignment: .bottomTrailing) { editBadge }
                            } else {
                                imagePlaceholder
                                    .overlay(alignment: .bottomTrailing) { editBadge }
                            }
                        }
                        Spacer()
                    }

                    // Name field
                    HStack {
                        TextField("Group name", text: $editedName)
                            .font(.button15)
                        if editedName != group.name && !editedName.isEmpty {
                            Button {
                                Task {
                                    isSavingName = true
                                    await groupVM.updateGroupName(groupId: group.id, name: editedName)
                                    isSavingName = false
                                    activeToast = .betSettled // reuse as "success"
                                }
                            } label: {
                                if isSavingName {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Save")
                                        .font(.button15)
                                        .foregroundStyle(Color.accentPrimary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Group")
                }
            }

            // Invite Code
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

            // Members
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

            // Bet History
            Section {
                NavigationLink {
                    BetHistoryView(groupId: group.id)
                } label: {
                    Label("Bet History", systemImage: "clock.arrow.circlepath")
                }
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
            Text("Remove \(member.username)? Their active wagers will be forfeited.")
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
            Text("Permanently delete this group and all its bets?")
        }
        .task {
            currentUserId = await groupVM.currentUserId
            editedName = group.name
            await groupVM.loadMembers(groupId: group.id)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    isSavingImage = true
                    await groupVM.updateGroupImage(groupId: group.id, imageData: data)
                    isSavingImage = false
                }
            }
        }
        .toast($activeToast)
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.bgSurface)
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.textSecondary)
            )
    }

    private var editBadge: some View {
        Image(systemName: "pencil.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.accentPrimary)
            .background(Circle().fill(Color.bgPrimary).padding(-2))
    }
}
