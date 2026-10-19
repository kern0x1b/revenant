import CreateMLComponents
import Foundation

struct Recorder: Estimator {
    struct Transformer: TransformerProtocol, Equatable {
        typealias Input = Double
        typealias Output = Double
        var fits: Int = 0
        var firstSeen: Double?
        func applied(to input: Double, eventHandler: EventHandler? = nil) async throws -> Double { input }
    }
    func fitted<S>(to input: S, eventHandler: EventHandler? = nil) async throws -> Transformer
    where S: Sequence, S.Element == Double {
        var t = Transformer()
        t.fits += 1
        t.firstSeen = Array(input).first
        return t
    }

    func encode(_ transformer: Transformer, to encoder: inout any EstimatorEncoder) throws {}
    func decode(from decoder: inout any EstimatorDecoder) throws -> Transformer { Transformer() }
}

typealias TransformerProtocol = CreateMLComponents.Transformer

let identity = LinearTransformer<Double>(scale: 1, offset: 0)
let pipeline = PreprocessingEstimator(identity, Recorder())

let batch = (1...8).map(Double.init)

var fitted = try await pipeline.fitted(to: batch)
print("after fitted(to:): preprocessor scale=\(fitted.inner.scale) offset=\(fitted.inner.offset)")
print("   and the estimator was fitted \(fitted.outer.fits) time(s), first seen \(String(describing: fitted.outer.firstSeen))")

let preprocessed = try await pipeline.preprocessed(from: batch)
print("after preprocessed(from:): the values are \(preprocessed)")
print("   1, 2, 3 ... would mean the identity preprocessor was used; anything else means it was fitted.")
