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
                .onChange(of: databaseManager.management?.playwhen) { _, _ in
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
        let calendar = Calendar.current
        let now = Date()
        let weekdaySymbols = calendar.weekdaySymbols

        var nextDate: Date? = nil
        if let playwhen = databaseManager.management?.playwhen {
            for day in playwhen {
                if let index = weekdaySymbols.firstIndex(of: day) {
                    var components = DateComponents()
                    components.weekday = index + 1
                    components.hour = 12
                    components.minute = 0
                    if let candidate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                        if nextDate == nil || candidate < nextDate! {
                            nextDate = candidate
                        }
                    }
                }
            }
        }

        let badgeCount = (nextDate != nil && calendar.isDateInToday(nextDate!)) ? 1 : 0
        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { _ in }
        scheduleNextGameAlert(for: nextDate)
    }

    private func scheduleNextGameAlert(for date: Date?) {
        let center = UNUserNotificationCenter.current()
        let identifier = "noonAlert"
        let defaults = UserDefaults.standard

        guard let date = date else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            defaults.removeObject(forKey: "scheduledGameDate")
            return
        }

        if let stored = defaults.object(forKey: "scheduledGameDate") as? Date,
           Calendar.current.isDate(stored, equalTo: date, toGranularity: .minute) {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = "Game day today!"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
        defaults.set(date, forKey: "scheduledGameDate")
    }
}
