import SwiftUI

struct MemberView: View {
    @Environment(\.dismiss) var dismiss
    let userPermit: Int
    @State private var members: [Member] = []
    @State private var sortOption: SortOption = .name
    @State private var editMode: EditMode = .inactive

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

    private func move(from source: IndexSet, to destination: Int) {
        members.move(fromOffsets: source, toOffset: destination)
        for (index, member) in members.enumerated() {
            _ = DatabaseManager.shared.updateSortOrder(id: member.id, sortOrder: index)
        }
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
                }
                .onMove(perform: move)
            }
            .navigationTitle("Members")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if userPermit == 9 || userPermit == 2 {
                        Button(editMode == .active ? "Done" : "Reorder") {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
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
        }
        .environment(\.editMode, $editMode)
    }
}

#Preview {
    MemberView(userPermit: 1)
}

