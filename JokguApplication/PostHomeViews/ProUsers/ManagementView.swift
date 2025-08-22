import SwiftUI

struct ManagementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var userFields: [String: [Int]] = [:]
    private let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    var body: some View {
        NavigationView {
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow()
                    ForEach(members) { member in
                        rowView(for: member)
                    }
                }
            }
            .navigationTitle("Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear { loadData() }
        }
    }

    private func headerRow() -> some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 120, height: 40)
                .border(Color.gray)
            ForEach(months, id: \.self) { month in
                Text(month)
                    .frame(width: 60, height: 40)
                    .background(Color.gray.opacity(0.2))
                    .border(Color.gray)
            }
        }
    }

    private func rowView(for member: Member) -> some View {
        let fields = userFields[member.username] ?? []
        return HStack(spacing: 0) {
            Text("\(member.lastName) \(member.firstName)")
                .frame(width: 120, height: 40, alignment: .leading)
                .border(Color.gray)
            ForEach(0..<12, id: \.self) { index in
                let value = index < fields.count ? fields[index] : 0
                Text(value > 0 ? "\(value)" : "-")
                    .frame(width: 60, height: 40)
                    .background(value > 0 ? Color.green.opacity(0.3) : Color.clear)
                    .border(Color.gray)
            }
        }
    }

    private func loadData() {
        members = DatabaseManager.shared.fetchMembers()
        var dict: [String: [Int]] = [:]
        for member in members {
            if let values = DatabaseManager.shared.fetchUserFields(username: member.username) {
                dict[member.username] = values
            } else {
                dict[member.username] = []
            }
        }
        userFields = dict
    }
}

#Preview {
    ManagementView()
}

