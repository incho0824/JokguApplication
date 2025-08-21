import SwiftUI

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @State private var showManagement = false

    var body: some View {
        VStack {
            Text("Atlanta Jokgu Association")
                .font(.title)
                .padding()

            if userPermit > 0 {
                Button("Management") {
                    showManagement = true
                }
                .padding()
                .sheet(isPresented: $showManagement) {
                    ManagementView()
                }
            }

            Button("Logout") {
                isLoggedIn = false
            }
            .padding()
        }
    }
}

#Preview {
    HomeView(isLoggedIn: .constant(true), userPermit: .constant(1))
}
