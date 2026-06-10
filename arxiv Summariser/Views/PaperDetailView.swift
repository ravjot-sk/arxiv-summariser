import SwiftUI

struct PaperDetailView: View {
    let paper: ArxivPaper

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(paper.cleanedTitle)
                    .font(.title3.bold())

                Text(paper.authorList)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(paper.categories.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.tint.opacity(0.15), in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Abstract").font(.headline)
                    Text(paper.cleanedSummary).font(.body)
                }

                HStack(spacing: 12) {
                    Link(destination: paper.absURL) {
                        Label("View on arXiv", systemImage: "safari")
                    }
                    if let pdf = paper.pdfURL {
                        Link(destination: pdf) {
                            Label("PDF", systemImage: "doc.richtext")
                        }
                    }
                }
                .font(.subheadline)

                // Future: in-depth analysis & relation to existing literature renders here.
            }
            .padding()
        }
        .navigationTitle("Paper")
        .navigationBarTitleDisplayMode(.inline)
    }
}
