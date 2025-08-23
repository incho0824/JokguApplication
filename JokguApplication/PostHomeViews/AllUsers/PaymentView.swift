import SwiftUI

struct PaymentView: View {
    @Environment(\.dismiss) var dismiss
    let username: String
    @State private var fields: [Int] = Array(repeating: 0, count: 12)
    @State private var fee: Int = 0
    @State private var selectedIndices: Set<Int> = []
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 3)
    private let currentMonth = Calendar.current.component(.month, from: Date())
    private enum PaymentOption { case selected, due }
    @State private var paymentSelection: PaymentOption = .selected

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

    private func loadData() {
        if let fetched = DatabaseManager.shared.fetchUserFields(username: username) {
            var filled = Array(repeating: 0, count: 12)
            for i in 0..<min(fetched.count, 12) {
                filled[i] = fetched[i]
            }
            fields = filled
        }
        if let management = DatabaseManager.shared.fetchManagementData().first {
            fee = management.fee
        }
    }
}

#Preview {
    PaymentView(username: "USER")
}
