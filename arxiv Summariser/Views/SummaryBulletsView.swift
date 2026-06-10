import SwiftUI

/// Turns an LLM-generated summary (loose markdown bullets, often with an intro
/// line like "Here are 5 bullet points:") into clean, structured items.
enum SummaryFormatter {
    /// Bullet strings with list markers stripped and any leading intro line
    /// removed. Wrapped continuation lines are joined back onto their bullet.
    static func bullets(from text: String) -> [String] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var bullets: [String] = []
        var current: String?
        for line in lines {
            if let item = strippingMarker(line) {
                if let current { bullets.append(current) }
                current = item
            } else if current != nil {
                current! += " " + line              // wrapped continuation
            }
            // a non-bullet line before any bullet is intro/preamble → ignored
        }
        if let current { bullets.append(current) }

        // No recognizable bullets → fall back to paragraphs so we never show nothing.
        return bullets.isEmpty ? lines : bullets
    }

    /// A compact single-line preview (markers/intro stripped) for teaser cards.
    static func plainPreview(from text: String) -> String {
        bullets(from: text).joined(separator: "  •  ")
    }

    /// A bullet split into an optional bold lead-in (text before the first colon,
    /// when short) and the remainder, rendered from inline markdown.
    static func attributed(for bullet: String) -> AttributedString {
        if let range = bullet.range(of: ": "),
           bullet.distance(from: bullet.startIndex, to: range.lowerBound) <= 42 {
            let lead = String(bullet[..<range.lowerBound])
            let rest = String(bullet[range.upperBound...])
            var leadAttr = inlineMarkdown(lead)
            leadAttr.font = .body.weight(.semibold)
            return leadAttr + AttributedString(": ") + inlineMarkdown(rest)
        }
        return inlineMarkdown(bullet)
    }

    private static func inlineMarkdown(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string)) ?? AttributedString(string)
    }

    /// Drop a leading list marker ("* ", "- ", "• ", "– ", "· ", "1.", "2)") if present.
    private static func strippingMarker(_ line: String) -> String? {
        for marker in ["* ", "- ", "• ", "– ", "· "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        if let match = line.range(of: #"^\d{1,2}[.)]\s+"#, options: .regularExpression) {
            return String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}

/// Renders a summary as a tidy, spaced bullet list with bold lead-ins.
struct SummaryBulletsView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(SummaryFormatter.bullets(from: text).enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("•")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.tint)
                    Text(SummaryFormatter.attributed(for: bullet))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
