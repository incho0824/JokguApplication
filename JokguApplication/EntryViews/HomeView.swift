import SwiftUI
import Foundation

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var username: String
    @State private var showManagement = false
    @State private var showMembers = false
    @State private var showLineup = false
    @State private var showProfile = false
    @State private var showPayment = false
    @State private var management = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, notification: "", playwhen: [], fee: 0, venmo: "")
    @State private var showTodayPrompt = false

    var body: some View {
        VStack {
            Text("Atlanta Jokgu Association")
                .font(.title)
                .padding()

            Text(management.notification)
                .padding(.vertical)
                .padding(.bottom, 20)

            Button("Today's Lineup") {
                showLineup = true
            }
            .padding()
            .sheet(isPresented: $showLineup) {
                LineupView()
            }

            Button("Members") {
                showMembers = true
            }
            .padding()
            .sheet(isPresented: $showMembers) {
                MemberView(userPermit: userPermit)
            }

            Button("Profile") {
                showProfile = true
            }
            .padding()
            .sheet(isPresented: $showProfile) {
                ProfileView(username: username)
            }

            Button("Payment") {
                showPayment = true
            }
            .padding()
            .sheet(isPresented: $showPayment) {
                PaymentView(username: username)
            }

            if userPermit > 0 {
                Button("Management") {
                    showManagement = true
                }
                .padding()
                .sheet(isPresented: $showManagement, onDismiss: loadManagement) {
                    ManagementView(userPermit: userPermit)
                }
            }

            Button("Logout") {
                username = ""
                isLoggedIn = false
            }
            .padding()

            Spacer()
        }
        .onAppear {
            loadManagement()
            performDailyResetIfNeeded()
            checkTodayStatus()
        }
        .alert("Jokgu Today—YOU IN?", isPresented: $showTodayPrompt) {
            Button("Yes") {
                DatabaseManager.shared.updateToday(username: username, value: 1)
                showTodayPrompt = false
            }
            Button("No") {
                DatabaseManager.shared.updateToday(username: username, value: 2)
                showTodayPrompt = false
            }
        }
    }

    private func loadManagement() {
        if let item = DatabaseManager.shared.fetchManagementData().first {
            management = item
        }
    }

    private func performDailyResetIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        let defaults = UserDefaults.standard
        let lastReset = defaults.string(forKey: "lastTodayReset")
        if lastReset != todayString {
            DatabaseManager.shared.resetTodayForAll()
            defaults.set(todayString, forKey: "lastTodayReset")
        }
    }

    private func checkTodayStatus() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let todayName = formatter.string(from: Date())
        if management.playwhen.contains(todayName) {
            if let user = DatabaseManager.shared.fetchUser(username: username), user.today == 0 {
                showTodayPrompt = true
            }
        }
    }

}

#Preview {
    HomeView(isLoggedIn: .constant(true), userPermit: .constant(1), username: .constant("USER"))
}
