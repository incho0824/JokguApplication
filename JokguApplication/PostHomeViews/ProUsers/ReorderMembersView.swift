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
            var updates: [(Int, Int)] = []
            for (index, member) in members.enumerated() {
                updates.append((member.id, index))
            }
            for (offset, member) in guestMembers.enumerated() {
                updates.append((member.id, members.count + offset))
            }
            try? await DatabaseManager.shared.updateOrders(updates)
        }
    }
}

#Preview {
    ReorderMembersView()
}
