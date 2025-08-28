import SwiftUI
import LocalAuthentication
import FirebaseAuth

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var loggedInUser: String
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginFailed: Bool = false
    @State private var showKeyCodePrompt: Bool = false
    @State private var keyCodeInput: String = ""
    @State private var showAddressPrompt: Bool = false
    @State private var canUseBiometrics = false

    @State private var showPhoneAuthSheet: Bool = false
    @State private var phoneNumber: String = ""
    @State private var verificationID: String? = nil
    @State private var smsCode: String = ""
    @State private var isSendingCode = false
    @State private var phoneAuthError: String? = nil
    @State private var existingMember: Member? = nil
    @State private var showRegisterView: Bool = false
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var databaseManager: DatabaseManager

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

                Text(databaseManager.management?.welcome ?? "")
                    .foregroundColor(.white)

                Button(action: { showAddressPrompt = true }) {
                    Text(databaseManager.management?.address ?? "")
                        .foregroundColor(.blue)
                        .underline()
                }
                .disabled((databaseManager.management?.address ?? "").isEmpty)
                .alert("Open in Maps?", isPresented: $showAddressPrompt) {
                    Button("Open") {
                        openInMaps(address: databaseManager.management?.address ?? "")
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
                    Task {
                        do {
                            if let permit = try await DatabaseManager.shared.validateUser(username: trimmedUser, password: password) {
                                await MainActor.run {
                                    loggedInUser = trimmedUser
                                    isLoggedIn = true
                                    loginFailed = false
                                    userPermit = permit
                                    let defaults = UserDefaults.standard
                                    defaults.set(trimmedUser, forKey: "biometricUsername")
                                    defaults.set(permit, forKey: "biometricPermit")
                                }
                            } else {
                                await MainActor.run {
                                    loginFailed = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        loginFailed = false
                                    }
                                }
                            }
                        } catch {
                            await MainActor.run {
                                loginFailed = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    loginFailed = false
                                }
                            }
                        }
                    }
                }
                .padding(.top)

                Button("Register") {
                    showKeyCodePrompt = true
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
                    if let kakaoURL = databaseManager.management?.kakao {
                        Button {
                            openURL(kakaoURL)
                        } label: {
                            Image("kakao-logo")
                                .resizable()
                                .frame(width: 40, height: 30)
                                .padding()
                        }
                    }
                    if let url = databaseManager.management?.youtube {
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
                        let storedCode = databaseManager.management?.code ?? "1234"
                        if keyCodeInput == storedCode {
                            showKeyCodePrompt = false
                            keyCodeInput = ""
                            showPhoneAuthSheet = true
                        }
                    }
                }
                .padding(.top)
            }
            .padding()
        }
        .sheet(isPresented: $showPhoneAuthSheet) {
            VStack(spacing: 16) {
                if verificationID == nil {
                    TextField("Enter phone number", text: $phoneNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)
                        .padding(.horizontal)

                    Button("Send Code") {
                        let digits = phoneNumber.filter { $0.isNumber }
                        let phone: String
                        if digits.count == 10 {
                            phone = "+1" + digits
                        } else if digits.count == 11 {
                            phone = "+" + digits
                        } else {
                            phoneAuthError = "Phone number must be 10 or 11 digits"
                            return
                        }
                        phoneNumber = phone
                        isSendingCode = true
                        PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil) { id, error in
                            DispatchQueue.main.async {
                                isSendingCode = false
                                if let id = id {
                                    verificationID = id
                                } else if let error = error {
                                    phoneAuthError = error.localizedDescription
                                }
                            }
                        }
                    }
                    .disabled(phoneNumber.isEmpty || isSendingCode)
                } else {
                    TextField("Enter verification code", text: $smsCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .padding(.horizontal)

                    Button("Confirm") {
                        guard let id = verificationID else { return }
                        let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: smsCode)
                        Auth.auth().signIn(with: credential) { _, error in
                            DispatchQueue.main.async {
                                if error == nil {
                                    Task {
                                        if let uid = Auth.auth().currentUser?.uid {
                                            if let member = try? await DatabaseManager.shared.fetchMemberByAuthID(uid) {
                                                if member.syncd == 0 {
                                                    existingMember = member
                                                    showRegisterView = true
                                                } else {
                                                    phoneAuthError = "Account already exists for this phone number"
                                                    try? Auth.auth().signOut()
                                                }
                                            } else {
                                                existingMember = nil
                                                showRegisterView = true
                                            }
                                        }
                                    }
                                } else {
                                    phoneAuthError = error?.localizedDescription
                                }
                                showPhoneAuthSheet = false
                                smsCode = ""
                                verificationID = nil
                            }
                        }
                    }
                    .disabled(smsCode.isEmpty)
                }

                Button("Cancel") {
                    showPhoneAuthSheet = false
                    phoneNumber = ""
                    smsCode = ""
                    verificationID = nil
                }
            }
            .padding()
        }
        .alert(phoneAuthError ?? "", isPresented: Binding(get: { phoneAuthError != nil }, set: { _ in phoneAuthError = nil })) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showRegisterView) {
            if let member = existingMember {
                RegisterView(member: member) {
                    try? Auth.auth().signOut()
                }
            } else {
                RegisterView() {
                    try? Auth.auth().signOut()
                }
            }
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
        .environmentObject(DatabaseManager.shared)
}
