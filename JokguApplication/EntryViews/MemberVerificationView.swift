import SwiftUI
import FirebaseAuth

struct MemberVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var selectedMember: Member? = nil
    @State private var showRegister = false
    @State private var verifyingMember: Member? = nil
    @State private var inputCode: String = ""
    @State private var verificationID: String? = nil
    @State private var isSendingCode = false
    @State private var errorMessage: String? = nil

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
                            let phone = digits.hasPrefix("1") ? "+" + digits : "+1" + digits
                            Task {
                                do {
                                    let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil)
                                    await MainActor.run {
                                        verificationID = id
                                        verifyingMember = member
                                        isSendingCode = false
                                    }
                                } catch {
                                    await MainActor.run {
                                        errorMessage = error.localizedDescription
                                        isSendingCode = false
                                    }
                                }
                            }
                        }
                    }
                    .disabled(selectedMember == nil || isSendingCode)
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
                        guard let id = verificationID else { return }
                        let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: inputCode)
                        Auth.auth().signIn(with: credential) { _, error in
                            DispatchQueue.main.async {
                                if error == nil {
                                    verifyingMember = nil
                                    inputCode = ""
                                    verificationID = nil
                                    showRegister = true
                                    try? Auth.auth().signOut()
                                } else {
                                    errorMessage = error?.localizedDescription
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
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { }
        }
    }
}

#Preview {
    MemberVerificationView()
}
