import SwiftUI

struct BetCardView: View {
    let bet: Bet
    let participantProfiles: [Profile]
    let creatorName: String?

    init(bet: Bet, participantProfiles: [Profile] = [], creatorName: String? = nil) {
        self.bet = bet
        self.participantProfiles = participantProfiles
        self.creatorName = creatorName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Row 1: Emoji + Title + Status
            HStack(alignment: .top, spacing: 12) {
                Text(bet.emoji)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(Color.bgEmoji)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(bet.title)
                        .font(.cardTitle)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        if let name = creatorName {
                            Text("by \(name)")
                                .font(.cardMeta)
                                .foregroundStyle(Color.textSecondary)
                        }
                        if let deadline = bet.deadline {
                            Text("·")
                                .font(.cardMeta)
                                .foregroundStyle(Color.textMuted)
                            Text(deadline.betDeadlineText)
                                .font(.cardMeta)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }

                Spacer()

                StatusPillView(status: bet.status, deadline: bet.deadline)
            }

            // Row 2: Outcome chips
            FlowLayout(spacing: 6) {
                ForEach(Array(bet.outcomes.enumerated()), id: \.offset) { index, outcome in
                    let chipColor = OutcomeColor.forIndex(index).color
                    let isWinner = bet.winner == outcome

                    HStack(spacing: 4) {
                        Circle()
                            .fill(chipColor)
                            .frame(width: 7, height: 7)
                        Text(outcome)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        if isWinner {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.accentSuccess)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        isWinner ? Color.accentSuccess.opacity(0.12) : chipColor.opacity(0.1)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        isWinner ?
                        Capsule().stroke(Color.accentSuccess.opacity(0.3), lineWidth: 1) : nil
                    )
                }
            }

            // Row 3: Pool + participant avatars
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentSuccess)
                    Text("$\(bet.pool)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentSuccess)
                    Text("pool")
                        .font(.cardMeta)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if !participantProfiles.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(Array(participantProfiles.prefix(5).enumerated()), id: \.element.id) { index, profile in
                            AvatarView(name: profile.username, size: 24, imageURL: profile.avatarUrl)
                                .overlay(Circle().stroke(Color.bgCard, lineWidth: 2))
                                .zIndex(Double(5 - index))
                        }
                        if participantProfiles.count > 5 {
                            Text("+\(participantProfiles.count - 5)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 24, height: 24)
                                .background(Color.bgSurface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.bgCard, lineWidth: 2))
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

// Simple flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
