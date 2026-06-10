import Foundation
import BackgroundTasks
import SwiftData

enum BackgroundRefreshManager {
    static let taskIdentifier = "com.ravjotsinghkohli.arxiv-Summariser.dailyDigest"

    /// Register the background task handler. Call once at launch.
    static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: refreshTask, modelContainer: modelContainer)
        }
    }

    /// Schedule the next refresh for the user's preferred morning time.
    static func schedule(hour: Int, minute: Int) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextRunDate(hour: hour, minute: minute)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func nextRunDate(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let now = Date.now
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        let candidate = cal.date(from: comps) ?? now
        return candidate > now ? candidate : cal.date(byAdding: .day, value: 1, to: candidate) ?? now.addingTimeInterval(86_400)
    }

    private static func handle(task: BGAppRefreshTask, modelContainer: ModelContainer) {
        let work = Task { @MainActor in
            let context = ModelContext(modelContainer)
            let selected = (try? context.fetch(FetchDescriptor<SelectedTopics>()))?.first
            let categoryIDs = selected?.categoryIDs ?? []
            let notificationsEnabled = selected?.notificationsEnabled ?? false

            let builder = DigestBuilder(modelContext: context)
            let count = await builder.buildToday(categoryIDs: categoryIDs)

            if notificationsEnabled {
                await NotificationManager.shared.postDigestReady(topicsWithPapers: count)
            }

            // Reschedule for tomorrow.
            if let selected {
                schedule(hour: selected.notificationHour, minute: selected.notificationMinute)
            }
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
