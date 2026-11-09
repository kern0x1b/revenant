import Foundation
import WebKit

func archiveData(of webView: WKWebView, completion: @escaping (Data?) -> Void) {
    webView.createWebArchiveData { result in
        guard case let .success(data) = result else {
            completion(nil)
            return
        }
        completion(data)
    }
}

func blobData(of webView: WKWebView, script: String, url: URL, completion: @escaping (Data?) -> Void) {
    webView.callAsyncJavaScript(script, arguments: ["blobUrl": url.absoluteString], in: nil, in: WKContentWorld.defaultClient) { result in
        switch result {
        case .success(let dataUrl):
            guard let url = URL(string: dataUrl as! String) else {
                completion(nil)
                return
            }
            completion(try? Data(contentsOf: url))
        case .failure:
            completion(nil)
        }
    }
}

func evaluated(in webView: WKWebView) async throws -> Any? {
    let page = try await webView.evaluateJavaScript("document.title", in: nil, contentWorld: .page)
    let computed = try await webView.callAsyncJavaScript("return await Promise.resolve(x + 1)", arguments: ["x": 41], contentWorld: .defaultClient)
    return computed ?? page
}

func evaluatedWithHandler(in webView: WKWebView, completion: @escaping (Any?) -> Void) {
    webView.evaluateJavaScript("1 + 1", in: nil, in: .page) { result in
        completion(try? result.get())
    }
}
