import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red

    var body: some View {
        VStack(spacing: 16) {
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
                    } else if DatabaseManager.shared.insertUser(username: username, password: password) {
                        showMessage("User created", color: .green)
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
}

#Preview {
    RegisterView()
}
