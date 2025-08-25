import SwiftUI

struct MemberVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var selectedMember: Member? = nil
    @State private var showRegister = false
    @State private var showCodePrompt = false
    @State private var generatedCode: String = ""
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
                            sendCode(to: member.phoneNumber)
                            showCodePrompt = true
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
            members = DatabaseManager.shared.fetchUnsyncedMembers()
        }
        .sheet(isPresented: $showRegister, onDismiss: {
            members = DatabaseManager.shared.fetchUnsyncedMembers()
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
        .sheet(isPresented: $showCodePrompt) {
            VStack(spacing: 16) {
                TextField("Enter verification code", text: $inputCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding()
                HStack {
                    Button("Cancel") {
                        showCodePrompt = false
                        inputCode = ""
                    }
                    Spacer()
                    Button("Confirm") {
                        if inputCode == generatedCode {
                            showCodePrompt = false
                            inputCode = ""
                            showRegister = true
                        }
                    }
                    .disabled(inputCode.count != 6)
                }
                .padding(.horizontal)
            }
            .presentationDetents([.medium])
        }
    }

    private func sendCode(to phone: String) {
        generatedCode = "000000"
    }
}

#Preview {
    MemberVerificationView()
}
