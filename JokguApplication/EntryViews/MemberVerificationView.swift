import SwiftUI

struct MemberVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var selectedMember: Member? = nil
    @State private var showRegister = false
    @State private var verifyingMember: Member? = nil
    @State private var inputCode: String = ""

    var body: some View {
        NavigationView {
            VStack {
                List(members, id: \.id) { member in
                    HStack {
                        Text("\(member.lastName) \(member.firstName)")
                        Spacer()
                        Text(member.dob)
                    }
                    .contentShape(Rectangle())
                    .background(selectedMember?.id == member.id ? Color.gray.opacity(0.2) : Color.clear)
                    .onTapGesture {
                        selectedMember = member
                    }
                }
                HStack {
                    Button("New") {
                        selectedMember = nil
                        showRegister = true
                    }
                    Spacer()
                    Button("Verify") {
                        if let member = selectedMember {
                            verifyingMember = member
                        }
                    }
                    .disabled(selectedMember == nil)
                }
                .padding()
            }
            .navigationTitle("Who are you?")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                if let fetched = try? await DatabaseManager.shared.fetchUnsyncedMembers() {
                    await MainActor.run { members = fetched }
                }
            }
        }
        .sheet(isPresented: $showRegister, onDismiss: {
            Task {
                if let fetched = try? await DatabaseManager.shared.fetchUnsyncedMembers() {
                    await MainActor.run { members = fetched }
                }
            }
        }) {
            if let member = selectedMember {
                RegisterView(member: member) {
                    dismiss()
                }
            } else {
                RegisterView() {
                    dismiss()
                }
            }
        }
        .sheet(item: $verifyingMember) { member in
            VStack(spacing: 16) {
                TextField("Enter verification code", text: $inputCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: inputCode) { _, newValue in
                        inputCode = newValue.filter { $0.isLetter || $0.isNumber }.uppercased()
                    }
                    .padding()
                Text("Ask In Cho for your code.\n(SMS Mobile Text Verification is currently disabled because\nIn Cho does not want to pay for the Twilio Account)")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                HStack {
                    Button("Cancel") {
                        verifyingMember = nil
                        inputCode = ""
                    }
                    Spacer()
                    Button("Confirm") {
                        if inputCode.caseInsensitiveCompare(member.username) == .orderedSame {
                            verifyingMember = nil
                            inputCode = ""
                            showRegister = true
                        }
                    }
                    .disabled(inputCode.isEmpty)
                }
                .padding(.horizontal)
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    MemberVerificationView()
}
