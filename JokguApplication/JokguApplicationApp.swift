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
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                scheduleNextPlayDayAlert()
            }
        }
    }

    private func scheduleNextPlayDayAlert() {
        guard let playDays = databaseManager.management?.playwhen, !playDays.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = "noonAlert"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let now = Date()

        for offset in 0..<7 {
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: now) else { continue }
            let dayName = formatter.string(from: date)
            guard playDays.contains(dayName) else { continue }

            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 12
            components.minute = 0

            guard let triggerDate = Calendar.current.date(from: components), triggerDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Reminder"
            content.body = "Game day today!"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
            break
        }
    }
}
