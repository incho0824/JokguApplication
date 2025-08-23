import SwiftUI

struct ManagementView: View {
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    let userPermit: Int
    @State private var keyCode = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, notification: "", playwhen: [], fee: 0, venmo: "")
    @State private var originalKeyCode = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, notification: "", playwhen: [], fee: 0, venmo: "")
    
    private var hasChanges: Bool {
        keyCode.code != originalKeyCode.code ||
        keyCode.address != originalKeyCode.address ||
        keyCode.welcome != originalKeyCode.welcome ||
        keyCode.youtube != originalKeyCode.youtube ||
        keyCode.notification != originalKeyCode.notification ||
        keyCode.fee != originalKeyCode.fee ||
        keyCode.venmo != originalKeyCode.venmo ||
        keyCode.playwhen != originalKeyCode.playwhen
    }
    
    @State private var showPayStatus = false
    private let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keycode").font(.caption)
                    TextField("Keycode", text: $keyCode.code)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Address").font(.caption)
                    TextField("Address", text: $keyCode.address)
                        .textContentType(.fullStreetAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome").font(.caption)
                    TextField("Welcome", text: $keyCode.welcome)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Youtube").font(.caption)
                    TextField("Youtube", text: Binding(
                        get: { keyCode.youtube?.absoluteString ?? "" },
                        set: { keyCode.youtube = URL(string: $0.lowercased()) }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notification").font(.caption)
                    TextField("Notification", text: $keyCode.notification)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Game day(s)").font(.caption)
                    ForEach(daysOfWeek, id: .self) { day in
                        Toggle(day, isOn: Binding(
                            get: { keyCode.playwhen.contains(day) },
                            set: { newValue in
                                if newValue {
                                    keyCode.playwhen.append(day)
                                } else {
                                    keyCode.playwhen.removeAll { $0 == day }
                                }
                                keyCode.playwhen = daysOfWeek.filter { keyCode.playwhen.contains($0) }
                            }
                        ))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fee").font(.caption)
                    TextField("Fee", value: $keyCode.fee, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                if userPermit == 9 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Venmo").font(.caption)
                        TextField("Venmo", text: $keyCode.venmo)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                Button("Membership") { showPayStatus = true }
                    .padding()
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
                        DatabaseManager.shared.updateManagement(id: keyCode.id, code: keyCode.code, address: keyCode.address, welcome: keyCode.welcome, youtube: keyCode.youtube, notification: keyCode.notification, playwhen: keyCode.playwhen, fee: keyCode.fee, venmo: keyCode.venmo)
                        originalKeyCode = keyCode
                        onSave?()
                    }
                    .disabled(!hasChanges)
                }
            }
            .onAppear { loadData() }
        }
        .sheet(isPresented: $showPayStatus) {
            PayStatusView(userPermit: userPermit)
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
    ManagementView(userPermit: 9)
}
