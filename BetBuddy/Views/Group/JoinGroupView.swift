import SwiftUI

struct JoinGroupView: View {
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isJoining = false
    @FocusState private var isFocused: Bool
    var initialCode: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.sectionGap) {
                VStack(spacing: 8) {
                    Text("🔑")
                        .font(.system(size: 64))
                    Text("Join a Group")
                        .font(.heading2)
                        .foregroundStyle(Color.textPrimary)
                    Text("Enter the 6-character invite code")
                        .font(.body15)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 40)

                // Code input styled as boxes
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        let char = index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : ""
                        Text(char)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 44, height: 56)
                            .background(Color.bgInput)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(index < code.count ? Color.accentPrimary : Color.borderPrimary, lineWidth: 1)
                            )
                    }
                }
                .overlay {
                    TextField("", text: $code)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($isFocused)
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.prefix(6)).uppercased().filter { $0.isLetter || $0.isNumber }
                        }
                }
                .onTapGesture { isFocused = true }

                if let error = groupVM.errorMessage {
                    Text(error)
                        .font(.cardMeta)
                        .foregroundStyle(Color.accentDanger)
                }

                Button {
                    Task {
                        isJoining = true
                        await groupVM.joinGroup(inviteCode: code)
                        if groupVM.errorMessage == nil {
                            dismiss()
                        }
                        isJoining = false
                    }
                } label: {
                    Group {
                        if isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Text("Join Group")
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
                    .opacity(code.count == 6 ? 1 : 0.5)
                }
                .disabled(code.count != 6 || isJoining)
                .padding(.horizontal, Spacing.screenH)

                Spacer()
            }
            .background(Color.bgPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .onAppear {
                isFocused = true
                if let initialCode, code.isEmpty {
                    code = initialCode.uppercased()
                }
            }
        }
    }
}
