import SwiftUI

struct ManagementView: View {
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    let userPermit: Int
    @State private var keyCode = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, kakao: nil, notification: "", playwhen: [], fee: 0, venmo: "")
    @State private var originalKeyCode = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, kakao: nil, notification: "", playwhen: [], fee: 0, venmo: "")
    @State private var showDayPicker = false
    
    private var hasChanges: Bool {
        keyCode.code != originalKeyCode.code ||
        keyCode.address != originalKeyCode.address ||
        keyCode.welcome != originalKeyCode.welcome ||
        keyCode.youtube != originalKeyCode.youtube ||
        keyCode.kakao != originalKeyCode.kakao ||
        keyCode.notification != originalKeyCode.notification ||
        keyCode.playwhen != originalKeyCode.playwhen ||
        keyCode.fee != originalKeyCode.fee ||
        keyCode.venmo != originalKeyCode.venmo
    }
    
    @State private var showPayStatus = false
    
    var body: some View {
        NavigationView {
            ScrollView {
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
                        Text("Kakao").font(.caption)
                        TextField("Kakao", text: Binding(
                            get: { keyCode.kakao?.absoluteString ?? "" },
                            set: { keyCode.kakao = URL(string: $0.lowercased()) }
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
                        Button(action: { showDayPicker = true }) {
                            HStack {
                                if keyCode.playwhen.isEmpty {
                                    Text("Select days").foregroundColor(.gray)
                                } else {
                                    ForEach(keyCode.playwhen, id: \.self) { day in
                                        Text(day)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.5)))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fee").font(.caption)
                        TextField("Fee", value: $keyCode.fee, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    if userPermit == 9 || userPermit == 2 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Venmo").font(.caption)
                            TextField("Venmo", text: $keyCode.venmo)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    Button("Membership") { showPayStatus = true }
                        .padding()
                }
                .padding()
            }
            .navigationTitle("Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        DatabaseManager.shared.updateManagement(id: keyCode.id, code: keyCode.code, address: keyCode.address, welcome: keyCode.welcome, youtube: keyCode.youtube, kakao: keyCode.kakao, notification: keyCode.notification, playwhen: keyCode.playwhen, fee: keyCode.fee, venmo: keyCode.venmo)
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
        .sheet(isPresented: $showDayPicker) {
            DaySelectionView(selectedDays: $keyCode.playwhen)
        }
    }
    

    private func loadData() {
        if let item = DatabaseManager.shared.fetchManagementData().first {
            keyCode = item
            originalKeyCode = item
        }
    }
}

struct DaySelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDays: [String]
    private let days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]

    var body: some View {
        NavigationView {
            List {
                ForEach(days, id: \.self) { day in
                    MultipleSelectionRow(day: day, isSelected: selectedDays.contains(day)) {
                        if let index = selectedDays.firstIndex(of: day) {
                            selectedDays.remove(at: index)
                        } else {
                            selectedDays.append(day)
                            selectedDays.sort { days.firstIndex(of: $0)! < days.firstIndex(of: $1)! }
                        }
                    }
                }
            }
            .navigationTitle("Game Days")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MultipleSelectionRow: View {
    var day: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(day)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

#Preview {
    ManagementView(userPermit: 9)
}
