import SwiftUI
import PhotosUI

struct MemberView: View {
    @Environment(\.dismiss) var dismiss
    let userPermit: Int
    @State private var members: [Member] = []
    @State private var selectedMember: Member?
    @State private var newPermit: Int = 0
    @State private var showPermitChoice = false

    private enum ActiveAlert: Identifiable {
        case delete
        case permit

        var id: Int { hashValue }
    }

    @State private var activeAlert: ActiveAlert?

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
                .swipeActions {
                    if userPermit > 0 {
                        Button(role: .destructive) {
                            selectedMember = member
                            activeAlert = .delete
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    if userPermit == 2 {
                        Button {
                            selectedMember = member
                            showPermitChoice = true
                        } label: {
                            Label("Permit", systemImage: "pencil")
                        }
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
            .confirmationDialog("Select Permit", isPresented: $showPermitChoice, titleVisibility: .visible) {
                Button("Permit 0") { newPermit = 0; activeAlert = .permit }
                Button("Permit 1") { newPermit = 1; activeAlert = .permit }
                Button("Permit 2") { newPermit = 2; activeAlert = .permit }
                Button("Cancel", role: .cancel) {}
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .delete:
                    return Alert(
                        title: Text("Confirm Delete"),
                        message: Text("Are you sure you want to delete \(selectedMember?.username ?? "this user")?"),
                        primaryButton: .destructive(Text("Delete")) {
                            if let member = selectedMember {
                                _ = DatabaseManager.shared.deleteUser(id: member.id)
                                members = DatabaseManager.shared.fetchMembers()
                            }
                        },
                        secondaryButton: .cancel()
                    )
                case .permit:
                    return Alert(
                        title: Text("Confirm Permit Change"),
                        message: Text("Change permit to \(newPermit) for \(selectedMember?.username ?? "user")?"),
                        primaryButton: .default(Text("Update")) {
                            if let member = selectedMember {
                                _ = DatabaseManager.shared.updatePermit(id: member.id, permit: newPermit)
                                members = DatabaseManager.shared.fetchMembers()
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }
}

#Preview {
    MemberView(userPermit: 1)
}

