import SwiftUI
import PhotosUI

struct CreateBetView: View {
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CreateBetViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var createdBetId: UUID?
    @State private var showGroupPicker = false

    private var creatableGroups: [BetGroup] {
        let userId = authVM.currentUser?.id
        return groupVM.groups.filter { group in
            if group.isGlobal {
                guard let userId else { return false }
                return group.adminIds?.contains(userId) == true || group.leaderId == userId
            }
            return true
        }
    }

    private var selectedGroupName: String {
        creatableGroups.first(where: { $0.id == vm.selectedGroupId })?.name ?? "Select Group"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {

                    // 1. Group selector (home-screen style)
                    if creatableGroups.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GROUP")
                                .font(.label11)
                                .foregroundStyle(Color.textLabel)
                                .tracking(0.5)
                            Button {
                                showGroupPicker = true
                            } label: {
                                HStack(spacing: 10) {
                                    if let group = creatableGroups.first(where: { $0.id == vm.selectedGroupId }) {
                                        AvatarView(name: group.name, size: 32, imageURL: group.imageUrl)
                                        Text(group.name)
                                            .font(.button15)
                                            .foregroundStyle(Color.textPrimary)
                                    } else {
                                        Text("Select Group")
                                            .font(.button15)
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .padding(14)
                                .background(Color.bgInput)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Spacing.inputRadius)
                                        .stroke(Color.borderPrimary, lineWidth: 1)
                                )
                            }
                        }
                    }

                    // Quick Templates
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QUICK BET")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(BetTemplate.allCases) { template in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            vm.applyTemplate(template)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(template.emoji)
                                                .font(.system(size: 16))
                                            Text(template.rawValue)
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(vm.selectedTemplate == template ? Color.accentPrimary : Color.bgSurface)
                                        .foregroundStyle(vm.selectedTemplate == template ? .white : Color.textSecondary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            vm.selectedTemplate != template ?
                                            Capsule().stroke(Color.borderPrimary, lineWidth: 1) : nil
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // 2. Title
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

                    // 3. Outcomes
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

                    // Category picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CATEGORY")
                            .font(.label11)
                            .foregroundStyle(Color.textLabel)
                            .tracking(0.5)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(BetCategory.allCases) { cat in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            vm.selectedCategory = vm.selectedCategory == cat ? nil : cat
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(cat.icon)
                                                .font(.system(size: 14))
                                            Text(cat.rawValue)
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(vm.selectedCategory == cat ? cat.color.opacity(0.2) : Color.bgSurface)
                                        .foregroundStyle(vm.selectedCategory == cat ? cat.color : Color.textSecondary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            vm.selectedCategory != cat ?
                                            Capsule().stroke(Color.borderPrimary, lineWidth: 1) : nil
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // 4. Emoji picker
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

                    // 5. Cover image
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

                    // 6. Creator can bet toggle
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

                    // 7. Deadline
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
                if let current = groupVM.selectedGroup, creatableGroups.contains(where: { $0.id == current.id }) {
                    vm.selectedGroupId = current.id
                } else {
                    vm.selectedGroupId = creatableGroups.first?.id
                }
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
            .sheet(isPresented: $showGroupPicker) {
                NavigationStack {
                    List {
                        ForEach(creatableGroups) { group in
                            Button {
                                vm.selectedGroupId = group.id
                                showGroupPicker = false
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(name: group.name, size: 36, imageURL: group.imageUrl)
                                    Text(group.name)
                                        .font(.button15)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    if vm.selectedGroupId == group.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentPrimary)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Select Group")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showGroupPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
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
