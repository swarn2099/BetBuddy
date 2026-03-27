import SwiftUI
import PhotosUI

struct CreateGroupView: View {
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var previewImage: Image?
    @State private var isSaving = false
    @State private var createdGroup: BetGroup?

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.sectionGap) {
                if let group = createdGroup {
                    // Success state
                    VStack(spacing: 16) {
                        Text("🎉")
                            .font(.system(size: 64))
                        Text("Group Created!")
                            .font(.heading2)
                            .foregroundStyle(Color.textPrimary)
                        Text("Share this code with friends")
                            .font(.body15)
                            .foregroundStyle(Color.textSecondary)

                        Text(group.inviteCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.accentPrimary)
                            .tracking(4)
                            .padding()

                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = group.inviteCode
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.button15)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.bgSurface)
                                    .foregroundStyle(Color.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                            .stroke(Color.borderPrimary, lineWidth: 1)
                                    )
                            }

                            ShareLink(item: "Join my BetBuddy group! Code: \(group.inviteCode)") {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.button15)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(colors: [Color.accentPrimary, Color.accentViolet], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                            }
                        }
                        .padding(.horizontal, Spacing.screenH)
                    }
                    .padding(.top, 40)
                } else {
                    // Creation form
                    VStack(spacing: 20) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let previewImage {
                                previewImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.bgSurface)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 24))
                                            .foregroundStyle(Color.textSecondary)
                                    )
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("GROUP NAME")
                                .font(.label11)
                                .foregroundStyle(Color.textLabel)
                                .tracking(0.5)
                            TextField("Enter group name", text: $name)
                                .padding()
                                .background(Color.bgInput)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                        .stroke(Color.borderPrimary, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, Spacing.screenH)

                        if let error = groupVM.errorMessage {
                            Text(error)
                                .font(.cardMeta)
                                .foregroundStyle(Color.accentDanger)
                        }

                        Button {
                            Task {
                                isSaving = true
                                await groupVM.createGroup(name: name, imageData: imageData)
                                if groupVM.errorMessage == nil {
                                    createdGroup = groupVM.selectedGroup
                                }
                                isSaving = false
                            }
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Create Group")
                                        .font(.button15)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color.accentPrimary, Color.accentViolet], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                            .opacity(name.isEmpty ? 0.5 : 1)
                        }
                        .disabled(name.isEmpty || isSaving)
                        .padding(.horizontal, Spacing.screenH)
                    }
                    .padding(.top, 20)
                }

                Spacer()
            }
            .background(Color.bgPrimary)
            .navigationTitle(createdGroup != nil ? "" : "Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                if createdGroup != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = data
                        if let uiImage = UIImage(data: data) {
                            previewImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
        }
    }
}
