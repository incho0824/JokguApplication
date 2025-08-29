import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn: Bool = false
    @State private var userPermit: Int = 0
    @State private var phoneNumber: String = ""

    var body: some View {
        if isLoggedIn {
            HomeView(isLoggedIn: $isLoggedIn, userPermit: $userPermit, phoneNumber: $phoneNumber)
        } else {
            LoginView(isLoggedIn: $isLoggedIn, userPermit: $userPermit, loggedInUser: $phoneNumber)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DatabaseManager.shared)
}
