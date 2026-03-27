import Foundation
import SwiftUI

@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isOnboarded = false
    var currentUser: Profile?
    var isLoading = true
    var email = ""
    var errorMessage: String?
    var isSendingLink = false
    var testPassword = ""

    static let testEmail = "swarn2099@gmail.com"
    static let testPasswordValue = "testuser2026"

    var isTestAccount: Bool {
        email.lowercased() == Self.testEmail
    }

    private let authService = AuthService()
    private let profileService = ProfileService()

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        guard let session = await authService.currentSession else {
            isAuthenticated = false
            return
        }

        isAuthenticated = true
        do {
            let profile = try await profileService.fetchProfile(userId: session.user.id)
            currentUser = profile
            isOnboarded = !profile.firstName.isEmpty && !profile.lastName.isEmpty
        } catch {
            isOnboarded = false
        }
    }

    func sendMagicLink() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        isSendingLink = true
        errorMessage = nil
        do {
            try await authService.sendMagicLink(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingLink = false
    }

    func signInTestAccount() async {
        guard isTestAccount, testPassword == Self.testPasswordValue else {
            errorMessage = "Incorrect password"
            return
        }
        isSendingLink = true
        errorMessage = nil
        do {
            // Try sign in first, if fails then sign up
            do {
                try await authService.signInWithPassword(email: email, password: testPassword)
            } catch {
                try await authService.signUpWithPassword(email: email, password: testPassword)
                try await authService.signInWithPassword(email: email, password: testPassword)
            }
            await checkSession()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingLink = false
    }

    func handleDeepLink(url: URL) async {
        do {
            try await authService.handleDeepLink(url: url)
            await checkSession()
        } catch {
            errorMessage = "Failed to verify link: \(error.localizedDescription)"
        }
    }

    func completeOnboarding(firstName: String, lastName: String, username: String, avatarData: Data?) async throws {
        guard let session = await authService.currentSession else { return }
        let userId = session.user.id

        let profile = try await profileService.updateProfile(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            username: username
        )

        currentUser = profile

        if let data = avatarData {
            if let avatarUrl = try? await profileService.uploadAvatar(userId: userId, imageData: data) {
                currentUser?.avatarUrl = avatarUrl
            }
        }

        isOnboarded = true
    }

    func signOut() async {
        try? await authService.signOut()
        isAuthenticated = false
        isOnboarded = false
        currentUser = nil
        email = ""
    }

    func startAuthListener() {
        Task {
            for await event in authService.authStateChanges() {
                switch event {
                case .signedIn:
                    await checkSession()
                case .signedOut:
                    await MainActor.run {
                        isAuthenticated = false
                        isOnboarded = false
                        currentUser = nil
                    }
                default:
                    break
                }
            }
        }
    }
}
