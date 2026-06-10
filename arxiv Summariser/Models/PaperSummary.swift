import Foundation
import SwiftData

/// A cached, on-device per-paper summary. Generated once per paper (keyed by arXiv id)
/// and reused to build the dynamic overview, so filtering only re-runs a cheap reduce
/// over these short texts instead of re-reading every abstract.
@Model
final class PaperSummary {
    @Attribute(.unique) var paperID: String
    var summaryText: String
    var generatedByAI: Bool
    var createdAt: Date

    init(paperID: String, summaryText: String, generatedByAI: Bool, createdAt: Date = .now) {
        self.paperID = paperID
        self.summaryText = summaryText
        self.generatedByAI = generatedByAI
        self.createdAt = createdAt
    }
}
