import SwiftUI

struct PaymentView: View {
    @Environment(\.dismiss) var dismiss
    let username: String
    @State private var fields: [Int] = Array(repeating: 0, count: 12)
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(0..<months.count, id: \.self) { index in
                        VStack {
                            Text(months[index])
                                .font(.headline)
                            Text("\(fields[index])")
                                .font(.title2)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)))
                    }
                }
                .padding()
            }
            .navigationTitle("Payment")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear(perform: loadFields)
        }
    }

    private func loadFields() {
        if let fetched = DatabaseManager.shared.fetchUserFields(username: username) {
            var filled = Array(repeating: 0, count: 12)
            for i in 0..<min(fetched.count, 12) {
                filled[i] = fetched[i]
            }
            fields = filled
        }
    }
}

#Preview {
    PaymentView(username: "USER")
}
