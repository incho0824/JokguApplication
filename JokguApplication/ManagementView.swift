import SwiftUI

struct ManagementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var keyCode = KeyCode(id: 0, code: "", location: "")
    @State private var originalKeyCode = KeyCode(id: 0, code: "", location: "")

    private var hasChanges: Bool {
        keyCode.code != originalKeyCode.code || keyCode.location != originalKeyCode.location
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Keycode", text: $keyCode.code)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Location", text: $keyCode.location)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Spacer()
            }
            .padding()
            .navigationTitle("Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        DatabaseManager.shared.updateManagement(id: keyCode.id, code: keyCode.code, location: keyCode.location)
                        originalKeyCode = keyCode
                    }
                    .disabled(!hasChanges)
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
            originalKeyCode = item
        }
    }
}

#Preview {
    ManagementView()
}
