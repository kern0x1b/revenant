import SwiftUI
import UIKit

struct WebPage: UIViewRepresentable {
    let html: String
    @Binding var loading: Bool

    func makeUIView(context: Context) -> UIWebView {
        let view = UIWebView()
        view.delegate = context.coordinator
        view.scalesPageToFit = true
        return view
    }

    func updateUIView(_ view: UIWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loaded != html {
            context.coordinator.loaded = html
            view.loadHTMLString(html, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIWebViewDelegate {
        var parent: WebPage
        var loaded = ""
        init(_ parent: WebPage) { self.parent = parent }
        func webViewDidStartLoad(_ webView: UIWebView) { parent.loading = true }
        func webViewDidFinishLoad(_ webView: UIWebView) { parent.loading = false }
    }
}

struct BrowserView: View {
    @State private var address = "Welcome"
    @State private var loading = false
    @State private var history = ["Welcome"]
    @State private var showBookmarks = false

    var html: String { "<html><body style='font-family:Helvetica;padding:20px'><h2>\(address)</h2><p>Page content for \(address).</p></body></html>" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { if history.count > 1 { history.removeLast(); address = history.last ?? "Welcome" } } label: { Image(systemName: "chevron.left") }
                    .disabled(history.count < 2)
                TextField("Search or enter address", text: $address, onCommit: { history.append(address) })
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                if loading { ProgressView() }
                Button { showBookmarks = true } label: { Image(systemName: "bookmark") }
            }
            .padding(8)
            .background(Color(white: 0.92))
            WebPage(html: html, loading: $loading)
        }
        .actionSheet(isPresented: $showBookmarks) {
            ActionSheet(title: Text("Bookmarks"), buttons: [.default(Text("Home")) { address = "Home" }, .default(Text("News")) { address = "News" }, .cancel()])
        }
    }
}
