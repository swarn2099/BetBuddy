import Foundation
import Supabase
import Realtime

final class RealtimeService {
    private let client = SupabaseManager.client
    private var betChannel: RealtimeChannelV2?

    func subscribeToBets(groupId: UUID, onInsert: @escaping (Bet) -> Void, onUpdate: @escaping (Bet) -> Void, onDelete: @escaping (UUID) -> Void) async {
        await unsubscribeFromBets()

        let channel = client.realtimeV2.channel("bets:\(groupId.uuidString)")

        let insertions = channel.postgresChange(InsertAction.self, schema: "public", table: "bets", filter: .eq("group_id", value: groupId.uuidString))
        let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "bets", filter: .eq("group_id", value: groupId.uuidString))
        let deletions = channel.postgresChange(DeleteAction.self, schema: "public", table: "bets", filter: .eq("group_id", value: groupId.uuidString))

        await channel.subscribe()
        betChannel = channel

        Task {
            for await insertion in insertions {
                if let bet: Bet = try? insertion.decodeRecord(decoder: JSONDecoder.supabaseDecoder) {
                    await MainActor.run { onInsert(bet) }
                }
            }
        }
        Task {
            for await update in updates {
                if let bet: Bet = try? update.decodeRecord(decoder: JSONDecoder.supabaseDecoder) {
                    await MainActor.run { onUpdate(bet) }
                }
            }
        }
        Task {
            for await deletion in deletions {
                if let idString = deletion.oldRecord["id"]?.value as? String,
                   let id = UUID(uuidString: idString) {
                    await MainActor.run { onDelete(id) }
                }
            }
        }
    }

    func unsubscribeFromBets() async {
        if let channel = betChannel {
            await channel.unsubscribe()
            betChannel = nil
        }
    }
}

extension JSONDecoder {
    static let supabaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatters: [DateFormatter] = {
                let f1 = DateFormatter()
                f1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                f1.locale = Locale(identifier: "en_US_POSIX")
                let f2 = DateFormatter()
                f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                f2.locale = Locale(identifier: "en_US_POSIX")
                return [f1, f2]
            }()
            for formatter in formatters {
                if let date = formatter.date(from: string) { return date }
            }
            if let date = ISO8601DateFormatter().date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        return decoder
    }()
}
