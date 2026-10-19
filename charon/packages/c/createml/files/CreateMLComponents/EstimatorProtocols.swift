import Foundation

public protocol TabularEstimator {
    associatedtype Transformer

    func fitted(on input: ColumnarTable) throws -> Transformer
}

public protocol Estimator: TabularEstimator {}

public protocol SupervisedEstimator {
    associatedtype Transformer

    func fitted(on input: ColumnarTable) throws -> Transformer
}

public protocol UpdatableEstimator {
    associatedtype Transformer

    func makeTransformer() -> Transformer

    func update(_ transformer: inout Transformer, with input: ColumnarTable) throws
}

public protocol UpdatableSupervisedEstimator: SupervisedEstimator, UpdatableEstimator where Transformer: Any {}
