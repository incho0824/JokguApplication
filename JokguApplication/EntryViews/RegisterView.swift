import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var dob: Date = Date()
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red

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

            DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "en_GB"))
                .padding(.horizontal)

            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal)

            SecureField("Password", text: $password)
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
                Button("Create") {
                    if DatabaseManager.shared.userExists(username) {
                        showMessage("Username already exists", color: .red)
                    } else if DatabaseManager.shared.insertUser(username: username, password: password, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, dob: dateFormatter.string(from: dob)) {
                        showMessage("User created", color: .green)
                        self.firstName = ""
                        self.lastName = ""
                        self.phoneNumber = ""
                        self.dob = Date()
                        self.username = ""
                        self.password = ""
                    } else {
                        showMessage("Unable to create user", color: .red)
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
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }
}

#Preview {
    RegisterView()
}
