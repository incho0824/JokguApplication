import SwiftUI
import PhotosUI

struct MemberView: View {
    @Environment(\.dismiss) var dismiss
    let userPermit: Int
    @State private var members: [Member] = []
    @State private var sortOption: SortOption = .name
    @State private var selectedMember: Member?
    @State private var newPermit: Int = 0
    @State private var showPermitChoice = false

    private enum ActiveAlert: Identifiable {
        case delete
        case permit

        var id: Int { hashValue }
    }

    @State private var activeAlert: ActiveAlert?

    private enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case attendance = "Attendance"
        case age = "Age"

        var id: String { rawValue }
    }

    private func sortMembers() {
        switch sortOption {
        case .name:
            members.sort { $0.lastName < $1.lastName }
        case .attendance:
            members.sort { $0.attendance > $1.attendance }
        case .age:
            members.sort {
                guard
                    let date0 = date(from: $0.dob),
                    let date1 = date(from: $1.dob)
                else { return false }
                return date0 < date1
            }
        }
    }

    private func date(from dob: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: dob)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(members.indices, id: \.self) { index in
                    let member = members[index]
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
                            if userPermit == 2 {
                                Text("Recovery: \(member.recovery)")
                            }
                            if userPermit == 9 || userPermit == 2 {
                                Toggle("Guest", isOn: Binding(
                                    get: { members[index].guest == 1 },
                                    set: { newValue in
                                        members[index].guest = newValue ? 1 : 0
                                        _ = DatabaseManager.shared.updateGuest(id: member.id, guest: members[index].guest)
                                    }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                    .swipeActions {
                        if userPermit > 0 && member.permit != 2 {
                            Button(role: .destructive) {
                                selectedMember = member
                                activeAlert = .delete
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        if userPermit == 2 && member.permit != 2 {
                            Button {
                                selectedMember = member
                                showPermitChoice = true
                            } label: {
                                Label("Permit", systemImage: "pencil")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Members")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .onAppear {
                members = DatabaseManager.shared.fetchMembers()
                sortMembers()
            }
            .onChange(of: sortOption) {
                sortMembers()
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
                            if let member = selectedMember, member.permit != 2 {
                                _ = DatabaseManager.shared.deleteUser(id: member.id)
                                members = DatabaseManager.shared.fetchMembers()
                                sortMembers()
                            }
                        },
                        secondaryButton: .cancel()
                    )
                case .permit:
                    return Alert(
                        title: Text("Confirm Permit Change"),
                        message: Text("Change permit to \(newPermit) for \(selectedMember?.username ?? "user")?"),
                        primaryButton: .default(Text("Update")) {
                            if let member = selectedMember, member.permit != 2 {
                                _ = DatabaseManager.shared.updatePermit(id: member.id, permit: newPermit)
                                members = DatabaseManager.shared.fetchMembers()
                                sortMembers()
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

