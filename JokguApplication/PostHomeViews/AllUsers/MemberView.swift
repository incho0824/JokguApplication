import SwiftUI

struct MemberView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []

    var body: some View {
        NavigationView {
            List(members) { member in
                VStack(alignment: .leading) {
                    Text("\(member.lastName) \(member.firstName)")
                    Text("DOB: \(member.dob)")
                    Text("Phone: \(member.phoneNumber)")
                    Text("Attendance: \(member.attendance)")
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

