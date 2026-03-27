import Foundation
import Supabase

final class GroupService {
    private let client = SupabaseManager.client

    func fetchUserGroups(userId: UUID) async throws -> [BetGroup] {
        let memberRows: [GroupMember] = try await client
            .from("group_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        guard !memberRows.isEmpty else { return [] }
        let groupIds = memberRows.map { $0.groupId.uuidString }
        let groups: [BetGroup] = try await client
            .from("groups")
            .select()
            .in("id", values: groupIds)
            .execute()
            .value
        return groups
    }

    func createGroup(name: String, leaderId: UUID) async throws -> BetGroup {
        let inviteCode: String = try await client.rpc("generate_invite_code").execute().value
        let group: BetGroup = try await client
            .from("groups")
            .insert([
                "name": name,
                "invite_code": inviteCode,
                "leader_id": leaderId.uuidString
            ])
            .select()
            .single()
            .execute()
            .value
        return group
    }

    func joinGroup(inviteCode: String, userId: UUID) async throws -> BetGroup {
        let groups: [BetGroup] = try await client
            .from("groups")
            .select()
            .eq("invite_code", value: inviteCode.uppercased())
            .execute()
            .value
        guard let group = groups.first else {
            throw NSError(domain: "BetBuddy", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid invite code"])
        }
        try await client
            .from("group_members")
            .insert([
                "group_id": group.id.uuidString,
                "user_id": userId.uuidString
            ])
            .execute()
        return group
    }

    func fetchGroupMembers(groupId: UUID) async throws -> [Profile] {
        let memberRows: [GroupMember] = try await client
            .from("group_members")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value
        guard !memberRows.isEmpty else { return [] }
        let userIds = memberRows.map { $0.userId.uuidString }
        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .in("id", values: userIds)
            .execute()
            .value
        return profiles
    }

    func leaveGroup(groupId: UUID, userId: UUID) async throws {
        try await client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func deleteGroup(groupId: UUID) async throws {
        try await client
            .from("groups")
            .delete()
            .eq("id", value: groupId.uuidString)
            .execute()
    }

    func removeMember(groupId: UUID, leaderId: UUID, targetId: UUID) async throws {
        try await client.rpc("remove_member", params: [
            "p_group_id": groupId.uuidString,
            "p_leader_id": leaderId.uuidString,
            "p_target_id": targetId.uuidString
        ]).execute()
    }

    func uploadGroupImage(groupId: UUID, imageData: Data) async throws -> String {
        let path = "\(groupId.uuidString.lowercased())/image.jpg"
        try await client.storage.from("group-images").upload(
            path,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let publicURL = try client.storage.from("group-images").getPublicURL(path: path)
        try await client
            .from("groups")
            .update(["image_url": publicURL.absoluteString])
            .eq("id", value: groupId.uuidString)
            .execute()
        return publicURL.absoluteString
    }
}
