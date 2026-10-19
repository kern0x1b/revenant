// EstimatorProtocols.swift — what an estimator is, over the two types this package has.
//
// The framework writes these over `DataFrame` and over a shaped array; this package writes them over
// `ColumnarTable` and over `RowMatrix`, which are the table and the design matrix it already has. The
// shape is the framework's: a fit that answers a transformer, a transformer that answers something,
// and the `Supervised`/`Tabular`/`Updatable` refinements that say which of those a type is.
//
// What is deliberately *not* here: `TemporalSequence`, `TabularSequence` and the shaped-array
// `Input`/`Output` associated types, because those need the `DataFrame` and `MLShapedArray` work that
// is next. A protocol that names a type this package does not have would be a declaration nothing can
// conform to, and that is the thing a row is not allowed to be.

import Foundation

/// Something that is fitted on a table and answers a fitted transformer.
public protocol TabularEstimator {
    associatedtype Transformer

    /// The fit.
    func fitted(on input: ColumnarTable) throws -> Transformer
}

/// An estimator that is fitted without a target.
public protocol Estimator: TabularEstimator {}

/// An estimator that is fitted against a target column.
public protocol SupervisedEstimator {
    associatedtype Transformer

    /// The fit, over a table that carries its target in `annotationColumn`.
    func fitted(on input: ColumnarTable) throws -> Transformer
}

/// An estimator that can be updated on new data without being refitted.
public protocol UpdatableEstimator {
    associatedtype Transformer

    /// The unfitted transformer.
    func makeTransformer() -> Transformer

    /// The update, in place.
    func update(_ transformer: inout Transformer, with input: ColumnarTable) throws
}

/// An estimator over a supervised target, that can be updated.
public protocol UpdatableSupervisedEstimator: SupervisedEstimator, UpdatableEstimator where Transformer: Any {}
