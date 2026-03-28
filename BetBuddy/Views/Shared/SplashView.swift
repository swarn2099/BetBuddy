import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            FloatingEmojisView()
                .opacity(0.6)

            VStack(spacing: 20) {
                Text("🎲")
                    .font(.system(size: 72))
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("BetBuddys")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Fake money bets with friends")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .opacity(textOpacity)

                ProgressView()
                    .tint(Color.accentPrimary)
                    .padding(.top, 20)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }
        }
    }
}
