import SwiftUI

struct MemberVerificationView: View {
    @Environment(\.dismiss) var dismiss
    struct RegistrationSelection: Identifiable {
        let id = UUID()
        let member: Member?
    }

    @State private var members: [Member] = []
    @State private var selectedMember: Member? = nil
    @State private var registrationSelection: RegistrationSelection? = nil
    @State private var codeSelection: Member? = nil
    @State private var generatedCode: String = ""
    @State private var inputCode: String = ""
    @State private var codeExpiration: Date? = nil

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
                        registrationSelection = RegistrationSelection(member: nil)
                    }
                    Spacer()
                    Button("Verify") {
                        if let member = selectedMember {
                            sendCode(to: member.phoneNumber)
                            codeSelection = member
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
        .sheet(item: $registrationSelection, onDismiss: {
            members = DatabaseManager.shared.fetchUnsyncedMembers()
        }) { selection in
            if let member = selection.member {
                RegisterView(member: member) {
                    dismiss()
                }
            } else {
                RegisterView() {
                    dismiss()
                }
            }
        }
        .sheet(item: $codeSelection) { member in
            VStack(spacing: 16) {
                TextField("Enter verification code", text: $inputCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding()
                    .onChange(of: inputCode) { _, newValue in
                        inputCode = newValue.filter { $0.isNumber }
                        if inputCode.count > 6 { inputCode = String(inputCode.prefix(6)) }
                    }
                HStack {
                    Button("Cancel") {
                        codeSelection = nil
                        inputCode = ""
                    }
                    Spacer()
                    Button("Confirm") {
                        if inputCode == generatedCode,
                           let expiry = codeExpiration,
                           Date() <= expiry {
                            codeSelection = nil
                            inputCode = ""
                            registrationSelection = RegistrationSelection(member: member)
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
        generatedCode = String(format: "%06d", Int.random(in: 0...999_999))
        codeExpiration = Date().addingTimeInterval(300)
        SMSService.shared.sendSMS(to: phone, message: "Your verification code is \(generatedCode)")
    }
}

#Preview {
    MemberVerificationView()
}
