import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var loggedInUser: String
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginFailed: Bool = false
    @State private var showKeyCodePrompt: Bool = false
    @State private var keyCodeInput: String = ""
    @State private var showRegisterView: Bool = false
    @State private var showAddressPrompt: Bool = false
    @State private var management = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, notification: "", fee: 0, venmo: "")
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .padding(.bottom, 20)

            Text(management.welcome)

            Button(action: { showAddressPrompt = true }) {
                Text(management.address)
                    .foregroundColor(.blue)
                    .underline()
            }
            .disabled(management.address.isEmpty)
            .alert("Open in Maps?", isPresented: $showAddressPrompt) {
                Button("Open") {
                    openInMaps(address: management.address)
                }
                Button("Cancel", role: .cancel) {}
            }
            .padding(.bottom, 20)

            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: username) { _, newValue in
                    username = newValue.filter { $0.isLetter }
                }
                .padding(.horizontal)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Button("Login") {
                let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if let permit = DatabaseManager.shared.validateUser(username: trimmedUser, password: password) {
                    loggedInUser = trimmedUser
                    isLoggedIn = true
                    loginFailed = false
                    userPermit = permit
                } else {
                    loginFailed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        loginFailed = false
                    }
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
        .onAppear {
            loadManagement()
        }
        .sheet(isPresented: $showKeyCodePrompt) {
            VStack(spacing: 16) {
                TextField("Enter key code", text: $keyCodeInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding(.horizontal)

                HStack {
                    Button("Cancel") {
                        showKeyCodePrompt = false
                        keyCodeInput = ""
                    }

                    Spacer()

                    Button("Confirm") {
                        let storedCode = DatabaseManager.shared.fetchKeyCode() ?? ""
                        if keyCodeInput == storedCode {
                            showKeyCodePrompt = false
                            keyCodeInput = ""
                            showRegisterView = true
                        }
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

    private func loadManagement() {
        if let item = DatabaseManager.shared.fetchManagementData().first {
            management = item
        }
    }

    private func openInMaps(address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)") {
            openURL(url)
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false), userPermit: .constant(0), loggedInUser: .constant(""))
}
