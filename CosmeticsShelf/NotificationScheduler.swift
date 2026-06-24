import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private init() {}

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            assertionFailure("Notification authorization failed: \(error)")
        }
    }

    func scheduleReminder(for product: ProductItem) {
        guard let remindFromDate = product.remindFromDate else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = notificationIdentifier(for: product)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let fireDate = max(remindFromDate, Date().addingTimeInterval(10))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: fireDate)

        let content = UNMutableNotificationContent()
        content.title = "该优先使用了"
        content.body = "\(product.brand) \(product.name) 距离建议到期不到半年。"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelReminder(for product: ProductItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: product)]
        )
    }

    private func notificationIdentifier(for product: ProductItem) -> String {
        "expiry-\(product.id.uuidString)"
    }
}

