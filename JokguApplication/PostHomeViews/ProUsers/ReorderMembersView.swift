import SwiftUI

struct ReorderMembersView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []

    var body: some View {
        List {
            ForEach(members) { member in
                Text("\(member.lastName) \(member.firstName)")
            }
            .onMove(perform: move)
        }
        .navigationTitle("Reorder Members")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            members = DatabaseManager.shared.fetchMembers()
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        members.move(fromOffsets: source, toOffset: destination)
        for (index, member) in members.enumerated() {
            _ = DatabaseManager.shared.updateOrder(id: member.id, order: index)
        }
    }
}

#Preview {
    ReorderMembersView()
}
