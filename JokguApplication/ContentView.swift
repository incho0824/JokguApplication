import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var loginFailed: Bool = false

    var body: some View {
        if isLoggedIn {
            HomeView()
        } else {
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
                    if username == "admin" && password == "admin" {
                        isLoggedIn = true
                        loginFailed = false
                    } else {
                        loginFailed = true
                    }
                }
                .padding(.top)

                if loginFailed {
                    Text("Invalid credentials")
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
