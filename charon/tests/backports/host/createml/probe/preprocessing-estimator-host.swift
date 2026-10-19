// Does the host's `PreprocessingEstimator` - the unsupervised, non-updatable one - fit its
// preprocessor, and when?
//
// The instrument is the host's own `LinearTransformer`, because a *fitted* linear transformer has
// non-identity `scale` and `offset` and an unfitted one is the identity, so "was it fitted" is two
// numbers read off the transformer's public `inner`. Nothing is transcribed from Apple's source: the
// conformer below satisfies exactly what the macOS SDK's `CreateMLComponents.swiftinterface` requires
// of `Transformer` (associated `Input`, `Output`, and one `applied(to:eventHandler:)`) and of
// `Estimator` (`Transformer: Transformer`, `fitted(to:eventHandler:)`).
//
// This is the *other* question from `preprocessing-updatable-host.swift`, which asks the supervised
// updatable type and found the host never fitting its preprocessor. The port fits this one's, so the
// two answers have to be measured rather than assumed to be the same rule.
//
//     xcrun swiftc -O -o preprocessing-estimator-host preprocessing-estimator-host.swift
//     ./preprocessing-estimator-host
import CreateMLComponents
import Foundation

/// The inner estimator: an unsupervised one that records how many times it was fitted and what it was
/// handed, so "the preprocessor transformed the input" and "the estimator received something" are two
/// readings of the same question.
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

// The preprocessor, the host's own and deliberately the identity: if the pipeline fits it, its scale
// and offset stop being 1 and 0.
let identity = LinearTransformer<Double>(scale: 1, offset: 0)
let pipeline = PreprocessingEstimator(identity, Recorder())

// The batch: x = 1...8, which is 4.5 at the mean, so a fitted preprocessor would be visible.
let batch = (1...8).map(Double.init)

var fitted = try await pipeline.fitted(to: batch)
print("after fitted(to:): preprocessor scale=\(fitted.inner.scale) offset=\(fitted.inner.offset)")
print("   and the estimator was fitted \(fitted.outer.fits) time(s), first seen \(String(describing: fitted.outer.firstSeen))")

// The host's entry points here are `preprocessed(from:)` and `fitted(to:)` - it has **no**
// `transformed(to:)` at all, where the port has `transformed(_:)` at Preprocessing.swift:57, so that is
// a divergence in the API surface rather than a spelling difference, and it is recorded as one.
let preprocessed = try await pipeline.preprocessed(from: batch)
print("after preprocessed(from:): the values are \(preprocessed)")
print("   1, 2, 3 ... would mean the identity preprocessor was used; anything else means it was fitted.")
