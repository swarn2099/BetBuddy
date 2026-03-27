import SwiftUI

// GlassCard modifier is defined in Extensions/View+GlassCard.swift
// Usage: anyView.glassCard()
//
// This file provides a standalone GlassCard container view for convenience.

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .glassCard()
    }
}
