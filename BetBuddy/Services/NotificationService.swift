import Foundation
import UserNotifications
import Supabase

struct PushNotificationPayload: Encodable {
    let type: String
    let userIds: [String]
    let title: String
    let body: String
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case type, title, body, metadata
        case userIds = "user_ids"
    }
}

final class NotificationService {
    private let client = SupabaseManager.client

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func sendPushNotification(type: String, userIds: [String], title: String, body: String, metadata: [String: String]) async {
        let payload = PushNotificationPayload(type: type, userIds: userIds, title: title, body: body, metadata: metadata)
        do {
            try await client.functions.invoke("send-push-notification", options: .init(body: payload))
        } catch {
            // Push notification failures are non-fatal
        }
    }
}
