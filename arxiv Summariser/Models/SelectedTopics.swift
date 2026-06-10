import Foundation
import SwiftData

@Model
final class SelectedTopics {
    var categoryIDs: [String]
    var notificationsEnabled: Bool
    var notificationHour: Int
    var notificationMinute: Int
    var hasCompletedOnboarding: Bool
    var appearanceRawValue: String = AppAppearance.system.rawValue

    init(
        categoryIDs: [String] = [],
        notificationsEnabled: Bool = true,
        notificationHour: Int = 8,
        notificationMinute: Int = 0,
        hasCompletedOnboarding: Bool = false,
        appearance: AppAppearance = .system
    ) {
        self.categoryIDs = categoryIDs
        self.notificationsEnabled = notificationsEnabled
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.appearanceRawValue = appearance.rawValue
    }

    var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRawValue) ?? .system }
        set { appearanceRawValue = newValue.rawValue }
    }

    var hasSelection: Bool { !categoryIDs.isEmpty }
}
