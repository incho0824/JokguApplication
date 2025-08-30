import SwiftUI
import FirebaseAuth

struct MemberVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var loggedInUser: String
    @State private var members: [Member] = []
    @State private var selectedMember: Member? = nil
    @State private var showRegister = false
    @State private var verifyingMember: Member? = nil
    @State private var inputCode: String = ""
    @State private var verificationID: String? = nil
    @State private var isSendingCode = false
    @State private var message: String? = nil
    @State private var messageColor: Color = .green

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
                            isSendingCode = true
                            let digits = member.phoneNumber.filter { $0.isNumber }
                            let phone: String
                            if digits.count == 10 {
                                phone = "+1" + digits
                            } else if digits.count == 11 && digits.hasPrefix("1") {
                                phone = "+" + digits
                            } else {
                                isSendingCode = false
                                showMessage("Invalid phone number format", color: .red)
                                return
                            }
                            PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil) { id, error in
                                DispatchQueue.main.async {
                                    isSendingCode = false
                                    if let id = id {
                                        verificationID = id
                                        verifyingMember = member
                                    } else if let error = error {
                                        showMessage(error.localizedDescription, color: .red)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(selectedMember == nil || isSendingCode)
                }
                .padding()
                if let message = message {
                    Text(message)
                        .foregroundColor(messageColor)
                }
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
            RegisterView(isLoggedIn: $isLoggedIn, userPermit: $userPermit, loggedInUser: $loggedInUser) {
                dismiss()
            }
        }
        .sheet(item: $verifyingMember) { member in
            VStack(spacing: 16) {
                TextField("Enter verification code", text: $inputCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding()
                HStack {
                    Button("Cancel") {
                        verifyingMember = nil
                        inputCode = ""
                        verificationID = nil
                    }
                    Spacer()
                    Button("Confirm") {
                        guard let id = verificationID, let member = verifyingMember else { return }
                        let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: inputCode)
                        Auth.auth().signIn(with: credential) { _, error in
                            DispatchQueue.main.async {
                                if error == nil {
                                    Task {
                                        do {
                                            // Check if a member already exists with the same phone number
                                            let existing = try await DatabaseManager.shared.fetchMemberByPhoneNumber(phoneNumber: member.phoneNumber)
                                            let target = existing ?? member

                                            try await DatabaseManager.shared.updateSyncd(id: target.id, syncd: 1)
                                            await DatabaseManager.shared.createTablesIfNeeded(for: target.phoneNumber)

                                            await MainActor.run {
                                                loggedInUser = target.phoneNumber
                                                userPermit = target.permit
                                                isLoggedIn = true
                                                showMessage("Registration Complete", color: .green)
                                                verifyingMember = nil
                                                inputCode = ""
                                                verificationID = nil
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                dismiss()
                                            }
                                        } catch {
                                            await MainActor.run { showMessage(error.localizedDescription, color: .red) }
                                        }
                                    }
                                } else {
                                    showMessage(error?.localizedDescription ?? "Unknown error", color: .red)
                                }
                            }
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
    MemberVerificationView(isLoggedIn: .constant(false), userPermit: .constant(0), loggedInUser: .constant(""))
}

extension MemberVerificationView {
    private func showMessage(_ text: String, color: Color) {
        message = text
        messageColor = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            message = nil
        }
    }
}
