import Foundation

private func evaluation(_ value: Any?, _ error: Error?) -> Result<Any, Error> {
    if let error = error {
        return .failure(error)
    }
    return .success(value as Any)
}

private func archive(_ data: Data?, _ error: Error?) -> Result<Data, Error> {
    if let error = error {
        return .failure(error)
    }
    guard let data = data else {
        preconditionFailure("WebKit completed without data and without an error")
    }
    return .success(data)
}

extension WKWebView {
    @nonobjc public func callAsyncJavaScript(_ functionBody: String, arguments: [String: Any] = [:], in frame: WKFrameInfo? = nil, in contentWorld: WKContentWorld, completionHandler: (@MainActor @Sendable (Result<Any, Error>) -> Void)? = nil) {
        __callAsyncJavaScript(functionBody, arguments: arguments, inFrame: frame, in: contentWorld, completionHandler: completionHandler.map { handler in
            { @MainActor @Sendable value, error in handler(evaluation(value, error)) }
        })
    }

    @nonobjc public func callAsyncJavaScript(_ functionBody: String, arguments: [String: Any] = [:], in frame: WKFrameInfo? = nil, contentWorld: WKContentWorld) async throws -> Any? {
        return try await withCheckedThrowingContinuation { continuation in
            __callAsyncJavaScript(functionBody, arguments: arguments, inFrame: frame, in: contentWorld) { value, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: value)
                }
            }
        }
    }

    @nonobjc public func evaluateJavaScript(_ javaScript: String, in frame: WKFrameInfo? = nil, in contentWorld: WKContentWorld, completionHandler: (@MainActor @Sendable (Result<Any, Error>) -> Void)? = nil) {
        __evaluateJavaScript(javaScript, inFrame: frame, in: contentWorld, completionHandler: completionHandler.map { handler in
            { @MainActor @Sendable value, error in handler(evaluation(value, error)) }
        })
    }

    @nonobjc public func evaluateJavaScript(_ javaScript: String, in frame: WKFrameInfo? = nil, contentWorld: WKContentWorld) async throws -> Any? {
        return try await withCheckedThrowingContinuation { continuation in
            __evaluateJavaScript(javaScript, inFrame: frame, in: contentWorld) { value, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: value)
                }
            }
        }
    }

    @nonobjc public func createWebArchiveData(completionHandler: @escaping @MainActor @Sendable (Result<Data, Error>) -> Void) {
        __createWebArchiveData { data, error in completionHandler(archive(data, error)) }
    }
}
