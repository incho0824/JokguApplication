import SwiftUI

struct ManagementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showPayStatus = false

    var body: some View {
        NavigationView {
            VStack {
                Button("Membership") { showPayStatus = true }
                    .padding()
                Spacer()
            }
            .navigationTitle("Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showPayStatus) {
            PayStatusView()
        }
    }
}

#Preview {
    ManagementView()
}
