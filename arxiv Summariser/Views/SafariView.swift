import SwiftUI
import SafariServices

/// In-app Safari (SFSafariViewController) for showing web content, e.g. the
/// arXiv HTML rendering of a paper, without leaving the app.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
