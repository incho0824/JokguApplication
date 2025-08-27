//
//  JokguApplicationApp.swift
//  JokguApplication
//
//  Created by In Cho on 8/20/25.
//

import SwiftUI
import UIKit
import UserNotifications
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate { //UIResponder
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct JokguApplicationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
        updateAppBadge()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                updateAppBadge()
            }
        }
    }

    private func updateAppBadge() {
        Task {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let today = formatter.string(from: Date())
            let badgeCount: Int
            do {
                let managements = try await DatabaseManager.shared.fetchManagementData()
                if let management = managements.first, management.playwhen.contains(today) {
                    badgeCount = 1
                } else {
                    badgeCount = 0
                }
            } catch {
                badgeCount = 0
            }
            UNUserNotificationCenter.current().setBadgeCount(badgeCount) { _ in }
            scheduleNoonAlertIfNeeded(badgeCount: badgeCount)
        }
    }

    private func scheduleNoonAlertIfNeeded(badgeCount: Int) {
        let center = UNUserNotificationCenter.current()
        let identifier = "noonAlert"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard badgeCount == 1 else { return }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 12
        dateComponents.minute = 0

        guard let triggerDate = Calendar.current.date(from: dateComponents),
              triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = "Game day today!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
}
