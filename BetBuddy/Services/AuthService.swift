import Foundation
import Supabase

final class AuthService {
    private let client = SupabaseManager.client

    func sendMagicLink(email: String) async throws {
        try await client.auth.signInWithOTP(email: email, redirectTo: URL(string: "betbuddy://auth/callback"))
    }

    func signInWithPassword(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUpWithPassword(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    func handleDeepLink(url: URL) async throws {
        try await client.auth.session(from: url)
    }

    var currentSession: Session? {
        get async {
            try? await client.auth.session
        }
    }

    var currentUserId: UUID? {
        get async {
            let session = await currentSession
            return session?.user.id
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func authStateChanges() -> AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, _) in client.auth.authStateChanges {
                    continuation.yield(event)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
