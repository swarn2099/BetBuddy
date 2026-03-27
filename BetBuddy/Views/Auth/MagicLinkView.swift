import SwiftUI

struct MagicLinkView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var showSentView = false

    var body: some View {
        @Bindable var authVM = authVM

        VStack(spacing: Spacing.sectionGap) {
            Spacer()

            Text("🎲")
                .font(.system(size: 64))

            VStack(spacing: 8) {
                Text("BetBuddy")
                    .font(.heading1)
                    .foregroundStyle(Color.textPrimary)
                Text("Bet on anything with friends")
                    .font(.body15)
                    .foregroundStyle(Color.textSecondary)
            }

            VStack(spacing: 16) {
                TextField("Email address", text: $authVM.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color.bgInput)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.inputRadius)
                            .stroke(Color.borderPrimary, lineWidth: 1)
                    )

                Button {
                    Task {
                        await authVM.sendMagicLink()
                        if authVM.errorMessage == nil {
                            showSentView = true
                        }
                    }
                } label: {
                    Group {
                        if authVM.isSendingLink {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                                .font(.button15)
                        }
                    }
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
                .disabled(authVM.isSendingLink || authVM.email.isEmpty)

                if let error = authVM.errorMessage {
                    Text(error)
                        .font(.cardMeta)
                        .foregroundStyle(Color.accentDanger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Spacing.screenH)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .navigationDestination(isPresented: $showSentView) {
            MagicLinkSentView()
        }
    }
}
