import SwiftUI

struct PaperBubbleView: View {
    let paper: ArxivPaper

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !paper.displayKeywords.isEmpty {
                HStack(spacing: 6) {
                    ForEach(paper.displayKeywords, id: \.self) { keyword in
                        KeywordTag(text: keyword)
                    }
                }
            }

            Text(paper.cleanedTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Text(paper.authorList)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(paper.cleanedSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct KeywordTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.tint.opacity(0.15), in: Capsule())
    }
}
