import SwiftUI

struct PaymentView: View {
    @Environment(\.dismiss) var dismiss
    let username: String
    @State private var fields: [Int] = Array(repeating: 0, count: 12)
    @State private var fee: Int = 0
    @State private var selectedIndices: Set<Int> = []
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        NavigationView {
            VStack {
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
                                    .fill(selectedIndices.contains(index) ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
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
                }
                Text("Selected amount = $\(selectedTotal)")
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
