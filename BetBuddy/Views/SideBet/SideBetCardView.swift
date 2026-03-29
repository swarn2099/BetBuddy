import SwiftUI

struct SideBetCardView: View {
    let sideBet: SideBet
    let creatorProfile: Profile?
    let opponentProfile: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Badge + Status
            HStack {
                HStack(spacing: 4) {
                    Text("🤝")
                        .font(.system(size: 12))
                    Text("Side Bet")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentViolet.opacity(0.15))
                .foregroundStyle(Color.accentViolet)
                .clipShape(Capsule())

                Spacer()

                Text(statusText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusColor)
                    .textCase(.uppercase)
            }

            // Avatars + Title
            HStack(spacing: 12) {
                // Creator avatar
                AvatarView(name: creatorProfile?.username ?? "?", size: 40, imageURL: creatorProfile?.avatarUrl)

                Text("vs")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textMuted)

                // Opponent avatar
                AvatarView(name: opponentProfile?.username ?? "?", size: 40, imageURL: opponentProfile?.avatarUrl)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sideBet.title)
                        .font(.cardTitle)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                    Text("\(creatorProfile?.username ?? "?") vs \(opponentProfile?.username ?? "?")")
                        .font(.cardMeta)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Amount
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentSuccess)
                    Text("$\(sideBet.amount)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentSuccess)
                    Text("each")
                        .font(.cardMeta)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text(sideBet.createdAt.relativeDateText)
                    .font(.cardMeta)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(16)
        .glassCard()
    }

    private var statusText: String {
        switch sideBet.status {
        case "pending": "Pending"
        case "active": "Active"
        case "declaring": "Awaiting Confirm"
        case "settled": "Settled"
        case "cancelled": "Cancelled"
        default: sideBet.status
        }
    }

    private var statusColor: Color {
        switch sideBet.status {
        case "pending": Color.accentWarning
        case "active": Color.accentSuccess
        case "declaring": Color.accentPrimary
        case "settled": Color.accentSettled
        case "cancelled": Color.textMuted
        default: Color.textSecondary
        }
    }
}
