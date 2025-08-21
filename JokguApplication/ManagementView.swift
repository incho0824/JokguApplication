import SwiftUI

struct ManagementView: View {
    @State private var keyCodes: [KeyCode] = []
    @State private var newCode: String = ""

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach($keyCodes) { $item in
                        TextField("Keycode", text: $item.code, onCommit: {
                            DatabaseManager.shared.updateKeyCode(id: item.id, code: item.code)
                        })
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let id = keyCodes[index].id
                            DatabaseManager.shared.deleteKeyCode(id: id)
                        }
                        keyCodes.remove(atOffsets: indexSet)
                    }
                }

                HStack {
                    TextField("New keycode", text: $newCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        if DatabaseManager.shared.insertKeyCode(newCode) {
                            loadData()
                            newCode = ""
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Management")
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        keyCodes = DatabaseManager.shared.fetchKeyCodes()
    }
}

#Preview {
    ManagementView()
}
