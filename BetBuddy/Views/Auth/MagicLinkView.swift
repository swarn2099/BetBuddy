import SwiftUI

struct MagicLinkView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var showSentView = false
    @State private var showPassword = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0

    var body: some View {
        @Bindable var authVM = authVM

        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            // Floating emoji background
            FloatingEmojisView()

            // Gradient glow behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentPrimary.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(y: -120)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Logo + branding
                VStack(spacing: 16) {
                    Text("🎲")
                        .font(.system(size: 80))
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    VStack(spacing: 6) {
                        Text("BetBuddys")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.textPrimary, Color.textPrimary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("Fake money bets with friends")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: 50)

                // Form
                VStack(spacing: 14) {
                    TextField("Email address", text: $authVM.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                .stroke(Color.borderPrimary, lineWidth: 1)
                        )
                        .onChange(of: authVM.email) { _, newValue in
                            showPassword = newValue.lowercased() == AuthViewModel.testEmail
                        }

                    if showPassword {
                        SecureField("Password", text: $authVM.testPassword)
                            .textContentType(.password)
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )
                    }

                    Button {
                        Task {
                            if showPassword {
                                await authVM.signInTestAccount()
                            } else {
                                await authVM.sendMagicLink()
                                if authVM.errorMessage == nil {
                                    showSentView = true
                                }
                            }
                        }
                    } label: {
                        Group {
                            if authVM.isSendingLink {
                                ProgressView().tint(.white)
                            } else {
                                Text(showPassword ? "Sign In" : "Continue")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color.accentPrimary, Color.accentViolet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                        .shadow(color: Color.accentPrimary.opacity(0.3), radius: 12, y: 6)
                    }
                    .disabled(authVM.isSendingLink || authVM.email.isEmpty || (showPassword && authVM.testPassword.isEmpty))

                    if let error = authVM.errorMessage {
                        Text(error)
                            .font(.cardMeta)
                            .foregroundStyle(Color.accentDanger)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .opacity(contentOpacity)

                Spacer()

                // Footer
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("💰")
                        Text("$1,000 starting balance")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentSuccess)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.accentSuccess.opacity(0.1))
                    .clipShape(Capsule())

                    Text("No real money. Ever.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textMuted)
                        .padding(.top, 4)
                }
                .opacity(contentOpacity)
                .padding(.bottom, 30)
            }
        }
        .navigationDestination(isPresented: $showSentView) {
            MagicLinkSentView()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.2)) {
                contentOpacity = 1.0
            }
        }
    }
}
