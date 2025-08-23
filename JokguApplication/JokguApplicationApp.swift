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
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                updateAppBadge()
            }
        }
    }

    private func updateAppBadge() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let today = formatter.string(from: Date())
        if let management = DatabaseManager.shared.fetchManagementData().first,
           management.playwhen.contains(today) {
            UIApplication.shared.applicationIconBadgeNumber = 1
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}
