import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginFailed: Bool = false
    @State private var showKeyCodePrompt: Bool = false
    @State private var keyCodeInput: String = ""
    @State private var showRegisterView: Bool = false

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

            Button("Login") {
                if let permit = DatabaseManager.shared.validateUser(username: username, password: password) {
                    isLoggedIn = true
                    loginFailed = false
                    userPermit = permit
                } else {
                    loginFailed = true
                }
            }
            .padding(.top)

            Button("Register") {
                showKeyCodePrompt = true
            }

            if loginFailed {
                Text("Invalid credentials")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .sheet(isPresented: $showKeyCodePrompt) {
            VStack(spacing: 16) {
                TextField("Enter key code", text: $keyCodeInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding(.horizontal)

                Button("Confirm") {
                    let storedCode = DatabaseManager.shared.fetchKeyCodes().first?.code ?? ""
                    if keyCodeInput == storedCode {
                        showKeyCodePrompt = false
                        keyCodeInput = ""
                        showRegisterView = true
                    }
                }
                .padding(.top)
            }
            .padding()
        }
        .sheet(isPresented: $showRegisterView) {
            RegisterView()
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false), userPermit: .constant(0))
}
