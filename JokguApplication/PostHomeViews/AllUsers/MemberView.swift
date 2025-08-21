import SwiftUI

struct MemberView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []

    var body: some View {
        NavigationView {
            List(members) { member in
                VStack(alignment: .leading) {
                    Text("ID: \(member.id)")
                    Text("Username: \(member.username)")
                    Text("Password: \(member.password)")
                }
            }
            .navigationTitle("Members")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                members = DatabaseManager.shared.fetchMembers()
            }
        }
    }
}

#Preview {
    MemberView()
}

