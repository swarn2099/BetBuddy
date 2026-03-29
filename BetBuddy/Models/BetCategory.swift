import SwiftUI

enum BetCategory: String, CaseIterable, Identifiable {
    case sports = "Sports"
    case foodDrink = "Food & Drink"
    case weather = "Weather"
    case entertainment = "Entertainment"
    case random = "Random"
    case personal = "Personal"
    case workSchool = "Work/School"
    case money = "Money"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sports: "⚽"
        case .foodDrink: "🍕"
        case .weather: "🌧️"
        case .entertainment: "🎬"
        case .random: "🎲"
        case .personal: "💪"
        case .workSchool: "📚"
        case .money: "💰"
        }
    }

    var color: Color {
        switch self {
        case .sports: Color(hex: 0x34C759)
        case .foodDrink: Color(hex: 0xFF9F0A)
        case .weather: Color(hex: 0x007AFF)
        case .entertainment: Color(hex: 0xFF2D55)
        case .random: Color(hex: 0xAF52DE)
        case .personal: Color(hex: 0xFF3B30)
        case .workSchool: Color(hex: 0x5856D6)
        case .money: Color(hex: 0x22C55E)
        }
    }
}
