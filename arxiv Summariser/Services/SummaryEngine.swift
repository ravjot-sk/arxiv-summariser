import Foundation

/// User-selectable summary engine.
enum SummaryEngine: String, CaseIterable, Identifiable {
    /// Best available: on-device Gemma if downloaded → Gemini if keyed → Apple → abstracts.
    case automatic
    /// On-device Gemma via MLX.
    case gemma
    /// Hosted Google Gemini.
    case gemini
    /// Apple on-device FoundationModels.
    case apple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .gemma: return "On-device Gemma"
        case .gemini: return "Gemini (cloud)"
        case .apple: return "Apple Intelligence"
        }
    }
}

/// App-wide engine preference. Backed by `UserDefaults` so the stateless
/// `SummaryService` singleton can read it without a SwiftData context.
enum SummaryPreferences {
    private static let key = "summaryEngine"

    static var engine: SummaryEngine {
        get { SummaryEngine(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .automatic }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
