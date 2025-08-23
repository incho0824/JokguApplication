import SwiftUI
import Foundation
import UIKit

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var username: String
    @Environment(\.scenePhase) private var scenePhase
    @State private var showManagement = false
    @State private var showMembers = false
    @State private var showLineup = false
    @State private var showProfile = false
    @State private var showPayment = false
    @State private var management = KeyCode(id: 0, code: "", address: "", welcome: "", youtube: nil, notification: "", playwhen: [], fee: 0, venmo: "")
    @State private var showTodayPrompt = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.85, blue: 0.7),
                    Color(red: 1.0, green: 0.65, blue: 0.45)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Text("Atlanta Jokgu Association")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 40)
                        .padding(.horizontal)

                    Text(management.notification)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                        .padding(.horizontal)

                    Button {
                        showLineup = true
                    } label: {
                        Label("Today's Lineup", systemImage: "list.bullet")
                    }
                    .buttonStyle(HomeButtonStyle())
                    .sheet(isPresented: $showLineup) {
                        LineupView(username: username)
                    }
                    .padding(.horizontal)

                    Button {
                        showMembers = true
                    } label: {
                        Label("Members", systemImage: "person.3")
                    }
                    .buttonStyle(HomeButtonStyle())
                    .sheet(isPresented: $showMembers) {
                        MemberView(userPermit: userPermit)
                    }
                    .padding(.horizontal)

                    Button {
                        showProfile = true
                    } label: {
                        Label("Profile", systemImage: "person.circle")
                    }
                    .buttonStyle(HomeButtonStyle())
                    .sheet(isPresented: $showProfile) {
                        ProfileView(username: username)
                    }
                    .padding(.horizontal)

                    Button {
                        showPayment = true
                    } label: {
                        Label("Payment", systemImage: "creditcard")
                    }
                    .buttonStyle(HomeButtonStyle())
                    .sheet(isPresented: $showPayment) {
                        PaymentView(username: username)
                    }
                    .padding(.horizontal)

                    if userPermit > 0 {
                        Button {
                            showManagement = true
                        } label: {
                            Label("Management", systemImage: "gearshape")
                        }
                        .buttonStyle(HomeButtonStyle())
                        .sheet(isPresented: $showManagement, onDismiss: loadManagement) {
                            ManagementView(userPermit: userPermit)
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        username = ""
                        isLoggedIn = false
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(HomeButtonStyle())
                    .padding(.top, 10)
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            UIApplication.shared.applicationIconBadgeNumber = 0
            loadManagement()
            performDailyResetIfNeeded()
            checkTodayStatus()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
        .todayPrompt(isPresented: $showTodayPrompt, username: username)
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
        if management.playwhen.contains(todayName),
           let user = DatabaseManager.shared.fetchUser(username: username),
           user.today == 0 {
            showTodayPrompt = true
        }
    }

}

private struct HomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(configuration.isPressed ? 0.6 : 0.9))
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

#Preview {
    HomeView(isLoggedIn: .constant(true), userPermit: .constant(1), username: .constant("USER"))
}
