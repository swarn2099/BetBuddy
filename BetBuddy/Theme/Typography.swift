import SwiftUI

extension Font {
    // Display / headings
    static let heading1 = Font.system(size: 30, weight: .bold, design: .default)
    static let heading2 = Font.system(size: 22, weight: .bold, design: .default)
    static let cardTitle = Font.system(size: 15, weight: .semibold)
    static let cardMeta = Font.system(size: 12, weight: .regular)
    static let body15 = Font.system(size: 15, weight: .regular)
    static let button15 = Font.system(size: 15, weight: .semibold)
    static let label11 = Font.system(size: 11, weight: .semibold)
    static let navLabel = Font.system(size: 10, weight: .medium)

    // Monospace for all dollar amounts
    static let balanceLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
    static let statValue = Font.system(size: 20, weight: .bold, design: .monospaced)
    static let poolAmount = Font.system(size: 14, weight: .bold, design: .monospaced)
    static let chipAmount = Font.system(size: 13, weight: .bold, design: .monospaced)
}
