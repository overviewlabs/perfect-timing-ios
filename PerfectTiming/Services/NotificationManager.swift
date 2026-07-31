import SwiftUI
import UserNotifications

@MainActor final class NotificationManager: ObservableObject {
  @Published private(set) var authorized = false
  func request() async -> Bool {
    do {
      authorized = try await UNUserNotificationCenter.current().requestAuthorization(options: [
        .alert, .sound, .badge,
      ])
      if authorized { schedule() }
      return authorized
    } catch { return false }
  }
  func schedule() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["daily.challenge", "daily.reward"])
    let reminders: [(String, Int, String, String)] = [
      (
        "daily.challenge", 18, "Your daily timing challenge is ready",
        "Set today’s score in Don’t Tap Yet!"
      ),
      (
        "daily.reward", 12, "Timing Coins are waiting", "Claim today’s reward and keep your streak."
      ),
    ]
    for (id, hour, title, body) in reminders {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      var date = DateComponents()
      date.hour = hour
      center.add(
        UNNotificationRequest(
          identifier: id, content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true)))
    }
  }
  func disable() {
    authorized = false
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
  }
}
