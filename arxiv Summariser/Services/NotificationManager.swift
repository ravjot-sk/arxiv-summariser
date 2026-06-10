import Foundation
import UserNotifications

struct NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Post an immediate notification that the digest is ready (used after a background build).
    func postDigestReady(topicsWithPapers: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Your arXiv digest is ready"
        content.body = topicsWithPapers > 0
            ? "New research summarized across \(topicsWithPapers) topic\(topicsWithPapers == 1 ? "" : "s")."
            : "We checked your topics — no new papers today."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "digest-ready-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
