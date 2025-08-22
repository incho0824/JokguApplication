import SwiftUI

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var username: String
    @State private var showManagement = false
    @State private var showMembers = false
    @State private var showProfile = false

    var body: some View {
        VStack {
            Text("Atlanta Jokgu Association")
                .font(.title)
                .padding()

            Button("Members") {
                showMembers = true
            }
            .padding()
            .sheet(isPresented: $showMembers) {
                MemberView(userPermit: userPermit)
            }

            Button("Profile") {
                showProfile = true
            }
            .padding()
            .sheet(isPresented: $showProfile) {
                ProfileView(username: username)
            }

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
                username = ""
                isLoggedIn = false
            }
            .padding()
        }
    }
}

#Preview {
    HomeView(isLoggedIn: .constant(true), userPermit: .constant(1), username: .constant("USER"))
}
