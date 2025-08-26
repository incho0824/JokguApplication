import SwiftUI

struct ReorderMembersView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var guestMembers: [Member] = []

    var body: some View {
        List {
            ForEach(members) { member in
                Text("\(member.lastName) \(member.firstName)")
            }
            .onMove(perform: move)
        }
        .navigationTitle("Reorder Members")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            let allMembers = DatabaseManager.shared.fetchMembers()
            members = allMembers.filter { $0.guest != 0 }
            guestMembers = allMembers.filter { $0.guest == 0 }
            updateOrderIndices()
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        members.move(fromOffsets: source, toOffset: destination)
        updateOrderIndices()
    }

    private func updateOrderIndices() {
        for (index, member) in members.enumerated() {
            _ = DatabaseManager.shared.updateOrder(id: member.id, order: index)
        }
        for (offset, member) in guestMembers.enumerated() {
            _ = DatabaseManager.shared.updateOrder(id: member.id, order: members.count + offset)
        }
    }
}

#Preview {
    ReorderMembersView()
}
