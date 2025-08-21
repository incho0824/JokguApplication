import SwiftUI

struct HomeView: View {
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack {
            Text("Atlanta Jokgu Association")
                .font(.title)
                .padding()

            Button("Logout") {
                isLoggedIn = false
            }
            .padding()
        }
    }
}

#Preview {
    HomeView(isLoggedIn: .constant(true))
}
