import SwiftUI
import PhotosUI
import FirebaseAuth

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    var member: Member? = nil
    var onComplete: (() -> Void)? = nil
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var dob: Date? = nil
    @State private var username: String = ""
    @State private var verificationID: String? = nil
    @State private var smsCode: String = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var pictureData: Data? = nil

    init(member: Member? = nil, onComplete: (() -> Void)? = nil) {
        self.member = member
        self.onComplete = onComplete
        _firstName = State(initialValue: member?.firstName ?? "")
        _lastName = State(initialValue: member?.lastName ?? "")
        _phoneNumber = State(initialValue: member?.phoneNumber ?? "")
        if let dobString = member?.dob {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy"
            _dob = State(initialValue: formatter.date(from: dobString))
        } else {
            _dob = State(initialValue: nil)
        }
        _username = State(initialValue: "")
    }

    var body: some View {
        VStack(spacing: 16) {
            if member == nil {
                PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                    if let pictureData,
                       let uiImage = UIImage(data: pictureData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Image("default-profile")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    }
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            pictureData = data
                        }
                    }
                }

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

                Button("Send Code") {
                    let digits = phoneNumber.filter { $0.isNumber }
                    let phone = digits.hasPrefix("1") ? "+" + digits : "+1" + digits
                    Task {
                        do {
                            verificationID = try await DatabaseManager.shared.sendVerificationCode(to: phone)
                            await MainActor.run { showMessage("Code sent", color: .green) }
                        } catch {
                            await MainActor.run { showMessage("Failed to send code", color: .red) }
                        }
                    }
                }
                .disabled(phoneNumber.filter { $0.isNumber }.count < 10)
                .padding(.horizontal)

                DatePicker("Date of Birth", selection: Binding(
                    get: { dob ?? Date() },
                    set: { dob = $0 }
                ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .padding(.horizontal)

                TextField("SMS Code", text: $smsCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding(.horizontal)
            } else {
                Text("Registering \(firstName) \(lastName)")
                Text("DOB: \(member!.dob)")
            }

            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: username) { _, newValue in
                    username = newValue.filter { $0.isLetter || $0.isNumber }
                }
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
                    let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if member == nil {
                        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedFirst.isEmpty || trimmedLast.isEmpty || trimmedPhone.isEmpty || trimmedUser.isEmpty {
                            showMessage("All fields are required", color: .red)
                        } else if dob == nil {
                            showMessage("Date of birth is required", color: .red)
                        } else if verificationID == nil || smsCode.isEmpty {
                            showMessage("Phone verification required", color: .red)
                        } else if !trimmedUser.allSatisfy({ $0.isLetter || $0.isNumber }) {
                            showMessage("Username must contain letters and numbers only", color: .red)
                        } else {
                            Task {
                                do {
                                    try await DatabaseManager.shared.signIn(with: verificationID!, smsCode: smsCode)
                                    if try await DatabaseManager.shared.userExists(trimmedUser) {
                                        await MainActor.run { showMessage("Username already exists", color: .red) }
                                    } else {
                                        try await DatabaseManager.shared.insertUser(username: trimmedUser, firstName: trimmedFirst, lastName: trimmedLast, phoneNumber: trimmedPhone, dob: dateFormatter.string(from: dob!), picture: pictureData ?? UIImage(named: "default-profile")?.pngData())
                                        try? Auth.auth().signOut()
                                        await MainActor.run {
                                            showMessage("User created", color: .green)
                                            onComplete?()
                                            dismiss()
                                        }
                                    }
                                } catch {
                                    print("Create user error:", error)
                                    await MainActor.run { showMessage("Unable to create user", color: .red) }
                                }
                            }
                        }
                    } else if let member = member {
                        if trimmedUser.isEmpty {
                            showMessage("All fields are required", color: .red)
                        } else {
                            Task {
                                do {
                                    if try await DatabaseManager.shared.userExists(trimmedUser) && trimmedUser != member.username.uppercased() {
                                        await MainActor.run { showMessage("Username already exists", color: .red) }
                                    } else {
                                        try await DatabaseManager.shared.updateMemberUsername(id: member.id, username: trimmedUser)
                                        await MainActor.run {
                                            showMessage("User updated", color: .green)
                                            onComplete?()
                                            dismiss()
                                        }
                                    }
                                } catch {
                                    await MainActor.run { showMessage("Unable to update user", color: .red) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .padding()
    }

    private func showMessage(_ text: String, color: Color) {
        message = text
        messageColor = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            message = nil
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
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
    RegisterView()
}
