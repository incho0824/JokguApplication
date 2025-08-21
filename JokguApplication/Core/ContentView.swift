import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn: Bool = false
    @State private var userPermit: Int = 0

    var body: some View {
        if isLoggedIn {
            HomeView(isLoggedIn: $isLoggedIn, userPermit: $userPermit)
        } else {
            LoginView(isLoggedIn: $isLoggedIn, userPermit: $userPermit)
        }
    }
}

#Preview {
    ContentView()
}
