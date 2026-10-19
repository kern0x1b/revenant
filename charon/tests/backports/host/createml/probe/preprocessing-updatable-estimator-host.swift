import CreateMLComponents
import Foundation

typealias TransformerProtocol = CreateMLComponents.Transformer

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

    func update<InputSequence>(_ transformer: inout Transformer, with input: InputSequence,
                               eventHandler: EventHandler? = nil) async throws
    where InputSequence: Sequence, InputSequence.Element == Double {
        transformer.fits += 1
        if transformer.firstSeen == nil { transformer.firstSeen = Array(input).first }
    }
}

let identity = LinearTransformer<Double>(scale: 1, offset: 0)
let pipeline = PreprocessingUpdatableEstimator(identity, Recorder())

let batch = (1...8).map(Double.init)
let preprocessed = try await pipeline.preprocessed(from: batch)
print("after preprocessed(from:): the values are \(preprocessed)")
print("   1, 2, 3 ... would mean the identity preprocessor was used; anything else means it was fitted.")
print("   The port fits here (Preprocessing.swift:137), so this decides whether the port is right.")
