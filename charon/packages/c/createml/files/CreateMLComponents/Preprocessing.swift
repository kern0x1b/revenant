import Foundation

public struct ComposedTransformer<Preprocessor, Fitted> {
    public var preprocessor: Preprocessor
    public var estimator: Fitted

    public init(_ preprocessor: Preprocessor, _ estimator: Fitted) {
        self.preprocessor = preprocessor
        self.estimator = estimator
    }
}

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

    public func preprocessed(from training: Input) throws -> Intermediate {
        try preprocessor.transformed(training)
    }

    public func fitted(on training: Input) throws -> Transformer {
        let fitted = preprocessor
        return Transformer(fitted, try estimator.fitted(on: fitted.transformed(training)))
    }
}

public struct PreprocessingSupervisedEstimator<Preprocessor: ColumnarTransformer, Base: SupervisedEstimator> {
    public typealias Transformer = ComposedTransformer<Preprocessor, Base.Transformer>
    public typealias Input = ColumnarTable
    public typealias Intermediate = ColumnarTable
    public typealias Output = Base

    public var preprocessor: Preprocessor
    public var estimator: Base

    public var annotationColumn: String

    public init(_ preprocessor: Preprocessor, _ estimator: Base, annotationColumn: String) {
        self.preprocessor = preprocessor
        self.estimator = estimator
        self.annotationColumn = annotationColumn
    }

    public func preprocessed(from training: Input) throws -> Intermediate {
        let fitted = try preprocessor.fitted(on: featuresOnly(from: training))
        var transformed = fitted.transformed(featuresOnly(from: training))
        if let target = training.column(annotationColumn) {
            transformed.set(target, named: annotationColumn)
        }
        return transformed
    }

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

    public func makeTransformer() -> Transformer {
        Transformer(preprocessor, estimator.makeTransformer())
    }

    public func preprocessed(from training: Input) throws -> Intermediate {
        try preprocessor.transformed(training)
    }

    public func update(_ transformer: inout Transformer, with input: Input) throws {
        try estimator.update(&transformer.estimator, with: transformer.preprocessor.transformed(input))
    }
}

public struct PreprocessingUpdatableSupervisedEstimator<Preprocessor: ColumnarTransformer, Base: UpdatableSupervisedEstimator> {
    public typealias Transformer = ComposedTransformer<Preprocessor, Base.Transformer>
    public typealias Input = ColumnarTable
    public typealias Intermediate = ColumnarTable
    public typealias Output = Base

    public var preprocessor: Preprocessor
    public var estimator: Base

    public var annotationColumn: String

    public init(_ preprocessor: Preprocessor, _ estimator: Base, annotationColumn: String) {
        self.preprocessor = preprocessor
        self.estimator = estimator
        self.annotationColumn = annotationColumn
    }

    public func makeTransformer() -> Transformer {
        Transformer(preprocessor, estimator.makeTransformer())
    }

    public func update(_ transformer: inout Transformer, with input: Input) throws {
        var features = input
        if !annotationColumn.isEmpty { features.removeColumn(named: annotationColumn) }
        try estimator.update(&transformer.estimator, with: transformer.preprocessor.transformed(features))
    }
}
