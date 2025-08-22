import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn: Bool = false
    @State private var userPermit: Int = 0
    @State private var username: String = ""

    var body: some View {
        if isLoggedIn {
            HomeView(isLoggedIn: $isLoggedIn, userPermit: $userPermit, username: $username)
        } else {
            LoginView(isLoggedIn: $isLoggedIn, userPermit: $userPermit, loggedInUser: $username)
        }
    }
}

#Preview {
    ContentView()
}
