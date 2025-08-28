import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var loggedInUser: String
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var verificationID: String? = nil
    @State private var loginFailed: Bool = false
    @State private var showKeyCodePrompt: Bool = false
    @State private var keyCodeInput: String = ""
    @State private var showMemberVerifyView: Bool = false
    @State private var showAddressPrompt: Bool = false
    @State private var canUseBiometrics = false
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

                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
                    .onChange(of: phoneNumber) { _, newValue in
                        phoneNumber = formatPhoneNumber(newValue)
                    }
                    .padding(.horizontal)

                Button("Send Code") {
                    let digits = phoneNumber.filter { $0.isNumber }
                    let phone = digits.hasPrefix("1") ? "+" + digits : "+1" + digits
                    Task {
                        do {
                            verificationID = try await DatabaseManager.shared.sendVerificationCode(to: phone)
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
                .disabled(phoneNumber.filter { $0.isNumber }.count < 10)
                .padding(.horizontal)

                TextField("SMS Code", text: $verificationCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
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
                    let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        do {
                            if let verificationID = verificationID {
                                try await DatabaseManager.shared.signIn(with: verificationID, smsCode: verificationCode)
                                if let member = try await DatabaseManager.shared.fetchMemberByPhoneNumber(phoneNumber: trimmedPhone) {
                                    await MainActor.run {
                                        loggedInUser = member.username
                                        isLoggedIn = true
                                        loginFailed = false
                                        userPermit = member.permit
                                        let defaults = UserDefaults.standard
                                        defaults.set(member.username, forKey: "biometricUsername")
                                        defaults.set(member.permit, forKey: "biometricPermit")
                                    }
                                } else {
                                    await MainActor.run {
                                        loginFailed = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                            loginFailed = false
                                        }
                                    }
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
                        let storedCode = databaseManager.management?.code ?? ""
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
        .sheet(isPresented: $showMemberVerifyView) {
            MemberVerificationView()
        }
    }

    private func openInMaps(address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)") {
            openURL(url)
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
