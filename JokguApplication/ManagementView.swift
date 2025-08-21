import SwiftUI

struct ManagementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var keyCode = KeyCode(id: 0, code: "", location: "")

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Keycode", text: $keyCode.code, onCommit: {
                    DatabaseManager.shared.updateManagement(id: keyCode.id, code: keyCode.code, location: keyCode.location)
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Location", text: $keyCode.location, onCommit: {
                    DatabaseManager.shared.updateManagement(id: keyCode.id, code: keyCode.code, location: keyCode.location)
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())

                Spacer()
            }
            .padding()
            .navigationTitle("Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        if let item = DatabaseManager.shared.fetchKeyCodes().first {
            keyCode = item
        }
    }
}

#Preview {
    ManagementView()
}
