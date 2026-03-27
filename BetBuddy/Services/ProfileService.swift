import Foundation
import Supabase

final class ProfileService {
    private let client = SupabaseManager.client

    func fetchProfile(userId: UUID) async throws -> Profile {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    func updateProfile(userId: UUID, firstName: String, lastName: String, username: String) async throws -> Profile {
        try await client
            .from("profiles")
            .update([
                "first_name": firstName,
                "last_name": lastName,
                "username": username,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    func checkUsernameAvailable(_ username: String, excludingUserId: UUID? = nil) async throws -> Bool {
        let query = client
            .from("profiles")
            .select("id", head: true, count: .exact)
            .eq("username", value: username)

        let response: PostgrestResponse<[Profile]>
        if let excludeId = excludingUserId {
            response = try await query.neq("id", value: excludeId.uuidString).execute()
        } else {
            response = try await query.execute()
        }
        return (response.count ?? 0) == 0
    }

    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        try await client.storage.from("avatars").upload(
            path,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
        try await client
            .from("profiles")
            .update(["avatar_url": publicURL.absoluteString, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: userId.uuidString)
            .execute()
        return publicURL.absoluteString
    }

    func updatePushToken(userId: UUID, token: String) async throws {
        try await client
            .from("profiles")
            .update(["push_token": token])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    func deleteProfile(userId: UUID) async throws {
        try await client
            .from("profiles")
            .delete()
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
