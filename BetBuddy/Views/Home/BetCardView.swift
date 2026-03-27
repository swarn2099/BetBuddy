import SwiftUI

struct BetCardView: View {
    let bet: Bet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Emoji + Title + Status
            HStack(spacing: 12) {
                Text(bet.emoji)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(Color.bgEmoji)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(bet.title)
                        .font(.cardTitle)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                StatusPillView(status: bet.status, deadline: bet.deadline)
            }

            // Row 2: Outcome chips
            FlowLayout(spacing: 6) {
                ForEach(Array(bet.outcomes.enumerated()), id: \.offset) { index, outcome in
                    OutcomeChipView(
                        outcome: outcome,
                        index: index,
                        isWinner: bet.winner == outcome
                    )
                }
            }

            // Row 3: Pool + deadline
            HStack {
                BalanceView(amount: bet.pool, font: .poolAmount)
                Text("pool")
                    .font(.cardMeta)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if let deadline = bet.deadline {
                    Text(deadline.betDeadlineText)
                        .font(.cardMeta)
                        .foregroundStyle(Color.textSecondary)
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
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
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
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
