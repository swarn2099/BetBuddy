import SwiftUI

struct StatusPillView: View {
    let status: String
    let deadline: Date?

    private var isPastDeadline: Bool {
        guard let deadline else { return false }
        return deadline <= Date()
    }

    private var displayStatus: DisplayStatus {
        if status == "settled" {
            return .settled
        } else if isPastDeadline {
            return .closed
        } else {
            return .live
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if displayStatus == .live {
                Circle()
                    .fill(displayStatus.color)
                    .frame(width: 6, height: 6)
                    .modifier(PulsingModifier())
            }
            Text(displayStatus.label)
                .font(.label11)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(displayStatus.color.opacity(0.15))
        .foregroundStyle(displayStatus.color)
        .clipShape(Capsule())
    }

    private enum DisplayStatus {
        case live, closed, settled

        var label: String {
            switch self {
            case .live: "Live"
            case .closed: "Closed"
            case .settled: "Settled"
            }
        }

        var color: Color {
            switch self {
            case .live: .accentSuccess
            case .closed: .accentWarning
            case .settled: .accentSettled
            }
        }
    }
}

private struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
