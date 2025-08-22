import SwiftUI

struct ManagementView: View {
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var keyCode = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: "", notification: "")
    @State private var originalKeyCode = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: "", notification: "")

    private var hasChanges: Bool {
        keyCode.code != originalKeyCode.code ||
        keyCode.address != originalKeyCode.address ||
        keyCode.welcome != originalKeyCode.welcome ||
        keyCode.youtube != originalKeyCode.youtube ||
        keyCode.notification != originalKeyCode.notification
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Keycode", text: $keyCode.code)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Address", text: $keyCode.address)
                    .textContentType(.fullStreetAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Welcome", text: $keyCode.welcome)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Youtube", text: $keyCode.youtube)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Notification", text: $keyCode.notification)
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
                        DatabaseManager.shared.updateManagement(id: keyCode.id, code: keyCode.code, address: keyCode.address, welcome: keyCode.welcome, youtube: keyCode.youtube, notification: keyCode.notification)
                        originalKeyCode = keyCode
                        onSave?()
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
        if let item = DatabaseManager.shared.fetchManagementData().first {
            keyCode = item
            originalKeyCode = item
        }
    }
}

#Preview {
    ManagementView()
}
