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
                    if DatabaseManager.shared.insertUser(username: username, password: password) {
                        self.message = "User created"
                        self.messageColor = .green
                        self.username = ""
                        self.password = ""
                    } else {
                        self.message = "Username already exists"
                        self.messageColor = .red
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .padding()
    }
}

#Preview {
    RegisterView()
}
