import SwiftUI

struct GroupSelectorSheet: View {
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(\.dismiss) private var dismiss
    @Binding var showCreateGroup: Bool
    @Binding var showJoinGroup: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showCreateGroup = true
                        }
                    } label: {
                        Label("Create Group", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.accentPrimary)
                    }
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showJoinGroup = true
                        }
                    } label: {
                        Label("Join Group", systemImage: "person.badge.plus")
                            .foregroundStyle(Color.accentPrimary)
                    }
                }

                Section("Your Groups") {
                    ForEach(groupVM.groups) { group in
                        Button {
                            Task {
                                await groupVM.selectGroup(group)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(name: group.name, size: 36, imageURL: group.imageUrl)
                                Text(group.name)
                                    .font(.button15)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                if groupVM.selectedGroup?.id == group.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
