// Does the host's `PreprocessingUpdatableEstimator` - the unsupervised updatable one - fit its
// preprocessor?
//
// The third of the three, and the only one the port fits (Preprocessing.swift:137) whose host
// behaviour was still unmeasured. The instrument is the host's own `LinearTransformer`, because a
// *fitted* linear transformer has non-identity `scale` and `offset` and an unfitted one is the
// identity, so "was it fitted" is two numbers read off the transformer's public `inner`. Nothing is
// transcribed from Apple's source: the conformer satisfies exactly what the macOS SDK's
// `CreateMLComponents.swiftinterface` requires of `Transformer` (associated `Input`, `Output`, and one
// `applied(to:eventHandler:)`) and of `UpdatableEstimator` (which refines `Estimator`, whose
// `Transformer: Transformer`, `fitted<S>(to:eventHandler:)` with `S.Element == Transformer.Input`, and
// `encode`/`decode` the protocol adds).
//
//     xcrun swiftc -O -o preprocessing-updatable-estimator-host preprocessing-updatable-estimator-host.swift
//     ./preprocessing-updatable-estimator-host
import CreateMLComponents
import Foundation

typealias TransformerProtocol = CreateMLComponents.Transformer

/// The inner estimator: an updatable one that records how many times it was fitted and what it was
/// handed, so "the preprocessor transformed the input" and "the estimator received something" are two
/// readings of the same question.
struct Recorder: UpdatableEstimator {
    struct Transformer: TransformerProtocol, Equatable {
        typealias Input = Double
        typealias Output = Double
        var fits: Int = 0
        var firstSeen: Double?
        func applied(to input: Double, eventHandler: EventHandler? = nil) async throws -> Double { input }
    }
    typealias Annotation = Double

    func makeTransformer() -> Transformer { Transformer() }

    func fitted<S>(to input: S, eventHandler: EventHandler? = nil) async throws -> Transformer
    where S: Sequence, S.Element == Double {
        var t = Transformer()
        t.fits += 1
        t.firstSeen = Array(input).first
        return t
    }

    func encode(_ transformer: Transformer, to encoder: inout any EstimatorEncoder) throws {}
    func decode(from decoder: inout any EstimatorDecoder) throws -> Transformer { Transformer() }
    func encodeWithOptimizer(_ transformer: Transformer, to encoder: inout any EstimatorEncoder) throws {}
    func decodeWithOptimizer(from decoder: inout any EstimatorDecoder) throws -> Transformer { Transformer() }

    /// `UpdatableEstimator` adds this to `Estimator`'s four, so a conformer needs it whether or not
    /// this probe calls it - the pipeline's own `update` is the path that would carry the preprocessed
    /// values to the inner estimator.
    func update<InputSequence>(_ transformer: inout Transformer, with input: InputSequence,
                               eventHandler: EventHandler? = nil) async throws
    where InputSequence: Sequence, InputSequence.Element == Double {
        transformer.fits += 1
        if transformer.firstSeen == nil { transformer.firstSeen = Array(input).first }
    }
}

// The preprocessor, the host's own and deliberately the identity: if the pipeline fits it, its scale
// and offset stop being 1 and 0.
let identity = LinearTransformer<Double>(scale: 1, offset: 0)
let pipeline = PreprocessingUpdatableEstimator(identity, Recorder())

// The batch: x = 1...8, which is 4.5 at the mean, so a fitted preprocessor would be visible.
let batch = (1...8).map(Double.init)
// The host's entry points here are `preprocessed(from:)` and `fitted(toPreprocessed:)` — it has **no**
// `transformed(to:)`, the same divergence the other two probes found, where the port has
// `transformed(_:)` at Preprocessing.swift:137.
let preprocessed = try await pipeline.preprocessed(from: batch)
print("after preprocessed(from:): the values are \(preprocessed)")
print("   1, 2, 3 ... would mean the identity preprocessor was used; anything else means it was fitted.")
print("   The port fits here (Preprocessing.swift:137), so this decides whether the port is right.")
