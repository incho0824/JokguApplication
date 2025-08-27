//
//  JokguApplicationApp.swift
//  JokguApplication
//
//  Created by In Cho on 8/20/25.
//

import SwiftUI
import UserNotifications

@main
struct JokguApplicationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var databaseManager = DatabaseManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseManager)
                .onAppear {
                    updateAppBadge()
                }
                .onChange(of: databaseManager.management?.id) { _, _ in
                    updateAppBadge()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                updateAppBadge()
            }
        }
    }

    private func updateAppBadge() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let today = formatter.string(from: Date())
        let badgeCount = (databaseManager.management?.playwhen.contains(today) == true) ? 1 : 0
        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { _ in }
        scheduleNoonAlertIfNeeded(badgeCount: badgeCount)
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
