import CreateMLComponents
import Foundation

typealias TransformerProtocol = CreateMLComponents.Transformer

struct Recorder: Estimator {
    struct Transformer: TransformerProtocol, Equatable {
        typealias Input = Double
        typealias Output = Double
        func applied(to input: Double, eventHandler: EventHandler? = nil) async throws -> Double { input }
    }
    func makeTransformer() -> Transformer { Transformer() }
    func fitted<S>(to input: S, eventHandler: EventHandler? = nil) async throws -> Transformer
    where S: Sequence, S.Element == Double { Transformer() }
    func encode(_ transformer: Transformer, to encoder: inout any EstimatorEncoder) throws {}
    func decode(from decoder: inout any EstimatorDecoder) throws -> Transformer { Transformer() }
}

struct SupervisedRecorder: UpdatableSupervisedEstimator {
    struct Transformer: TransformerProtocol, Equatable {
        typealias Input = Double
        typealias Output = Double
        var firstSeen: Double?
        func applied(to input: Double, eventHandler: EventHandler? = nil) async throws -> Double { input }
    }
    typealias Annotation = Double
    func makeTransformer() -> Transformer { Transformer() }
    func fitted<Input>(to input: Input, eventHandler: EventHandler? = nil) async throws -> Transformer
    where Input: Sequence, Input.Element == AnnotatedFeature<Double, Double> { Transformer() }
    func update<InputSequence>(_ transformer: inout Transformer, with input: InputSequence,
                               eventHandler: EventHandler? = nil) async throws
    where InputSequence: Sequence, InputSequence.Element == AnnotatedFeature<Double, Double> {
        if transformer.firstSeen == nil { transformer.firstSeen = Array(input).first?.feature }
    }
    func encode(_ transformer: Transformer, to encoder: inout any EstimatorEncoder) throws {}
    func decode(from decoder: inout any EstimatorDecoder) throws -> Transformer { Transformer() }
    func encodeWithOptimizer(_ transformer: Transformer, to encoder: inout any EstimatorEncoder) throws {}
    func decodeWithOptimizer(from decoder: inout any EstimatorDecoder) throws -> Transformer { Transformer() }
}

let batch = (1...8).map(Double.init)
let annotated = (1...8).map { AnnotatedFeature(feature: Double($0), annotation: 0.0) }

func report(_ name: String, _ preprocessor: LinearTransformer<Double>) async {
    print("--- \(name): scale=\(preprocessor.scale) offset=\(preprocessor.offset)")
    let unsupervised = try await PreprocessingEstimator(preprocessor, Recorder())
        .preprocessed(from: batch)
    print("    PreprocessingEstimator            preprocessed(from:) = \(unsupervised)")
    let updatable = try await PreprocessingUpdatableEstimator(preprocessor, Recorder())
        .preprocessed(from: batch)
    print("    PreprocessingUpdatableEstimator   preprocessed(from:) = \(updatable)")
    var supervisedTransformer = try await PreprocessingUpdatableSupervisedEstimator(preprocessor,
                                                                                   SupervisedRecorder())
        .makeTransformer()
    try await PreprocessingUpdatableSupervisedEstimator(preprocessor, SupervisedRecorder())
        .update(&supervisedTransformer, with: annotated)
    print("    PreprocessingUpdatableSupervised  the estimator saw    = \(String(describing: supervisedTransformer.outer.firstSeen))")
}

await report("the identity", LinearTransformer(scale: 1, offset: 0))
await report("a doubling", LinearTransformer(scale: 2, offset: 0))
await report("a shift", LinearTransformer(scale: 1, offset: 100))
print()
print("unchanged [1...8] would mean the preprocessor is ignored; doubled or shifted means it is applied.")
