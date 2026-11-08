import CoreML

func loadWithResult(url: URL, configuration: MLModelConfiguration, handler: @escaping (Result<MLModel, Error>) -> Void) {
    MLModel.load(contentsOf: url, configuration: configuration) { result in
        switch result {
        case .failure(let error):
            handler(.failure(error))
        case .success(let model):
            handler(.success(model))
        }
    }
}

func loadWithDefaults(url: URL, handler: @escaping (Result<MLModel, Error>) -> Void) {
    MLModel.load(contentsOf: url, completionHandler: handler)
}

func loadAsynchronously(url: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> MLModel {
    return try await MLModel.load(contentsOf: url, configuration: configuration)
}

func compileWithResult(url: URL, handler: @escaping (Result<URL, Error>) -> Void) {
    MLModel.compileModel(at: url, completionHandler: handler)
}

func compileAsynchronously(url: URL) async throws -> URL {
    return try await MLModel.compileModel(at: url)
}

func openDirectly(url: URL, configuration: MLModelConfiguration) throws -> MLModel {
    return try MLModel(contentsOf: url, configuration: configuration)
}

func shape(of array: MLShapedArray<Float>) -> [Int] {
    return array.shape
}
