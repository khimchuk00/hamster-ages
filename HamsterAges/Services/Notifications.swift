import Foundation
import UserNotifications

/// Local re-engagement reminders (no server). Permission is asked after the first win, not at launch —
/// players who already enjoyed a battle opt in far more often.
@MainActor
enum Reminders {
    private static let center = UNUserNotificationCenter.current()
    private static let enabledKey = "hamsterages.remindersEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if !newValue { center.removeAllPendingNotificationRequests() }
        }
    }

    static func requestPermissionIfNeeded() {
        guard isEnabled else { return }   // player switched reminders off in Settings: never prompt
        Task {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Rebuilds all pending reminders from current progress. Call when the app goes to background.
    static func reschedule(progress p: PlayerProgress) {
        center.removeAllPendingNotificationRequests()
        guard isEnabled, p.tutorialDone == true else { return }

        // 1. Seed farm full.
        if let last = p.lastFarmCollect {
            let full = last.addingTimeInterval(SeedFarm.capHours * 3600)
            if full > .now.addingTimeInterval(600) {
                schedule(id: "farm_full", at: full,
                         title: L10n.t("Your Seed Farm is full! 🌻"),
                         body: L10n.f("%lld seeds are waiting. Collect them before the hamsters eat them all.", SeedFarm.capacity(highestStage: p.highestStage)))
            }
        }

        // 2. Tomorrow evening: daily reward + fresh quests.
        let cal = Calendar.current
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: .now),
           let evening = cal.date(bySettingHour: 18, minute: 30, second: 0, of: tomorrow) {
            schedule(id: "daily", at: evening,
                     title: L10n.t("New daily quests are up!"),
                     body: L10n.f("Claim your daily seeds and push past Stage %lld. The rats are getting bold…", p.stage))
        }

        // 3. Lapsed player nudge (3 days).
        if let later = cal.date(byAdding: .day, value: 3, to: .now),
           let noon = cal.date(bySettingHour: 12, minute: 15, second: 0, of: later) {
            schedule(id: "lapsed", at: noon,
                     title: L10n.t("The rat army is marching on your base 🐀"),
                     body: L10n.t("Your hamsters need their commander. A free crate might be waiting!"))
        }
    }

    private static func schedule(id: String, at date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
