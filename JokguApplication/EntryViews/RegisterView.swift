import SwiftUI
import FirebaseAuth

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var loggedInUser: String
    var onComplete: (() -> Void)? = nil
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var dob: Date? = nil
    @State private var message: String? = nil
    @State private var messageColor: Color = .red
    @State private var verificationID: String? = nil
    @State private var smsCode: String = ""
    @State private var isSendingCode = false

    var body: some View {
        VStack(spacing: 16) {
            TextField("First Name", text: $firstName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            TextField("Last Name", text: $lastName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            TextField("Phone Number", text: $phoneNumber)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.phonePad)
                .padding(.horizontal)
                .onChange(of: phoneNumber) { _, newValue in
                    phoneNumber = formatPhoneNumber(newValue)
                }

            DatePicker("Date of Birth", selection: Binding(
                get: { dob ?? Date() },
                set: { dob = $0 }
            ), displayedComponents: .date)
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "en_US"))
                .padding(.horizontal)

            if let message = message {
                Text(message)
                    .foregroundColor(messageColor)
            }

            HStack {
                Button("Back") {
                    dismiss()
                }
                Spacer()
                Button("Register") {
                    let digits = phoneNumber.filter { $0.isNumber }
                    let phone: String
                    if digits.count == 10 {
                        phone = "+1" + digits
                    } else if digits.count == 11 {
                        phone = "+" + digits
                    } else {
                        showMessage("Phone number must be 10 or 11 digits", color: .red)
                        return
                    }
                    isSendingCode = true
                    PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil) { id, error in
                        DispatchQueue.main.async {
                            isSendingCode = false
                            if let id = id {
                                verificationID = id
                            } else if let error = error {
                                showMessage(error.localizedDescription, color: .red)
                            }
                        }
                    }
                }
                .disabled(isSendingCode)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .padding()
        .sheet(isPresented: Binding(get: { verificationID != nil }, set: { if !$0 { verificationID = nil } })) {
            VStack(spacing: 16) {
                TextField("Enter verification code", text: $smsCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding()
                HStack {
                    Button("Cancel") {
                        verificationID = nil
                        smsCode = ""
                    }
                    Spacer()
                    Button("Confirm") {
                        guard let id = verificationID else { return }
                        let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: smsCode)
                        Auth.auth().signIn(with: credential) { _, error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    showMessage(error.localizedDescription, color: .red)
                                } else {
                                    Task {
                                        await registerAfterVerification()
                                    }
                                }
                                verificationID = nil
                                smsCode = ""
                            }
                        }
                    }
                    .disabled(smsCode.isEmpty)
                }
                .padding(.horizontal)
            }
            .presentationDetents([.medium])
        }
    }

    private func showMessage(_ text: String, color: Color) {
        message = text
        messageColor = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            message = nil
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }

    private func registerAfterVerification() async {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let dob = dob else { return }
        let username = trimmedPhone.filter { $0.isNumber }
        do {
            try await DatabaseManager.shared.insertUser(
                username: username,
                password: UUID().uuidString,
                firstName: trimmedFirst,
                lastName: trimmedLast,
                phoneNumber: trimmedPhone,
                dob: dateFormatter.string(from: dob),
                picture: UIImage(named: "default-profile")?.pngData()
            )
            let member = try await DatabaseManager.shared.fetchMemberByPhoneNumber(phoneNumber: trimmedPhone)
            await DatabaseManager.shared.createTablesIfNeeded(for: username)
            await MainActor.run {
                loggedInUser = member?.username ?? username
                userPermit = member?.permit ?? 0
                isLoggedIn = true
                showMessage("Registration Complete", color: .green)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onComplete?()
                dismiss()
            }
        } catch {
            await MainActor.run { showMessage("Unable to create user", color: .red) }
        }
    }

    private func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { $0.isNumber }
        let limited = String(digits.prefix(10))
        let area = limited.prefix(3)
        let middle = limited.dropFirst(3).prefix(3)
        let last = limited.dropFirst(6)
        var result = ""
        if !area.isEmpty {
            result += "(" + area
            if area.count == 3 { result += ")" }
        }
        result += middle
        if !last.isEmpty {
            result += "-" + last
        }
        return result
    }
}

#Preview {
    RegisterView(isLoggedIn: .constant(false), userPermit: .constant(0), loggedInUser: .constant(""))
}

