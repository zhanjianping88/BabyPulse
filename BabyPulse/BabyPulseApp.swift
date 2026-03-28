//
//  BabyPulseApp.swift
//  BabyPulse
//
//  Created by 建平 on 2026/3/26.
//

import SwiftUI

@main
struct BabyPulseApp: App {
    @StateObject private var store = BabyStore()
    @StateObject private var entitlementStore = EntitlementStore()
    @StateObject private var reminderStore = ReminderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(entitlementStore)
                .environmentObject(reminderStore)
        }
    }
}
