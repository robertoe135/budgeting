import Foundation
// UNUserNotificationCenter's completion-handler APIs predate Swift's Sendable checking, so its
// closures trip @MainActor capture warnings even though they're safe in practice; @preconcurrency
// tells the compiler to trust this framework's (pre-concurrency) API surface, per Xcode's own fix-it.
@preconcurrency import UserNotifications

/// Schedules and sends the app's local (in-phone) spending notifications. No backend is
/// involved — everything is computed on-device from the user's manually-logged transactions.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    /// Call after any transaction change to react immediately to a newly-crossed threshold.
    /// Each alert is only sent once per week (deduplicated by week-start date in the identifier).
    func evaluateWeeklyStatus(_ status: BudgetEngine.WeeklyStatus, settings: BudgetSettings) {
        guard settings.notificationsEnabled else { return }

        if status.isOverLimit, settings.notifyAtOverLimit {
            send(
                id: "weekly-over-\(weekKey(status.week.start))",
                title: "Over your weekly spending limit",
                body: "You've spent \(status.spent.formattedCurrency) of your \(status.limit.formattedCurrency) limit this week."
            )
        } else if status.percentUsed >= 0.8, settings.notifyAt80Percent {
            send(
                id: "weekly-80-\(weekKey(status.week.start))",
                title: "Approaching your weekly limit",
                body: "You've used \(Int(status.percentUsed * 100))% of this week's \(status.limit.formattedCurrency) budget."
            )
        }
    }

    /// Schedules a repeating reminder that fires at the start of every new budgeting week.
    func scheduleWeeklyResetReminder(weekStartsMonday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-reset"])

        var components = DateComponents()
        components.weekday = weekStartsMonday ? 2 : 1
        components.hour = 9
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "New budgeting week"
        content.body = "Your weekly spending limit has reset. Fresh start!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-reset", content: content, trigger: trigger)
        center.add(request)
    }

    private func send(id: String, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            guard !pending.contains(where: { $0.identifier == id }) else { return }
            center.getDeliveredNotifications { delivered in
                guard !delivered.contains(where: { $0.request.identifier == id }) else { return }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
                center.add(request)
            }
        }
    }

    private func weekKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
