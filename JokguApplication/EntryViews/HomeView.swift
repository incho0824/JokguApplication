import SwiftUI
import Foundation
import UIKit
import UserNotifications
import FirebaseAuth

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userPermit: Int
    @Binding var username: String
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var showManagement = false
    @State private var showMembers = false
    @State private var showLineup = false
    @State private var showProfile = false
    @State private var showPayment = false
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

                    if let notice = databaseManager.management?.notification {
                        Text(formatNotification(notice))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

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
                        .sheet(isPresented: $showManagement) {
                            ManagementView(userPermit: userPermit)
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        try? Auth.auth().signOut()
                        KeychainManager.shared.delete("loggedInUser")
                        KeychainManager.shared.delete("userPermit")
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
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            checkTodayStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            }
        }
        .onChange(of: databaseManager.management?.id) { _, _ in
            checkTodayStatus()
        }
        .todayPrompt(isPresented: $showTodayPrompt, username: username)
    }

    private func formatNotification(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]
        while let start = remaining.range(of: "**") {
            let before = remaining[..<start.lowerBound]
            var normal = AttributedString(String(before))
            normal.foregroundColor = .white
            result += normal
            let afterStart = remaining[start.upperBound...]
            guard let end = afterStart.range(of: "**") else {
                var rest = AttributedString(String(afterStart))
                rest.foregroundColor = .white
                result += rest
                return result
            }
            let address = String(afterStart[..<end.lowerBound])
            if let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                var link = AttributedString(address)
                link.link = url
                link.foregroundColor = .blue
                result += link
            } else {
                var textPart = AttributedString(address)
                textPart.foregroundColor = .white
                result += textPart
            }
            remaining = afterStart[end.upperBound...]
        }
        var tail = AttributedString(String(remaining))
        tail.foregroundColor = .white
        result += tail
        return result
    }

    private func checkTodayStatus() {
        Task {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let todayName = formatter.string(from: Date())
            if let management = databaseManager.management,
               management.playwhen.contains(todayName),
               let user = try? await DatabaseManager.shared.fetchUser(username: username),
               user.today == 0 {
                await MainActor.run { showTodayPrompt = true }
            }
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
        .environmentObject(DatabaseManager.shared)
}
