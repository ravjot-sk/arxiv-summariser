import Foundation
import SwiftData

/// Incremental progress for a digest build, surfaced to the UI so it can show
/// how far along fetching/summarizing is.
struct DigestBuildProgress: Equatable {
    enum Phase: Equatable { case fetching, summarizing }
    /// Topics fully processed so far.
    var completed: Int
    var total: Int
    /// The category currently being worked on (nil when wrapping up).
    var currentCategory: String?
    var phase: Phase

    var fraction: Double {
        total > 0 ? min(1, Double(completed) / Double(total)) : 0
    }
}

/// Orchestrates: fetch new papers per topic -> summarize -> upsert DailyDigest.
@MainActor
struct DigestBuilder {
    let modelContext: ModelContext
    let api: ArxivAPIClient
    let summarizer: SummaryService

    init(
        modelContext: ModelContext,
        api: ArxivAPIClient = .shared,
        summarizer: SummaryService = .shared
    ) {
        self.modelContext = modelContext
        self.api = api
        self.summarizer = summarizer
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Build today's digest for the selected topics. Each topic is saved as soon
    /// as its papers are fetched — before the slower on-device summarization — so
    /// the live `@Query` UI can show results as they arrive. Reports incremental
    /// progress, and stops starting new topics once `timeLimit` is exceeded.
    /// Returns the number of topics that had genuinely new papers today.
    @discardableResult
    func buildToday(
        categoryIDs: [String],
        referenceDate: Date = .now,
        timeLimit: TimeInterval = 120,
        onProgress: (@MainActor (DigestBuildProgress) -> Void)? = nil
    ) async -> Int {
        var topicsWithPapers = 0
        let total = categoryIDs.count
        let deadline = Date().addingTimeInterval(timeLimit)
        let store = PaperSummaryStore(modelContext: modelContext, summarizer: summarizer)

        // Request spacing and 503/429 retries are handled centrally in ArxivAPIClient.
        for (index, categoryID) in categoryIDs.enumerated() {
            // Overall deadline: stop starting new topics once we're out of time.
            if Date() >= deadline { break }

            onProgress?(DigestBuildProgress(completed: index, total: total, currentCategory: categoryID, phase: .fetching))

            // One request per category: fetch the most recent papers, then derive
            // both "today's" set and the fallback from the same response.
            let recent: [ArxivPaper]
            do {
                recent = try await api.recentPapers(category: categoryID, maxResults: 50)
            } catch {
                continue
            }

            // Today's submissions (UTC). On quiet days (e.g. weekends) this is
            // empty, so fall back to the 5 most recent papers from the SAME
            // response — these aren't genuinely "new today", so they don't bump
            // the count that drives the "new research" notification.
            let todaysPapers = recent.filter {
                Self.utcCalendar.isDate($0.published, inSameDayAs: referenceDate)
            }
            let hasNewToday = !todaysPapers.isEmpty
            let papers = hasNewToday ? todaysPapers : Array(recent.prefix(5))

            guard !papers.isEmpty else { continue }
            if hasNewToday { topicsWithPapers += 1 }

            // Display now: paper cards render from the abstract, so persist this
            // topic's papers immediately and let the live @Query surface them.
            upsertDigest(date: referenceDate, categoryID: categoryID, papers: papers, isFallback: !hasNewToday)
            try? modelContext.save()

            // Then warm the per-paper summary cache the overview reduces over,
            // before moving on — bounded by the same overall deadline.
            onProgress?(DigestBuildProgress(completed: index, total: total, currentCategory: categoryID, phase: .summarizing))
            await store.ensureSummaries(for: papers, deadline: deadline)
        }

        onProgress?(DigestBuildProgress(completed: total, total: total, currentCategory: nil, phase: .summarizing))
        try? modelContext.save()
        return topicsWithPapers
    }

    private func upsertDigest(date: Date, categoryID: String, papers: [ArxivPaper], isFallback: Bool) {
        let key = DailyDigest.makeDayKey(date: date, categoryID: categoryID)
        let descriptor = FetchDescriptor<DailyDigest>(predicate: #Predicate { $0.dayKey == key })

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.papers = papers
            existing.date = date
            existing.isFallback = isFallback
        } else {
            // summaryText is unused by the UI (the overview is recomputed live from
            // cached per-paper summaries); kept on the model for compatibility.
            let digest = DailyDigest(
                date: date,
                categoryID: categoryID,
                summaryText: "",
                generatedByAI: false,
                papers: papers,
                isFallback: isFallback
            )
            modelContext.insert(digest)
        }
    }
}
