import SwiftUI

struct LoadingView: View {
    var message: String?

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.accentPrimary)
            if let message {
                Text(message)
                    .font(.body15)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }
}
