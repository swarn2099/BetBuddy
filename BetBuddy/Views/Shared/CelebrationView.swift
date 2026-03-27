import SwiftUI

// MARK: - Confetti particle
struct ConfettiView: View {
    let colors: [Color] = [.red, .green, .blue, .orange, .purple, .pink, .yellow, .cyan]
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, size: CGFloat, rotation: Double, delay: Double)] = []
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 0.5)
                    .rotationEffect(.degrees(animate ? p.rotation + 360 : p.rotation))
                    .offset(
                        x: animate ? p.x : 0,
                        y: animate ? p.y : -50
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5).delay(p.delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            particles = (0..<40).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -180...180),
                    y: CGFloat.random(in: 200...500),
                    color: colors.randomElement()!,
                    size: CGFloat.random(in: 6...12),
                    rotation: Double.random(in: 0...360),
                    delay: Double.random(in: 0...0.3)
                )
            }
            animate = true
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Toast overlay
enum ToastType {
    case betPlaced(side: String, amount: Int)
    case betSettled
    case won(amount: Int)
    case lost(amount: Int)

    var icon: String {
        switch self {
        case .betPlaced: "checkmark.circle.fill"
        case .betSettled: "flag.checkered"
        case .won: "trophy.fill"
        case .lost: "arrow.down.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .betPlaced: "Bet Placed!"
        case .betSettled: "Bet Settled!"
        case .won(let amount): "You Won $\(amount)!"
        case .lost(let amount): "You Lost $\(amount)"
        }
    }

    var color: Color {
        switch self {
        case .betPlaced: Color.accentPrimary
        case .betSettled: Color.accentWarning
        case .won: Color.accentSuccess
        case .lost: Color.accentDanger
        }
    }

    var showConfetti: Bool {
        switch self {
        case .won, .betPlaced: true
        default: false
        }
    }
}

struct ToastView: View {
    let type: ToastType
    @State private var show = false

    var body: some View {
        VStack {
            if show {
                HStack(spacing: 12) {
                    Image(systemName: type.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(type.color)
                    Text(type.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(type.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: type.color.opacity(0.2), radius: 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, 60)
        .onAppear {
            withAnimation(.spring(duration: 0.5)) {
                show = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    show = false
                }
            }
        }
    }
}

// MARK: - View modifier for showing toasts
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastType?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let toast {
                    ZStack {
                        if toast.showConfetti {
                            ConfettiView()
                        }
                        ToastView(type: toast)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.toast = nil
                        }
                    }
                }
            }
    }
}

extension View {
    func toast(_ type: Binding<ToastType?>) -> some View {
        modifier(ToastModifier(toast: type))
    }
}
