import CreateMLComponents
import Foundation

typealias TransformerProtocol = CreateMLComponents.Transformer

struct Recorder: UpdatableSupervisedEstimator {
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

let identity = LinearTransformer<Double>(scale: 1, offset: 0)
let pipeline = PreprocessingUpdatableSupervisedEstimator(identity, Recorder())

var transformer = pipeline.makeTransformer()
print("after makeTransformer(): preprocessor scale=\(transformer.inner.scale) offset=\(transformer.inner.offset)")
print("   scale=1 offset=0 means UNFITTED; anything else means the pipeline fitted it.")

let batch = (1...8).map { AnnotatedFeature(feature: Double($0), annotation: 0.0) }
try await pipeline.update(&transformer, with: batch)
print("after the first update(): the estimator saw \(String(describing: transformer.outer.firstFeatureSeen))")
print("   preprocessor scale=\(transformer.inner.scale) offset=\(transformer.inner.offset)")
print("   and the preprocessor now does 1.0 -> \(transformer.inner.applied(to: 1.0))")

let second = (11...18).map { AnnotatedFeature(feature: Double($0), annotation: 0.0) }
try await pipeline.update(&transformer, with: second)
print("after the second update(): the estimator saw \(String(describing: transformer.outer.firstFeatureSeen))")
print("   preprocessor scale=\(transformer.inner.scale) offset=\(transformer.inner.offset)")
print("   and the preprocessor now does 1.0 -> \(transformer.inner.applied(to: 1.0))")
print("   scale=1 offset=0 after two updates means the host NEVER fits this pipeline's preprocessor.")
