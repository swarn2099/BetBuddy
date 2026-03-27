import SwiftUI
import PhotosUI

struct CreateBetView: View {
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CreateBetViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var createdBetId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    // Group selector (if multiple groups)
                    if groupVM.groups.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GROUP")
                                .font(.label11)
                                .foregroundStyle(Color.textLabel)
                                .tracking(0.5)
                            Picker("Group", selection: $vm.selectedGroupId) {
                                ForEach(groupVM.groups) { group in
                                    Text(group.name).tag(Optional(group.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.accentPrimary)
                        }
                    }

                    // Cover image picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("COVER IMAGE")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let previewImage {
                                previewImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white)
                                            .padding(8)
                                    }
                            } else {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 20))
                                    Text("Add a photo (optional)")
                                        .font(.button15)
                                }
                                .foregroundStyle(Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(Color.bgSurface)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.cardRadius)
                                        .stroke(Color.borderPrimary, style: StrokeStyle(lineWidth: 1, dash: [6]))
                                )
                            }
                        }
                    }

                    // Emoji picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EMOJI")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                            ForEach(CreateBetViewModel.emojiOptions, id: \.self) { emoji in
                                Button {
                                    vm.emoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 44, height: 44)
                                        .background(vm.emoji == emoji ? Color.accentPrimary.opacity(0.2) : Color.bgEmoji)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            vm.emoji == emoji ?
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.accentPrimary, lineWidth: 2) : nil
                                        )
                                }
                            }
                        }
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WHAT'S THE BET?")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        TextField("e.g. Who wins the game tonight?", text: $vm.title)
                            .font(.body15)
                            .padding()
                            .background(Color.bgInput)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )
                        Text("\(vm.title.count)/200")
                            .font(.cardMeta)
                            .foregroundStyle(Color.textMuted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // Outcomes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OUTCOMES")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)

                        ForEach(Array(vm.outcomes.enumerated()), id: \.offset) { index, _ in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(OutcomeColor.forIndex(index).color)
                                    .frame(width: 10, height: 10)
                                TextField("Outcome \(index + 1)", text: $vm.outcomes[index])
                                    .font(.body15)
                                if vm.outcomes.count > 2 {
                                    Button {
                                        vm.removeOutcome(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(Color.accentDanger)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.bgInput)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )
                        }

                        if vm.outcomes.count < 8 {
                            Button {
                                vm.addOutcome()
                            } label: {
                                Label("Add Outcome", systemImage: "plus.circle")
                                    .font(.button15)
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }

                    // Creator betting toggle
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $vm.creatorCanBet) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CREATOR CAN BET")
                                    .font(.label11)
                                    .foregroundStyle(Color.textLabel)
                                    .tracking(0.5)
                                Text("Turn off to prevent insider trading")
                                    .font(.cardMeta)
                                    .foregroundStyle(Color.textMuted)
                            }
                        }
                        .tint(Color.accentPrimary)
                    }

                    // Deadline
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $vm.hasDeadline) {
                            Text("SET DEADLINE")
                                .font(.label11)
                                .foregroundStyle(Color.textLabel)
                                .tracking(0.5)
                        }
                        .tint(Color.accentPrimary)

                        if vm.hasDeadline {
                            DatePicker("Deadline", selection: $vm.deadline, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .tint(Color.accentPrimary)
                        }
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.cardMeta)
                            .foregroundStyle(Color.accentDanger)
                    }

                    // Create button
                    Button {
                        Task {
                            if let bet = await vm.createBet() {
                                createdBetId = bet.id
                            }
                        }
                    } label: {
                        Group {
                            if vm.isCreating {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Bet")
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
                        .opacity(vm.isValid ? 1 : 0.5)
                    }
                    .disabled(!vm.isValid || vm.isCreating)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.topPadding)
                .padding(.bottom, 40)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Create Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .onAppear {
                vm.selectedGroupId = groupVM.selectedGroup?.id
            }
            .navigationDestination(item: $createdBetId) { betId in
                BetDetailView(betId: betId)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        vm.imageData = data
                        if let uiImage = UIImage(data: data) {
                            previewImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
        }
    }
}
