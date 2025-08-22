import SwiftUI

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var username: String
    @State private var showManagement = false
    @State private var showMembers = false
    @State private var showProfile = false
    @State private var management = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, notification: "")

    var body: some View {
        VStack {
            Text("Atlanta Jokgu Association")
                .font(.title)
                .padding()

            Text(management.notification)
                .padding(.vertical)
                .padding(.bottom, 20)

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
                .sheet(isPresented: $showManagement, onDismiss: loadManagement) {
                    ManagementView(onSave: loadManagement)
                }
            }

            Button("Logout") {
                username = ""
                isLoggedIn = false
            }
            .padding()

            Spacer()
        }
        .onAppear {
            loadManagement()
        }
    }

    private func loadManagement() {
        if let item = DatabaseManager.shared.fetchManagementData().first {
            management = item
        }
    }

}

#Preview {
    HomeView(isLoggedIn: .constant(true), userPermit: .constant(1), username: .constant("USER"))
}
