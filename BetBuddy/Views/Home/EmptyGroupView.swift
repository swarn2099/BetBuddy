import SwiftUI

struct EmptyGroupView: View {
    var onCreateBet: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🎲")
                .font(.system(size: 48))
            Text("No bets yet")
                .font(.heading2)
                .foregroundStyle(Color.textPrimary)
            Text("Tap + to create one")
                .font(.body15)
                .foregroundStyle(Color.textSecondary)
            Button {
                onCreateBet()
            } label: {
                Text("Create Bet")
                    .font(.button15)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [Color.accentPrimary, Color.accentViolet], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
            }
        }
    }
}
