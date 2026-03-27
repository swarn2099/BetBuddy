import SwiftUI

struct MagicLinkSentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var resendCountdown = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: Spacing.sectionGap) {
            Spacer()

            VStack(spacing: 16) {
                Text("✉️")
                    .font(.system(size: 64))
                Text("Check your email")
                    .font(.heading2)
                    .foregroundStyle(Color.textPrimary)
                Text("We sent a magic link to")
                    .font(.body15)
                    .foregroundStyle(Color.textSecondary)
                Text(authVM.email)
                    .font(.button15)
                    .foregroundStyle(Color.accentPrimary)
            }

            VStack(spacing: 12) {
                Button {
                    if let url = URL(string: "message://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Mail")
                        .font(.button15)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.accentPrimary, Color.accentViolet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                }

                Button {
                    Task {
                        await authVM.sendMagicLink()
                        startResendTimer()
                    }
                } label: {
                    Text(resendCountdown > 0 ? "Resend in \(resendCountdown)s" : "Resend link")
                        .font(.button15)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.bgSurface)
                        .foregroundStyle(resendCountdown > 0 ? Color.textMuted : Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                .stroke(Color.borderPrimary, lineWidth: 1)
                        )
                }
                .disabled(resendCountdown > 0)
            }
            .padding(.horizontal, Spacing.screenH)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .navigationBarBackButtonHidden(false)
        .onDisappear { timer?.invalidate() }
    }

    private func startResendTimer() {
        resendCountdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}
