// Does the host's `PreprocessingUpdatableSupervisedEstimator` fit its preprocessor, and if so when?
//
// The instrument is the host's own `LinearTransformer`, because a *fitted* linear transformer has
// non-identity `scale` and `offset` while an unfitted one is the identity - so the question is visible
// by reading two numbers off the transformer's preprocessor, with no private access and nothing
// transcribed from Apple's source. Its `preprocessor` is a public `var` (the pipeline declares both
// `preprocessor` and `estimator` as public stored properties), so the probe reads it directly.
//
// `makeTransformer()` takes no data, so a fit can only happen at the first `update(_:with:)` - or never,
// in which case every value is transformed by the identity and the inner estimator is fed the raw
// column.
//
// The pipeline's transformer is the host's `ComposedTransformer`, whose members are `inner` (the
// preprocessor) and `outer` (the fitted estimator) - read from the interface at line 439, not assumed.
//
// The conformer below satisfies exactly what the macOS SDK's `CreateMLComponents.swiftinterface`
// requires, and nothing more:
//
//   protocol Transformer                 - associatedtype Input, Output;
//  func applied(to:eventHandler:) async throws -> Output
//   protocol SupervisedEstimator         - associatedtype Transformer: Transformer,
//                                              Annotation: Equatable;
//                                          fitted(to:eventHandler:), fitted(to:validateOn:eventHandler:),
//                                          encode(_:to:), decode(from:)
//   protocol UpdatableSupervisedEstimator - the above plus makeTransformer(), update(_:with:eventHandler:),
//                                          encodeWithOptimizer(_:to:), decodeWithOptimizer(from:)
//
//     xcrun swiftc -O -o preprocessing-updatable-host preprocessing-updatable-host.swift
//     ./preprocessing-updatable-host
import CreateMLComponents
import Foundation

/// The inner estimator: records the first feature it is handed, so "what the estimator sees" and "what
/// the transformer's preprocessor does" are two readings of the same question.
typealias TransformerProtocol = CreateMLComponents.Transformer

struct Recorder: UpdatableSupervisedEstimator {
    /// `SupervisedEstimator` requires its `Transformer` to be a `Transformer` itself, so this is one:
    /// `Input` and `Output` are `Double` and `applied` hands back the value it was given. What the case
    /// measures is the *numbers recorded*, not what this does to one.
    struct Transformer: TransformerProtocol, Equatable {
        typealias Input = Double
        typealias Output = Double
        var updates: Int = 0
        var firstFeatureSeen: Double?
        func applied(to input: Double, eventHandler: EventHandler? = nil) async throws -> Double { input }
    }
    typealias Annotation = Double

    func makeTransformer() -> Transformer { Transformer() }

    func fitted<Input>(to input: Input, eventHandler: EventHandler? = nil) async throws -> Transformer
    where Input: Sequence, Input.Element == AnnotatedFeature<Double, Double> {
        Transformer()
    }

    func fitted<Input, Validation>(to input: Input, validateOn validation: Validation,
                                   eventHandler: EventHandler? = nil) async throws -> Transformer
    where Input: Sequence, Validation: Sequence,
          Input.Element == AnnotatedFeature<Double, Double>,
          Validation.Element == AnnotatedFeature<Double, Double> {
        Transformer()
    }

    func update<InputSequence>(_ transformer: inout Transformer, with input: InputSequence,
                               eventHandler: EventHandler? = nil) async throws
    where InputSequence: Sequence, InputSequence.Element == AnnotatedFeature<Double, Double> {
        transformer.updates += 1
        let features = Array(input)
        if transformer.firstFeatureSeen == nil { transformer.firstFeatureSeen = features.first?.feature }
    }

    func encode(_ transformer: Transformer, to encoder: inout any EstimatorEncoder) throws {}
    func decode(from decoder: inout any EstimatorDecoder) throws -> Transformer { Transformer() }
    func encodeWithOptimizer(_ transformer: Transformer, to encoder: inout any EstimatorEncoder) throws {}
    func decodeWithOptimizer(from decoder: inout any EstimatorDecoder) throws -> Transformer { Transformer() }
}

// The preprocessor, the host's own and deliberately the identity: if the pipeline fits it, its scale
// and offset stop being 1 and 0.
let identity = LinearTransformer<Double>(scale: 1, offset: 0)
let pipeline = PreprocessingUpdatableSupervisedEstimator(identity, Recorder())

var transformer = pipeline.makeTransformer()
print("after makeTransformer(): preprocessor scale=\(transformer.inner.scale) offset=\(transformer.inner.offset)")
print("   scale=1 offset=0 means UNFITTED; anything else means the pipeline fitted it.")

// x = 1...8 with an annotation of 0 each.
let batch = (1...8).map { AnnotatedFeature(feature: Double($0), annotation: 0.0) }
try await pipeline.update(&transformer, with: batch)
print("after the first update(): the estimator saw \(String(describing: transformer.outer.firstFeatureSeen))")
print("   preprocessor scale=\(transformer.inner.scale) offset=\(transformer.inner.offset)")
print("   and the preprocessor now does 1.0 -> \(transformer.inner.applied(to: 1.0))")

// A **second** update, so that "the host fits on a later update rather than the first" is excluded by
// measurement rather than by assumption. If the pipeline fits the preprocessor at any point in its
// life, these two lines are where it shows.
let second = (11...18).map { AnnotatedFeature(feature: Double($0), annotation: 0.0) }
try await pipeline.update(&transformer, with: second)
print("after the second update(): the estimator saw \(String(describing: transformer.outer.firstFeatureSeen))")
print("   preprocessor scale=\(transformer.inner.scale) offset=\(transformer.inner.offset)")
print("   and the preprocessor now does 1.0 -> \(transformer.inner.applied(to: 1.0))")
print("   scale=1 offset=0 after two updates means the host NEVER fits this pipeline's preprocessor.")
