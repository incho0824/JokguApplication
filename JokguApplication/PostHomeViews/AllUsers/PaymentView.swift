import SwiftUI
import UIKit

struct PaymentView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    
    let phoneNumber: String
    @State private var fields: [Int] = Array(repeating: 0, count: 12)
    @State private var fee: Int = 0
    @State private var selectedIndices: Set<Int> = []
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 3)
    private let currentMonth = Calendar.current.component(.month, from: Date())
    private enum PaymentOption { case selected, due }
    private var isPayDisabled: Bool { amountToPay == 0 || venmoAccount.isEmpty }
    @State private var paymentSelection: PaymentOption = .selected
    @State private var venmoAccount: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<months.count, id: \.self) { index in
                            VStack {
                                Text(months[index])
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text("$\(fields[index])")
                                    .font(.title2)
                                    .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        fields[index] == fee
                                            ? Color.green.opacity(0.3)
                                            : selectedIndices.contains(index)
                                                ? Color.blue.opacity(0.3)
                                                : (index < currentMonth && fields[index] < fee
                                                    ? Color.red.opacity(0.3)
                                                    : Color.gray.opacity(0.1))
                                    )
                            )
                            .onTapGesture {
                                guard fields[index] < fee else { return }
                                if selectedIndices.contains(index) {
                                    selectedIndices.remove(index)
                                } else {
                                    selectedIndices.insert(index)
                                }
                            }
                        }
                    }
                    .padding()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: paymentSelection == .selected ? "largecircle.fill.circle" : "circle")
                        Text("Selected Amount = $\(selectedTotal)")
                        Spacer()
                    }
                    .onTapGesture { paymentSelection = .selected }
                    HStack {
                        Image(systemName: paymentSelection == .due ? "largecircle.fill.circle" : "circle")
                        Text("Due Amount = $\(dueTotal)")
                        Spacer()
                    }
                    .onTapGesture { paymentSelection = .due }
                }
                .font(.headline)
                .padding()

                Button(action: payWithVenmo) {
                    Text("Pay with Venmo")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPayDisabled ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                .disabled(isPayDisabled)
            }
            .navigationTitle("Payment")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear(perform: loadData)
        }
    }

    private var selectedTotal: Int {
        selectedIndices.reduce(0) { $0 + max(0, fee - fields[$1]) }
    }

    private var dueTotal: Int {
        let month = Calendar.current.component(.month, from: Date())
        let paid = fields.prefix(month).reduce(0, +)
        return max(0, month * fee - paid)
    }

    private var amountToPay: Int {
        paymentSelection == .selected ? selectedTotal : dueTotal
    }

    private func loadData() {
        Task {
            if let fetched = await DatabaseManager.shared.fetchUserFields(phoneNumber: phoneNumber) {
                var filled = Array(repeating: 0, count: 12)
                for i in 0..<min(fetched.count, 12) {
                    filled[i] = fetched[i]
                }
                await MainActor.run { fields = filled }
            }
            if let management = try? await DatabaseManager.shared.fetchManagementData().first {
                await MainActor.run {
                    fee = management.fee
                    venmoAccount = management.venmo
                }
            }
        }
    }

    private func payWithVenmo() {
        let dollars = Decimal(amountToPay)
        guard dollars > 0, !venmoAccount.isEmpty else { return }

        let handle = normalizeHandle(venmoAccount)
        let monthsSummary = monthNoteSummary()
        let base = "Jokgu fee for \(phoneNumber)"
        let note = monthsSummary.isEmpty ? base : "\(base) — \(monthsSummary)"

        guard let appURL = makeVenmoAppURL(recipient: handle, amount: dollars, note: note) else {
            openURL(venmoWebURL(for: handle))
            return
        }

        openURL(appURL) { opened in
            if !opened {
                openURL(venmoWebURL(for: handle))
            }
        }
    }

    private func normalizeHandle(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
    }

    private func makeVenmoAppURL(recipient: String, amount: Decimal, note: String?) -> URL? {
        var comps = URLComponents()
        comps.scheme = "venmo"
        comps.host   = "paycharge"
        var items = [
            URLQueryItem(name: "txn", value: "pay"),
            URLQueryItem(name: "recipients", value: recipient),
            URLQueryItem(name: "amount", value: amountString(amount))
        ]
        if let note, !note.isEmpty {
            items.append(URLQueryItem(name: "note", value: note))
        }
        comps.queryItems = items
        return comps.url
    }

    private func venmoWebURL(for recipient: String) -> URL {
        URL(string: "https://venmo.com/u/\(recipient)")!
    }

    private func amountString(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: d as NSDecimalNumber) ?? "0.00"
    }
    
    private func owingMonths(in indices: [Int]) -> [Int] {
        indices.filter { max(0, fee - fields[$0]) > 0 }.sorted()
    }

    private func monthsBeingPaid() -> [Int] {
        switch paymentSelection {
        case .selected:
            return owingMonths(in: Array(selectedIndices))
        case .due:
            return owingMonths(in: Array(0..<currentMonth))
        }
    }

    private func monthNoteSummary() -> String {
        let idxs = monthsBeingPaid()
        guard !idxs.isEmpty else { return "" }

        let contiguous = zip(idxs, idxs.dropFirst()).allSatisfy { $1 == $0 + 1 }
        let shortName: (Int) -> String = { i in String(months[i].prefix(3)) }

        if contiguous && idxs.count >= 3 {
            return "\(shortName(idxs.first!))–\(shortName(idxs.last!))"
        } else if idxs.count <= 3 {
            return idxs.map(shortName).joined(separator: ", ")
        } else {
            let head = idxs.prefix(2).map(shortName).joined(separator: ", ")
            return "\(head) … +\(idxs.count - 2) more"
        }
    }

}

#Preview {
    PaymentView(phoneNumber: "USER")
}
