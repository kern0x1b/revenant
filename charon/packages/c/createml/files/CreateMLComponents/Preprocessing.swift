// Preprocessing.swift — a preprocessor in front of an estimator, and the composed transformer that
// carries both.
//
// A pipeline is not a new algorithm. `PreprocessingEstimator(scaler, forest)` *is* a scaler and a
// forest, and what it adds is one thing: the fitted preprocessor travels **with** the fitted model, so
// a prediction goes through the very scaler the fit used. Without that a caller has to remember to
// scale new data by the training mean, and the first time someone forgets, the numbers are wrong and
// nothing says so.
//
// So the type is a pair plus a composition, and the fit is two fits: the preprocessor fitted and
// applied, then the estimator fitted on what came out. The `fitted(on:)` convenience runs both,
// because a caller who wants to look at the intermediate calls the halves and a caller who does not
// calls one.
//
// The eight names the framework has are this same shape over four axes, differing only in which
// estimator protocol the inner one answers to and whether it can be updated. `Updatable` is the same
// pipeline with one semantic added: an update touches the **inner** estimator and leaves the
// preprocessor as the fit left it, because refitting the preprocessor on the update's data changes
// the features the estimator was fitted on, and that is a different model rather than an update.
//
// Everything here is over `ColumnarTable` and `RowMatrix`, the two types this package already has. A
// framework's pipeline is written over `DataFrame` and `TabularTransformer`, and those are the shapes
// of the `DataFrame` work that is next; naming types here that do not exist yet would put a
// declaration in the tree that nothing can use.

import Foundation

/// The fitted half of a pipeline: the preprocessor, and the estimator it fed.
public struct ComposedTransformer<Preprocessor, Fitted> {
    public var preprocessor: Preprocessor
    public var estimator: Fitted

    public init(_ preprocessor: Preprocessor, _ estimator: Fitted) {
        self.preprocessor = preprocessor
        self.estimator = estimator
    }
}

/// A preprocessor in front of an unsupervised estimator.
public struct PreprocessingEstimator<Preprocessor: ColumnarTransformer, Base: Estimator> {
    public typealias Transformer = ComposedTransformer<Preprocessor, Base.Transformer>
    public typealias Input = ColumnarTable
    public typealias Intermediate = ColumnarTable
    public typealias Output = Base

    public var preprocessor: Preprocessor
    public var estimator: Base

    public init(_ preprocessor: Preprocessor, _ estimator: Base) {
        self.preprocessor = preprocessor
        self.estimator = estimator
    }

    /// The table the preprocessor turns the input into, with the preprocessor fitted and applied.
    /// The fitted preprocessor itself is `Transformer.preprocessor`.
    public func preprocessed(from training: Input) throws -> Intermediate {
        try preprocessor.transformed(training)
    }

    /// The whole pipeline fitted: the preprocessor first, and the estimator on its output.
    public func fitted(on training: Input) throws -> Transformer {
        let fitted = preprocessor
        // The estimator's own fit takes the preprocessed table, and calling it here is what makes the
        // pipeline a pipeline rather than two things side by side.
        return Transformer(fitted, try estimator.fitted(on: fitted.transformed(training)))
    }
}

/// A preprocessor in front of a supervised estimator: the same, with a target column kept aside
/// rather than transformed, because a scaler over a target is a different model and not this one.
public struct PreprocessingSupervisedEstimator<Preprocessor: ColumnarTransformer, Base: SupervisedEstimator> {
    public typealias Transformer = ComposedTransformer<Preprocessor, Base.Transformer>
    public typealias Input = ColumnarTable
    public typealias Intermediate = ColumnarTable
    public typealias Output = Base

    public var preprocessor: Preprocessor
    public var estimator: Base

    /// The column holding the target, which the preprocessor must not touch.
    public var annotationColumn: String

    public init(_ preprocessor: Preprocessor, _ estimator: Base, annotationColumn: String) {
        self.preprocessor = preprocessor
        self.estimator = estimator
        self.annotationColumn = annotationColumn
    }

    /// The table the estimator is fitted on: the **features** preprocessed, and the target column put
    /// back untouched.
    public func preprocessed(from training: Input) throws -> Intermediate {
        let fitted = try preprocessor.fitted(on: featuresOnly(from: training))
        var transformed = fitted.transformed(featuresOnly(from: training))
        if let target = training.column(annotationColumn) {
            transformed.set(target, named: annotationColumn)
        }
        return transformed
    }

    /// The training table without its target, which is what the preprocessor is fitted over.
    public func featuresOnly(from training: Input) -> Input {
        var features = training
        features.removeColumn(named: annotationColumn)
        return features
    }

    public func fitted(on training: Input) throws -> Transformer {
        let fitted = try preprocessor.fitted(on: featuresOnly(from: training))
        return Transformer(fitted, try estimator.fitted(on: preprocessed(from: training)))
    }
}

/// A preprocessor in front of an estimator that can be updated on new data.
public struct PreprocessingUpdatableEstimator<Preprocessor: ColumnarTransformer, Base: UpdatableEstimator> {
    public typealias Transformer = ComposedTransformer<Preprocessor, Base.Transformer>
    public typealias Input = ColumnarTable
    public typealias Intermediate = ColumnarTable
    public typealias Output = Base

    public var preprocessor: Preprocessor
    public var estimator: Base

    public init(_ preprocessor: Preprocessor, _ estimator: Base) {
        self.preprocessor = preprocessor
        self.estimator = estimator
    }

    /// The unfitted pipeline. The preprocessor stays as it is: an update fits the *estimator* on
    /// the features this preprocessor already produces, and refitting the preprocessor would change
    /// those features under it.
    public func makeTransformer() -> Transformer {
        Transformer(preprocessor, estimator.makeTransformer())
    }

    /// The table the preprocessor turns the input into, with the preprocessor fitted and applied.
    public func preprocessed(from training: Input) throws -> Intermediate {
        try preprocessor.transformed(training)
    }

    /// The update: the input is preprocessed **by the preprocessor the fit produced**, and the inner
    /// estimator is updated on that. The preprocessor itself is not touched, because refitting it
    /// would change the features the estimator was fitted on, and that is a different model rather
    /// than an update.
    public func update(_ transformer: inout Transformer, with input: Input) throws {
        try estimator.update(&transformer.estimator, with: transformer.preprocessor.transformed(input))
    }
}

/// A preprocessor in front of a supervised estimator that can be updated.
public struct PreprocessingUpdatableSupervisedEstimator<Preprocessor: ColumnarTransformer, Base: UpdatableSupervisedEstimator> {
    public typealias Transformer = ComposedTransformer<Preprocessor, Base.Transformer>
    public typealias Input = ColumnarTable
    public typealias Intermediate = ColumnarTable
    public typealias Output = Base

    public var preprocessor: Preprocessor
    public var estimator: Base

    /// The column holding the target, which the preprocessor must not touch.
    public var annotationColumn: String

    public init(_ preprocessor: Preprocessor, _ estimator: Base, annotationColumn: String) {
        self.preprocessor = preprocessor
        self.estimator = estimator
        self.annotationColumn = annotationColumn
    }

    public func makeTransformer() -> Transformer {
        Transformer(preprocessor, estimator.makeTransformer())
    }

    /// The update, on the same terms as the unsupervised one: the preprocessor as the fit left it,
    /// the inner estimator on its output.
    public func update(_ transformer: inout Transformer, with input: Input) throws {
        var features = input
        if !annotationColumn.isEmpty { features.removeColumn(named: annotationColumn) }
        try estimator.update(&transformer.estimator, with: transformer.preprocessor.transformed(features))
    }
}
