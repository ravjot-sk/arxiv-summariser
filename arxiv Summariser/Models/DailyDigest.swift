import Foundation
import SwiftData

@Model
final class DailyDigest {
    /// Unique key per (day, category), e.g. "2026-05-28|cs.AI".
    @Attribute(.unique) var dayKey: String
    var date: Date
    var categoryID: String
    var summaryText: String
    var generatedByAI: Bool
    var papers: [ArxivPaper]
    /// True when no papers were submitted on this day for the category and the
    /// papers shown are the most-recent fallback (e.g. on weekends) rather than
    /// genuinely new today.
    var isFallback: Bool = false

    init(
        date: Date,
        categoryID: String,
        summaryText: String,
        generatedByAI: Bool,
        papers: [ArxivPaper],
        isFallback: Bool = false
    ) {
        self.date = date
        self.categoryID = categoryID
        self.summaryText = summaryText
        self.generatedByAI = generatedByAI
        self.papers = papers
        self.isFallback = isFallback
        self.dayKey = DailyDigest.makeDayKey(date: date, categoryID: categoryID)
    }

    var categoryDisplayName: String {
        ArxivCategory.displayName(for: categoryID)
    }

    static func makeDayKey(date: Date, categoryID: String) -> String {
        "\(Self.dayFormatter.string(from: date))|\(categoryID)"
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
