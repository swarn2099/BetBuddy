import Foundation

@Observable
final class GroupViewModel {
    var groups: [BetGroup] = []
    var selectedGroup: BetGroup?
    var members: [Profile] = []
    var isLoading = false
    var errorMessage: String?

    private let groupService = GroupService()
    private let authService = AuthService()

    var currentUserId: UUID? {
        get async { await authService.currentUserId }
    }

    func loadGroups() async {
        guard let userId = await authService.currentUserId else { return }
        isLoading = true
        do {
            groups = try await groupService.fetchUserGroups(userId: userId)
            if selectedGroup == nil {
                selectedGroup = groups.first
            }
            if let selected = selectedGroup {
                await loadMembers(groupId: selected.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMembers(groupId: UUID) async {
        do {
            members = try await groupService.fetchGroupMembers(groupId: groupId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createGroup(name: String, imageData: Data?) async {
        guard let userId = await authService.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        do {
            var group = try await groupService.createGroup(name: name, leaderId: userId)
            if let data = imageData {
                let url = try await groupService.uploadGroupImage(groupId: group.id, imageData: data)
                group.imageUrl = url
            }
            groups.append(group)
            selectedGroup = group
            await loadMembers(groupId: group.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func joinGroup(inviteCode: String) async {
        guard let userId = await authService.currentUserId else { return }
        isLoading = true
        errorMessage = nil
        do {
            let group = try await groupService.joinGroup(inviteCode: inviteCode, userId: userId)
            if !groups.contains(where: { $0.id == group.id }) {
                groups.append(group)
            }
            selectedGroup = group
            await loadMembers(groupId: group.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func leaveGroup(groupId: UUID) async {
        guard let userId = await authService.currentUserId else { return }
        do {
            try await groupService.leaveGroup(groupId: groupId, userId: userId)
            groups.removeAll { $0.id == groupId }
            if selectedGroup?.id == groupId {
                selectedGroup = groups.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeMember(groupId: UUID, targetId: UUID) async {
        guard let userId = await authService.currentUserId else { return }
        do {
            try await groupService.removeMember(groupId: groupId, leaderId: userId, targetId: targetId)
            members.removeAll { $0.id == targetId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectGroup(_ group: BetGroup) async {
        selectedGroup = group
        await loadMembers(groupId: group.id)
    }
}
