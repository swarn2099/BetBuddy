import SwiftUI

enum OutcomeColor: CaseIterable {
    case green, red, blue, orange, purple, cyan, pink, indigo

    var color: Color {
        switch self {
        case .green: Color(hex: 0x34C759)
        case .red: Color(hex: 0xFF3B30)
        case .blue: Color(hex: 0x007AFF)
        case .orange: Color(hex: 0xFF9F0A)
        case .purple: Color(hex: 0xAF52DE)
        case .cyan: Color(hex: 0x5AC8FA)
        case .pink: Color(hex: 0xFF2D55)
        case .indigo: Color(hex: 0x5856D6)
        }
    }

    static func forIndex(_ i: Int) -> OutcomeColor {
        allCases[i % allCases.count]
    }
}

struct OutcomeChipView: View {
    let outcome: String
    let index: Int
    let amount: Int?
    let isWinner: Bool

    init(outcome: String, index: Int, amount: Int? = nil, isWinner: Bool = false) {
        self.outcome = outcome
        self.index = index
        self.amount = amount
        self.isWinner = isWinner
    }

    private var chipColor: Color {
        OutcomeColor.forIndex(index).color
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(chipColor)
                .frame(width: 8, height: 8)
            Text(outcome)
                .font(.cardMeta)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            if let amount {
                Text("$\(amount)")
                    .font(.chipAmount)
                    .foregroundStyle(chipColor)
            }
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentSuccess)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(chipColor.opacity(0.1))
        .clipShape(Capsule())
    }
}
