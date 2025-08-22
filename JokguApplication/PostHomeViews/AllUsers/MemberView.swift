import SwiftUI
import PhotosUI

struct MemberView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []

    var body: some View {
        NavigationView {
            List(members) { member in
                HStack(alignment: .top) {
                    if let data = member.picture,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Image("default-profile")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    }
                    VStack(alignment: .leading) {
                        Text("\(member.lastName) \(member.firstName)")
                        Text("DOB: \(member.dob)")
                        Text("Phone: \(member.phoneNumber)")
                        Text("Attendance: \(member.attendance)")
                    }
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

