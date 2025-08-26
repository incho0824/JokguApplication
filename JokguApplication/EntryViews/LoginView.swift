import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var loggedInUser: String
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginFailed: Bool = false
    @State private var showKeyCodePrompt: Bool = false
    @State private var keyCodeInput: String = ""
    @State private var showMemberVerifyView: Bool = false
    @State private var showAddressPrompt: Bool = false
    @State private var showRecoveryPrompt: Bool = false
    @State private var recoveryCodeInput: String = ""
    @State private var recoveryMember: Member? = nil
    @State private var management = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, kakao: nil, notification: "", playwhen: [], fee: 0, venmo: "")
    @State private var canUseBiometrics = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.85, blue: 0.7),
                    Color(red: 1.0, green: 0.65, blue: 0.45)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                    .padding(.bottom, 20)

                Text(management.welcome)
                    .foregroundColor(.white)

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
                        username = newValue.filter { $0.isLetter || $0.isNumber }
                    }
                    .padding(.horizontal)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .overlay(alignment: .trailing) {
                        if canUseBiometrics {
                            Button(action: authenticateWithBiometrics) {
                                Image(systemName: "faceid")
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 12)
                        }
                    }

                Button("Login") {
                    let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if let permit = DatabaseManager.shared.validateUser(username: trimmedUser, password: password) {
                        loggedInUser = trimmedUser
                        isLoggedIn = true
                        loginFailed = false
                        userPermit = permit
                        let defaults = UserDefaults.standard
                        defaults.set(trimmedUser, forKey: "biometricUsername")
                        defaults.set(permit, forKey: "biometricPermit")
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

                Button("Forgot Password?") {
                    showRecoveryPrompt = true
                }

                if loginFailed {
                    Text("Authentication failed")
                        .foregroundColor(.red)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal)
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 0) {
                    if let kakaoURL = management.kakao {
                        Button {
                            openURL(kakaoURL)
                        } label: {
                            Image("kakao-logo")
                                .resizable()
                                .frame(width: 40, height: 30)
                                .padding()
                        }
                    }
                    if let url = management.youtube {
                        Button {
                            openURL(url)
                        } label: {
                            Image("youtube-logo")
                                .resizable()
                                .frame(width: 40, height: 30)
                                .padding()
                        }
                    }
                }
            }
        }
        .onAppear {
            loadManagement()
            checkBiometricAvailability()
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
                            showMemberVerifyView = true
                        }
                    }
                }
                .padding(.top)
            }
            .padding()
        }
        .sheet(isPresented: $showRecoveryPrompt) {
            VStack(spacing: 16) {
                TextField("Enter verification code", text: $recoveryCodeInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding(.horizontal)

                Text("Ask In Cho for your verification code.\n(SMS Mobile Text Verification is currently disabled because\nIn Cho does not want to pay for the Twilio Account)")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack {
                    Button("Cancel") {
                        showRecoveryPrompt = false
                        recoveryCodeInput = ""
                    }

                    Spacer()

                    Button("Confirm") {
                        if let code = Int(recoveryCodeInput), code != 0,
                           let member = DatabaseManager.shared.fetchMemberByRecovery(code: code) {
                            showRecoveryPrompt = false
                            recoveryCodeInput = ""
                            recoveryMember = member
                        }
                    }
                    .disabled(recoveryCodeInput.isEmpty)
                }
                .padding(.top)
            }
            .padding()
        }
        .sheet(item: $recoveryMember) { member in
            RegisterView(member: member)
        }
        .sheet(isPresented: $showMemberVerifyView) {
            MemberVerificationView()
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

    private func authenticateWithBiometrics() {
        let context = LAContext()
        let reason = "Authenticate to login"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                if success {
                    let defaults = UserDefaults.standard
                    if let savedUser = defaults.string(forKey: "biometricUsername") {
                        loggedInUser = savedUser
                        userPermit = defaults.integer(forKey: "biometricPermit")
                        isLoggedIn = true
                    } else {
                        loginFailed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            loginFailed = false
                        }
                    }
                } else {
                    loginFailed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        loginFailed = false
                    }
                }
            }
        }
    }

    private func checkBiometricAvailability() {
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil),
           UserDefaults.standard.string(forKey: "biometricUsername") != nil {
            canUseBiometrics = true
        } else {
            canUseBiometrics = false
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false), userPermit: .constant(0), loggedInUser: .constant(""))
}
