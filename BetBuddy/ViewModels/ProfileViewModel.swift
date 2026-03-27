import Foundation

@Observable
final class ProfileViewModel {
    var profile: Profile?
    var isLoading = false
    var errorMessage: String?
    var isSaving = false

    // Edit fields
    var editFirstName = ""
    var editLastName = ""
    var editUsername = ""
    var isUsernameAvailable = true
    var isCheckingUsername = false

    private let profileService = ProfileService()
    private let authService = AuthService()
    private var usernameCheckTask: Task<Void, Never>?

    func loadProfile() async {
        guard let userId = await authService.currentUserId else { return }
        isLoading = true
        do {
            profile = try await profileService.fetchProfile(userId: userId)
            if let p = profile {
                editFirstName = p.firstName
                editLastName = p.lastName
                editUsername = p.username
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func checkUsername(_ username: String) {
        usernameCheckTask?.cancel()
        guard username.count >= 2 else {
            isUsernameAvailable = true
            return
        }
        isCheckingUsername = true
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            do {
                let available = try await profileService.checkUsernameAvailable(username, excludingUserId: profile?.id)
                if !Task.isCancelled {
                    isUsernameAvailable = available
                    isCheckingUsername = false
                }
            } catch {
                if !Task.isCancelled {
                    isCheckingUsername = false
                }
            }
        }
    }

    func saveProfile(avatarData: Data?) async throws {
        guard let userId = profile?.id else { return }
        isSaving = true
        errorMessage = nil
        do {
            var updated = try await profileService.updateProfile(
                userId: userId,
                firstName: editFirstName.trimmingCharacters(in: .whitespaces),
                lastName: editLastName.trimmingCharacters(in: .whitespaces),
                username: editUsername
            )
            if let data = avatarData {
                let url = try await profileService.uploadAvatar(userId: userId, imageData: data)
                updated.avatarUrl = url
            }
            profile = updated
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
