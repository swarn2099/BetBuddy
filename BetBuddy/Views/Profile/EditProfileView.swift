import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = ProfileViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var previewImage: Image?

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let previewImage {
                            previewImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            AvatarView(
                                name: vm.profile?.username ?? "",
                                size: 80,
                                imageURL: vm.profile?.avatarUrl
                            )
                        }
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)

            Section("Name") {
                TextField("First name", text: $vm.editFirstName)
                TextField("Last name", text: $vm.editLastName)
            }

            Section("Username") {
                HStack {
                    TextField("Username", text: $vm.editUsername)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: vm.editUsername) { _, newValue in
                            vm.editUsername = String(newValue.prefix(16)).filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            vm.checkUsername(vm.editUsername)
                        }
                    if vm.isCheckingUsername {
                        ProgressView().controlSize(.small)
                    } else if !vm.editUsername.isEmpty {
                        Image(systemName: vm.isUsernameAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(vm.isUsernameAvailable ? Color.accentSuccess : Color.accentDanger)
                    }
                }
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(Color.accentDanger)
                        .font(.cardMeta)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        try? await vm.saveProfile(avatarData: avatarData)
                        if vm.errorMessage == nil {
                            // Update the auth VM's user
                            if let updated = vm.profile {
                                authVM.currentUser = updated
                            }
                            dismiss()
                        }
                    }
                } label: {
                    if vm.isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Save")
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                .disabled(vm.isSaving || !vm.isUsernameAvailable || vm.editUsername.count < 2)
            }
        }
        .task {
            await vm.loadProfile()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    avatarData = data
                    if let uiImage = UIImage(data: data) {
                        previewImage = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }
}
