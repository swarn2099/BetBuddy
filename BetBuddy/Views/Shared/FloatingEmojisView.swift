import SwiftUI

struct FloatingEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
}

struct FloatingEmojisView: View {
    @State private var animate = false

    private let emojis: [FloatingEmoji] = {
        let options = ["🎲", "🏀", "🌮", "💰", "🎯", "😂", "🍕", "☕", "🌧️", "🔥", "🎬", "💪"]
        return (0..<14).map { i in
            FloatingEmoji(
                emoji: options[i % options.count],
                x: CGFloat.random(in: 0.02...0.95),
                y: CGFloat.random(in: 0.05...0.9),
                size: CGFloat.random(in: 22...38),
                delay: Double.random(in: 0...5),
                duration: Double.random(in: 8...15)
            )
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(emojis) { item in
                Text(item.emoji)
                    .font(.system(size: item.size))
                    .opacity(0.08)
                    .position(
                        x: geo.size.width * item.x,
                        y: geo.size.height * item.y + (animate ? -20 : 20)
                    )
                    .animation(
                        .easeInOut(duration: item.duration)
                        .repeatForever(autoreverses: true)
                        .delay(item.delay),
                        value: animate
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
