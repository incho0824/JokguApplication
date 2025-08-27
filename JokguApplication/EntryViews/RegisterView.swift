import SwiftUI
import PhotosUI

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    var member: Member? = nil
    var onComplete: (() -> Void)? = nil
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var dob: Date? = nil
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
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

                DatePicker("Date of Birth", selection: Binding(
                    get: { dob ?? Date() },
                    set: { dob = $0 }
                ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "en_US"))
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

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
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
                        if trimmedFirst.isEmpty || trimmedLast.isEmpty || trimmedPhone.isEmpty || trimmedUser.isEmpty || password.isEmpty {
                            showMessage("All fields are required", color: .red)
                        } else if dob == nil {
                            showMessage("Date of birth is required", color: .red)
                        } else if confirmPassword.isEmpty {
                            showMessage("Please confirm your password", color: .red)
                        } else if password != confirmPassword {
                            showMessage("Passwords do not match", color: .red)
                        } else if !trimmedUser.allSatisfy({ $0.isLetter || $0.isNumber }) {
                            showMessage("Username must contain letters and numbers only", color: .red)
                        } else {
                            Task {
                                do {
                                    if try await DatabaseManager.shared.userExists(trimmedUser) {
                                        await MainActor.run { showMessage("Username already exists", color: .red) }
                                    } else {
                                        try await DatabaseManager.shared.insertUser(username: trimmedUser, password: password, firstName: trimmedFirst, lastName: trimmedLast, phoneNumber: trimmedPhone, dob: dateFormatter.string(from: dob!), picture: pictureData ?? UIImage(named: "default-profile")?.pngData())
                                        await MainActor.run {
                                            showMessage("User created", color: .green)
                                            onComplete?()
                                            dismiss()
                                        }
                                    }
                                } catch {
                                    await MainActor.run { showMessage("Unable to create user", color: .red) }
                                }
                            }
                        }
                    } else if let member = member {
                        if trimmedUser.isEmpty || password.isEmpty {
                            showMessage("All fields are required", color: .red)
                        } else if confirmPassword.isEmpty {
                            showMessage("Please confirm your password", color: .red)
                        } else if password != confirmPassword {
                            showMessage("Passwords do not match", color: .red)
                        } else {
                            Task {
                                do {
                                    if try await DatabaseManager.shared.userExists(trimmedUser) && trimmedUser != member.username.uppercased() {
                                        await MainActor.run { showMessage("Username already exists", color: .red) }
                                    } else {
                                        try await DatabaseManager.shared.updateMemberCredentials(id: member.id, username: trimmedUser, password: password)
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
