import SwiftUI

struct BalanceView: View {
    let amount: Int
    let font: Font
    let showSign: Bool

    init(amount: Int, font: Font = .balanceLarge, showSign: Bool = false) {
        self.amount = amount
        self.font = font
        self.showSign = showSign
    }

    private var color: Color {
        if showSign {
            return amount >= 0 ? .accentSuccess : .accentDanger
        }
        return amount >= 1000 ? .accentSuccess : .accentDanger
    }

    private var text: String {
        if showSign && amount > 0 {
            return "+$\(amount)"
        } else if showSign && amount < 0 {
            return "-$\(abs(amount))"
        }
        return "$\(amount)"
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
    }
}
