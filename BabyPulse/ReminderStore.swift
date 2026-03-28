//
//  ReminderStore.swift
//  BabyPulse
//
//  Created by Codex on 2026/3/28.
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class ReminderStore: ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var feedRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(feedRemindersEnabled, forKey: feedReminderKey)
        }
    }
    @Published var sleepCheckEnabled: Bool {
        didSet {
            UserDefaults.standard.set(sleepCheckEnabled, forKey: sleepReminderKey)
        }
    }
    @Published var feedReminderHours: Int {
        didSet {
            UserDefaults.standard.set(feedReminderHours, forKey: feedReminderHoursKey)
        }
    }
    @Published var sleepCheckMinutes: Int {
        didSet {
            UserDefaults.standard.set(sleepCheckMinutes, forKey: sleepReminderMinutesKey)
        }
    }

    private let center = UNUserNotificationCenter.current()
    private let feedReminderKey = "BabyPulse.feedRemindersEnabled"
    private let sleepReminderKey = "BabyPulse.sleepCheckEnabled"
    private let feedReminderHoursKey = "BabyPulse.feedReminderHours"
    private let sleepReminderMinutesKey = "BabyPulse.sleepCheckMinutes"

    private let feedReminderIdentifier = "BabyPulse.feedReminder"
    private let sleepCheckIdentifier = "BabyPulse.sleepCheck"

    init() {
        let defaults = UserDefaults.standard
        self.feedRemindersEnabled = defaults.object(forKey: feedReminderKey) as? Bool ?? false
        self.sleepCheckEnabled = defaults.object(forKey: sleepReminderKey) as? Bool ?? false

        let savedFeedHours = defaults.integer(forKey: feedReminderHoursKey)
        self.feedReminderHours = savedFeedHours == 0 ? 3 : savedFeedHours

        let savedSleepMinutes = defaults.integer(forKey: sleepReminderMinutesKey)
        self.sleepCheckMinutes = savedSleepMinutes == 0 ? 90 : savedSleepMinutes
    }

    func refreshAuthorizationStatus() {
        Task {
            let settings = await center.notificationSettings()
            await MainActor.run {
                authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus
            return granted
        } catch {
            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus
            return false
        }
    }

    func syncNotifications(using store: BabyStore, hasPro: Bool) {
        guard hasPro else {
            cancelAllNotifications()
            return
        }

        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            cancelAllNotifications()
            return
        }

        Task {
            if feedRemindersEnabled, let lastFeed = store.lastFeed {
                await scheduleFeedReminder(from: lastFeed.date)
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [feedReminderIdentifier])
            }

            if sleepCheckEnabled, let activeSleepStart = store.activeSleepStart {
                await scheduleSleepCheck(from: activeSleepStart)
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [sleepCheckIdentifier])
            }
        }
    }

    func cancelAllNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [feedReminderIdentifier, sleepCheckIdentifier])
    }

    var authorizationDescription: String {
        switch authorizationStatus {
        case .authorized:
            "Notifications enabled"
        case .provisional:
            "Notifications provisionally enabled"
        case .denied:
            "Notifications denied in Settings"
        case .ephemeral:
            "Notifications temporarily enabled"
        case .notDetermined:
            "Notifications not enabled yet"
        @unknown default:
            "Notification status unavailable"
        }
    }

    private func scheduleFeedReminder(from lastFeedDate: Date) async {
        let interval = max(60, TimeInterval(feedReminderHours * 60 * 60))
        let content = UNMutableNotificationContent()
        content.title = "BabyPulse Pro Feed Reminder"
        content.body = "It has been \(feedReminderHours) hours since the last logged feed."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: nextTimeInterval(from: lastFeedDate, duration: interval),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: feedReminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [feedReminderIdentifier])
        try? await center.add(request)
    }

    private func scheduleSleepCheck(from sleepStart: Date) async {
        let interval = max(60, TimeInterval(sleepCheckMinutes * 60))
        let content = UNMutableNotificationContent()
        content.title = "BabyPulse Pro Sleep Check"
        content.body = "Sleep has been active for \(sleepCheckMinutes) minutes. Check in if needed."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: nextTimeInterval(from: sleepStart, duration: interval),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: sleepCheckIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [sleepCheckIdentifier])
        try? await center.add(request)
    }

    private func nextTimeInterval(from referenceDate: Date, duration: TimeInterval) -> TimeInterval {
        let targetDate = referenceDate.addingTimeInterval(duration)
        return max(60, targetDate.timeIntervalSinceNow)
    }
}
