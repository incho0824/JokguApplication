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
            Task {
                if let allMembers = try? await DatabaseManager.shared.fetchMembers() {
                    await MainActor.run {
                        members = allMembers.filter { $0.guest != 0 }
                        guestMembers = allMembers.filter { $0.guest == 0 }
                        updateOrderIndices()
                    }
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        members.move(fromOffsets: source, toOffset: destination)
        updateOrderIndices()
    }

    private func updateOrderIndices() {
        Task {
            for (index, member) in members.enumerated() {
                try? await DatabaseManager.shared.updateOrder(id: member.id, order: index)
            }
            for (offset, member) in guestMembers.enumerated() {
                try? await DatabaseManager.shared.updateOrder(id: member.id, order: members.count + offset)
            }
        }
    }
}

#Preview {
    ReorderMembersView()
}
