//
//  JokguApplicationApp.swift
//  JokguApplication
//
//  Created by In Cho on 8/20/25.
//

import SwiftUI
import UIKit
import UserNotifications
@main
struct JokguApplicationApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { _, _ in }
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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let today = formatter.string(from: Date())
        let badgeCount: Int
        if let management = DatabaseManager.shared.fetchManagementData().first,
           management.playwhen.contains(today) {
            badgeCount = 1
        } else {
            badgeCount = 0
        }
        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { _ in }
    }
}
