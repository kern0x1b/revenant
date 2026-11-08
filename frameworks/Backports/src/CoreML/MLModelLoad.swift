import Foundation

private func loaded<Value>(_ value: Value?, _ error: Error?) -> Result<Value, Error> {
    if let value = value {
        return .success(value)
    }
    guard let error = error else {
        preconditionFailure("CoreML completed without a result or an error")
    }
    return .failure(error)
}

extension MLModel {
    public class func load(contentsOf url: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Result<MLModel, Error>) -> Void) {
        __loadContents(of: url, configuration: configuration) { model, error in
            handler(loaded(model, error))
        }
    }

    public class func load(contentsOf url: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> MLModel {
        try await withCheckedThrowingContinuation { continuation in
            load(contentsOf: url, configuration: configuration) { result in
                continuation.resume(with: result)
            }
        }
    }

    public class func compileModel(at url: URL, completionHandler handler: @escaping (Result<URL, Error>) -> Void) {
        __compileModel(at: url) { compiled, error in
            handler(loaded(compiled, error))
        }
    }

    public class func compileModel(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            compileModel(at: url) { result in
                continuation.resume(with: result)
            }
        }
    }

    public func prediction(from input: any MLFeatureProvider, options: MLPredictionOptions = MLPredictionOptions()) async throws -> any MLFeatureProvider {
        try await withCheckedThrowingContinuation { continuation in
            __prediction(fromFeatures: input, options: options) { output, error in
                continuation.resume(with: loaded(output, error))
            }
        }
    }
}
