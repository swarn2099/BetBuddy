import SwiftUI

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(Color.borderPrimary, lineWidth: 1)
            )
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 2, y: 1)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
