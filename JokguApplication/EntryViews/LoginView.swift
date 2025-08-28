import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var loggedInUser: String
    @State private var phoneNumber: String = ""
    @State private var smsCode: String = ""
    @State private var verificationID: String? = nil
    @State private var isSendingCode = false
    @State private var errorMessage: String? = nil
    @State private var showKeyCodePrompt: Bool = false
    @State private var keyCodeInput: String = ""
    @State private var showMemberVerifyView: Bool = false
    @State private var showAddressPrompt: Bool = false
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
                    .padding(.horizontal)
                    .onChange(of: phoneNumber) { _, newValue in
                        phoneNumber = formatPhoneNumber(newValue)
                    }

                if verificationID == nil {
                    Button("Send Code") {
                        sendCode()
                    }
                    .disabled(phoneNumber.isEmpty || isSendingCode)
                } else {
                    TextField("Verification Code", text: $smsCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .padding(.horizontal)

                    Button("Confirm") {
                        confirmCode()
                    }
                    .disabled(smsCode.isEmpty)
                }

                Button("Register") {
                    showKeyCodePrompt = true
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
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

    private func formatForAuth(_ number: String) -> String {
        let digits = number.filter { $0.isNumber }
        if digits.count == 11 && digits.hasPrefix("1") {
            return "+" + digits
        } else {
            return "+1" + String(digits.prefix(10))
        }
    }

    private func sendCode() {
        let phone = formatForAuth(phoneNumber)
        isSendingCode = true
        PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil) { id, error in
            DispatchQueue.main.async {
                isSendingCode = false
                if let id = id {
                    verificationID = id
                } else if let error = error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func confirmCode() {
        guard let id = verificationID else { return }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: smsCode)
        Auth.auth().signIn(with: credential) { _, error in
            DispatchQueue.main.async {
                if error == nil {
                    Task {
                        let digits = phoneNumber.filter { $0.isNumber }
                        let candidates = [phoneNumber, digits]
                        var fetchedMember: Member?
                        for number in candidates {
                            if let member = try? await DatabaseManager.shared.fetchMemberByPhoneNumber(phoneNumber: number), member.syncd == 1 {
                                fetchedMember = member
                                break
                            }
                        }
                        if let member = fetchedMember {
                            await MainActor.run {
                                loggedInUser = member.username
                                userPermit = member.permit
                                isLoggedIn = true
                            }
                        } else {
                            await MainActor.run { errorMessage = "Account has not been registered" }
                        }
                        try? Auth.auth().signOut()
                        await MainActor.run {
                            verificationID = nil
                            smsCode = ""
                        }
                    }
                } else {
                    errorMessage = error?.localizedDescription
                }
            }
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
}

#Preview {
    LoginView(isLoggedIn: .constant(false), userPermit: .constant(0), loggedInUser: .constant(""))
        .environmentObject(DatabaseManager.shared)
}
