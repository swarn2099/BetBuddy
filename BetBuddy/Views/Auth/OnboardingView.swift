import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var avatarImage: Image?
    @State private var isUsernameAvailable = true
    @State private var isCheckingUsername = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var usernameCheckTask: Task<Void, Never>?

    private let profileService = ProfileService()

    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        && username.count >= 2
        && username.count <= 16
        && isUsernameAvailable
        && !isCheckingUsername
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                VStack(spacing: 8) {
                    Text("Set up your profile")
                        .font(.heading1)
                        .foregroundStyle(Color.textPrimary)
                    Text("This is how your friends will see you")
                        .font(.body15)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 40)

                // Avatar picker
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if let avatarImage {
                        avatarImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.bgSurface)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.textSecondary)
                            )
                    }
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FIRST NAME")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        TextField("First name", text: $firstName)
                            .textContentType(.givenName)
                            .padding()
                            .background(Color.bgInput)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("LAST NAME")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        TextField("Last name", text: $lastName)
                            .textContentType(.familyName)
                            .padding()
                            .background(Color.bgInput)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("USERNAME")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        HStack {
                            TextField("username", text: $username)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: username) { _, newValue in
                                    username = String(newValue.prefix(16)).filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                    checkUsername()
                                }
                            if isCheckingUsername {
                                ProgressView()
                                    .controlSize(.small)
                            } else if !username.isEmpty {
                                Image(systemName: isUsernameAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(isUsernameAvailable ? Color.accentSuccess : Color.accentDanger)
                            }
                        }
                        .padding()
                        .background(Color.bgInput)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                .stroke(isUsernameAvailable || username.isEmpty ? Color.borderPrimary : Color.accentDanger, lineWidth: 1)
                        )
                        if !isUsernameAvailable && !username.isEmpty {
                            Text("Username is taken")
                                .font(.cardMeta)
                                .foregroundStyle(Color.accentDanger)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenH)

                if let error = errorMessage {
                    Text(error)
                        .font(.cardMeta)
                        .foregroundStyle(Color.accentDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.screenH)
                }

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Get Started")
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
                    .opacity(isFormValid ? 1 : 0.5)
                }
                .disabled(!isFormValid || isSaving)
                .padding(.horizontal, Spacing.screenH)

                HStack(spacing: 6) {
                    Text("💰")
                    Text("$1,000 starting balance")
                        .font(.button15)
                        .foregroundStyle(Color.accentSuccess)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color.accentSuccess.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .navigationBarBackButtonHidden()
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    avatarData = data
                    if let uiImage = UIImage(data: data) {
                        avatarImage = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }

    private func checkUsername() {
        usernameCheckTask?.cancel()
        guard username.count >= 2 else {
            isUsernameAvailable = true
            return
        }
        isCheckingUsername = true
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            do {
                let available = try await profileService.checkUsernameAvailable(username)
                if !Task.isCancelled {
                    isUsernameAvailable = available
                    isCheckingUsername = false
                }
            } catch {
                if !Task.isCancelled {
                    isCheckingUsername = false
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await authVM.completeOnboarding(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                username: username,
                avatarData: avatarData
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
