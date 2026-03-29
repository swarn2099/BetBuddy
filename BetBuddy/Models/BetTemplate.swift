import Foundation

enum BetTemplate: String, CaseIterable, Identifiable {
    case coinFlip = "Coin Flip"
    case yesOrNo = "Yes or No"
    case overUnder = "Over/Under"
    case winLoseDraw = "Win/Lose/Draw"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .coinFlip: "🪙"
        case .yesOrNo: "🤔"
        case .overUnder: "📊"
        case .winLoseDraw: "🏆"
        }
    }

    var outcomes: [String] {
        switch self {
        case .coinFlip: ["Heads", "Tails"]
        case .yesOrNo: ["Yes", "No"]
        case .overUnder: ["Over", "Under"]
        case .winLoseDraw: ["Win", "Lose", "Draw"]
        }
    }
}
