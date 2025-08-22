import SwiftUI

struct PaymentView: View {
    @Environment(\.dismiss) var dismiss

    private let venmoURL = URL(string: "https://venmo.com/atlanta-jokgu")!

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Support the club via Venmo")
                    .font(.title3)
                Link("Pay with Venmo", destination: venmoURL)
                    .padding()
            }
            .navigationTitle("Payment")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PaymentView()
}
