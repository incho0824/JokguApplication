import SwiftUI
import UIKit

struct PayStatusView: View {
    @Environment(\.dismiss) var dismiss
    let userPermit: Int
    @State private var members: [Member] = []
    @State private var userFields: [String: [String]] = [:]
    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false
    @State private var fee: Int = 0
    private let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack {
                    HStack(spacing: 0) {
                        leftColumn()
                        ScrollView(.horizontal) {
                            VStack(alignment: .leading, spacing: 0) {
                                headerRow()
                                ForEach(0..<months.count, id: \.self) { index in
                                    rowView(for: index)
                                }
                            }
                        }
                    }
                    Button("Download") { downloadCSV() }
                        .padding()
                }
            }
            .navigationTitle("Membership")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
                if userPermit == 9 || userPermit == 2 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink("Order") {
                            ReorderMembersView()
                        }
                    }
                }
            }
            .onAppear { loadData() }
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportURL = exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    private func headerRow() -> some View {
        HStack(spacing: 0) {
            ForEach(members) { member in
                Text("\(member.lastName) \(member.firstName)")
                    .frame(width: 120, height: 40)
                    .background(Color.gray.opacity(0.2))
                    .border(Color.gray)
            }
        }
    }

    private func rowView(for monthIndex: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(members) { member in
                let binding = Binding<String>(
                    get: {
                        let fields = userFields[member.username] ?? Array(repeating: "", count: months.count)
                        return monthIndex < fields.count ? fields[monthIndex] : ""
                    },
                    set: { newValue in
                        guard userPermit == 9 || userPermit == 2 else { return }
                        var fields = userFields[member.username] ?? Array(repeating: "", count: months.count)
                        if fields.count < months.count {
                            fields += Array(repeating: "", count: months.count - fields.count)
                        }
                        fields[monthIndex] = newValue
                        userFields[member.username] = fields
                        let intFields = fields.map { Int($0) ?? 0 }
                        _ = DatabaseManager.shared.saveUserFields(username: member.username, fields: intFields)
                    }
                )
                TextField("-", text: binding)
                    .frame(width: 120, height: 40)
                    .multilineTextAlignment(.center)
                    .background((Int(binding.wrappedValue) ?? 0) >= fee ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                    .border(Color.gray)
                    .keyboardType(.numberPad)
                    .disabled(!(userPermit == 9 || userPermit == 2))
            }
        }
    }

    private func leftColumn() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("")
                .frame(width: 80, height: 40, alignment: .center)
                .border(Color.gray)
            ForEach(0..<months.count, id: \.self) { index in
                Text(months[index])
                    .frame(width: 80, height: 40, alignment: .center)
                    .multilineTextAlignment(.center)
                    .border(Color.gray)
            }
        }
    }

    private func loadData() {
        Task {
            do {
                let fetched = try await DatabaseManager.shared.fetchMembers()
                let filtered = fetched.filter { $0.guest == 1 }
                var dict: [String: [String]] = [:]
                for member in filtered {
                    if let values = await DatabaseManager.shared.fetchUserFields(username: member.username) {
                        var strings = values.map { String($0) }
                        if strings.count < months.count {
                            strings += Array(repeating: "", count: months.count - strings.count)
                        }
                        dict[member.username] = strings
                    } else {
                        dict[member.username] = Array(repeating: "", count: months.count)
                    }
                }
                let managements = try await DatabaseManager.shared.fetchManagementData()
                await MainActor.run {
                    members = filtered
                    userFields = dict
                    if let management = managements.first {
                        fee = management.fee
                    }
                }
            } catch {
                // ignore errors
            }
        }
    }

    private func downloadCSV() {
        var csv = "," + members.map { "\($0.lastName) \($0.firstName)" }.joined(separator: ",") + "\n"
        for monthIndex in 0..<months.count {
            var row = months[monthIndex]
            for member in members {
                let fields = userFields[member.username] ?? Array(repeating: "", count: months.count)
                let value = monthIndex < fields.count ? fields[monthIndex] : ""
                row += ",\(value)"
            }
            csv += row + "\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PayStatus.csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showShareSheet = true
        } catch {
            print("Failed to write CSV file")
        }
    }
}

#Preview {
    PayStatusView(userPermit: 9)
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
