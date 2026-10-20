import AppKit
import Observation
import UserNotifications

/// Posts system notifications. Sounds are played by the app itself so they work
/// even when notification permission is denied.
@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshStatus() }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshStatus()
        return granted
    }

    func refreshStatus() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    // Show banners even though the app counts as frontmost while the notch panel is up.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
