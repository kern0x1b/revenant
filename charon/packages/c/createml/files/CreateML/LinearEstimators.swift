// LinearEstimators.swift - MLLinearRegressor, over the linear fit in CreateMLComponents.
//
// The estimator takes an `MLDataTable` and gives back predictions as a column, as the six tabular
// estimators do. The arithmetic is `CreateMLComponents.LinearRegressor`: the ridge solve through the
// device's LAPACK, and the proximal iteration when an L1 penalty is set.
//
// Two things here are the framework's own and not the components':
//
// - **Feature rescaling.** `featureRescaling` is on by default and the components' `scaleFeatures`
//   is not read by the fit, so the centring and scaling are done here: every feature is centred and
//   divided by its unbiased deviation over the training rows, the fit runs on that, and the
//   coefficients are put back in the units the caller's columns are in. A fit with rescaling off is
//   the fit of the raw columns.
// - **Validation.** `ValidationData` is the framework's three answers: a split of the training table,
//   a table the caller holds out, or none. A validation table that cannot be read is an error, not a
//   missing metric: the caller asked for a validation and would otherwise get a model that was never
//   checked.
//
// **The penalties are refused, not answered.** With `l1Penalty` or `l2Penalty` non-zero, `init` throws
// `MLCreateError.penaltyNotMatched`. The unpenalised fit is the closed form, and it agrees with the host
// to 1e-14 (the host differential's "no penalty" rows). The host's penalised fit is not that closed form:
// its error rises steeply with the penalty, and it depends on `maxIterations`, which the closed form does
// not read. Matching it needs the framework's own optimiser, which is measured and not read, and until
// then an answer from the closed form would be a different model under the framework's name.
// facts/CreateML/LinearModels.md, "The penalties", has the measurements.
//
// Not here yet, and each is named in registry/CreateML.json rather than left out silently: the
// DataFrame initialisers and evaluation, the training jobs and sessions, the `model` property as
// CoreML's `MLModel` (it is the components' model), and `write`, which refuses. `write` refuses
// because the one writer this package has produces a `NeuralNetworkRegressor` that Core ML does not
// yet accept (facts/CreateML/Export.md), and a file Core ML cannot load is worse than the error.

import CoreML
import Foundation
import CreateMLComponents

public struct MLLinearRegressor {
    /// Where the validation of a fit comes from, in the framework's own three answers.
    public enum ValidationData {
        /// The training table is divided, and the part held out validates the fit.
        case split(strategy: MLSplitStrategy)
        /// The caller's own table validates the fit; the whole training table is trained on.
        case table(MLDataTable)
        /// The fit is not validated, and there are no validation metrics.
        case none
    }

    /// What a linear fit is allowed to be, in the framework's own names and defaults. The defaults
    /// are measured against the host's own `MLLinearRegressor.ModelParameters()`: 10 iterations, an L2
    /// penalty of 0.01, no L1 penalty, a step of 1, a convergence threshold of 0.01, feature rescaling
    /// on, and a split validation with an automatic strategy.
    public struct ModelParameters {
        public var validationData: MLDataTable?
        public var validation: ValidationData
        public var maxIterations: Int
        public var l1Penalty: Double
        public var l2Penalty: Double
        public var stepSize: Double
        public var convergenceThreshold: Double
        public var featureRescaling: Bool

        public init(validation: ValidationData, maxIterations: Int = 10, l1Penalty: Double = 0,
                    l2Penalty: Double = 0.01, stepSize: Double = 1.0, convergenceThreshold: Double = 0.01,
                    featureRescaling: Bool = true) {
            self.validationData = nil
            self.validation = validation
            self.maxIterations = maxIterations
            self.l1Penalty = l1Penalty
            self.l2Penalty = l2Penalty
            self.stepSize = stepSize
            self.convergenceThreshold = convergenceThreshold
            self.featureRescaling = featureRescaling
        }

        /// The framework's earlier spelling: a validation table, or the automatic split when there is
        /// none. Its `validationData` is the table it was given, as the framework's is.
        public init(validationData: MLDataTable? = nil, maxIterations: Int = 10, l1Penalty: Double = 0,
                    l2Penalty: Double = 0.01, stepSize: Double = 1.0, convergenceThreshold: Double = 0.01,
                    featureRescaling: Bool = true) {
            self.validationData = validationData
            self.validation = validationData.map { ValidationData.table($0) } ?? .split(strategy: .automatic)
            self.maxIterations = maxIterations
            self.l1Penalty = l1Penalty
            self.l2Penalty = l2Penalty
            self.stepSize = stepSize
            self.convergenceThreshold = convergenceThreshold
            self.featureRescaling = featureRescaling
        }
    }

    public var targetColumn: String
    public var featureColumns: [String]
    public var modelParameters: ModelParameters
    /// The fitted coefficients, the intercept first, in the units of the caller's columns. This is the
    /// components' model and not CoreML's `MLModel`: see the file's header for what is not here yet.
    public private(set) var model: LinearRegressorModel<Double>
    public private(set) var trainingMetrics: MLRegressorMetrics
    /// The metrics of the validation set. Without one they are not comparable, and carry that as their
    /// `error`, as the framework's do: the property is not optional.
    public private(set) var validationMetrics: MLRegressorMetrics

    public init(trainingData: MLDataTable, targetColumn: String, featureColumns: [String]? = nil,
                parameters: ModelParameters = ModelParameters()) throws {
        guard parameters.l1Penalty == 0 && parameters.l2Penalty == 0 else {
            throw MLCreateError.penaltyNotMatched(
                "The penalties are not matched to the framework yet: this build fits the unpenalised model only, so "
                + "l1Penalty and l2Penalty must be 0. The framework's penalised fit is a different model, which the "
                + "port does not answer (facts/CreateML/LinearModels.md).")
        }
        let (training, validation) = Self.partition(trainingData, validation: parameters.validation)
        let trainingSet = try TabularEstimatorCoreBridge.make(training, targetColumn: targetColumn,
                                                              featureColumns: featureColumns, classification: false)
        let model = try Self.fit(trainingSet, parameters: parameters)
        self.targetColumn = targetColumn
        self.featureColumns = trainingSet.featureNames
        self.modelParameters = parameters
        self.model = model
        self.trainingMetrics = MLRegressorMetrics(
            observations: trainingSet.targets, predictions: Self.predict(model, trainingSet.design))
        if let validation = validation {
            let validationSet = try TabularEstimatorCoreBridge.make(validation, targetColumn: targetColumn,
                                                                    featureColumns: trainingSet.featureNames,
                                                                    classification: false)
            self.validationMetrics = MLRegressorMetrics(
                observations: validationSet.targets, predictions: Self.predict(model, validationSet.design))
        } else {
            self.validationMetrics = Self.notComparable(MLRegressorMetricsError.noValidationSet)
        }
    }

    /// The training rows and the validation rows, as the validation asks for them.
    private static func partition(_ table: MLDataTable, validation: ValidationData) -> (MLDataTable, MLDataTable?) {
        switch validation {
        case .none:
            return (table, nil)
        case .table(let held):
            return (table, held)
        case .split(let strategy):
            return TabularEstimatorCore.split(table, classification: false, strategy: strategy,
                                              seed: CreateMLComponents.SeededGenerator.timestampSeed())
        }
    }

    /// The fit. With rescaling, the design is centred and scaled column by column, fitted there, and
    /// the answer is carried back: a coefficient divides by its column's deviation, and the intercept
    /// absorbs each column's mean.
    private static func fit(_ set: TabularTrainingSet, parameters: ModelParameters) throws -> LinearRegressorModel<Double> {
        let design = set.design
        let width = design.columns
        var means = [Double](repeating: 0, count: width)
        var deviations = [Double](repeating: 1, count: width)
        if parameters.featureRescaling {
            for column in 0..<width {
                let values = design.contiguousColumn(column)
                means[column] = RowMatrix.mean(values)
                let deviation = RowMatrix.standardDeviation(values)
                deviations[column] = deviation > 0 ? deviation : 1
            }
        }
        let rows: [AnnotatedFeature<MLShapedArray<Double>, Double>] = (0..<design.rows).map { row in
            let features = (0..<width).map { (design[row, $0] - means[$0]) / deviations[$0] }
            return AnnotatedFeature(feature: MLShapedArray<Double>(scalars: features, shape: [width]),
                                    annotation: set.targets[row])
        }
        let regressor = LinearRegressor<Double>(configuration: LinearRegressorConfiguration(
            l2Penalty: parameters.l2Penalty, l1Penalty: parameters.l1Penalty,
            maximumIterations: parameters.maxIterations, stepSize: parameters.stepSize,
            convergenceThreshold: parameters.convergenceThreshold, scaleFeatures: parameters.featureRescaling))
        let fitted = try regressor.fitted(to: rows)
        let scaled = fitted.coefficients
        var coefficients = [Double](repeating: 0, count: width + 1)
        var intercept = scaled[0]
        for column in 0..<width {
            let weight = scaled[column + 1] / deviations[column]
            coefficients[column + 1] = weight
            intercept -= weight * means[column]
        }
        coefficients[0] = intercept
        return LinearRegressorModel<Double>(coefficients: coefficients)
    }

    /// The prediction for each row of a design: the intercept and the dot product of the row and the
    /// weights.
    private static func predict(_ model: LinearRegressorModel<Double>, _ design: RowMatrix) -> [Double] {
        let coefficients = model.coefficients
        return (0..<design.rows).map { row in
            var total = coefficients[0]
            for column in 0..<design.columns {
                total += design[row, column] * coefficients[column + 1]
            }
            return total
        }
    }

    /// The design of a table for prediction. The table need not hold the target: a caller predicting
    /// on new rows has none, which is why this does not go through the training bridge.
    private static func design(_ table: MLDataTable, featureNames: [String]) throws -> RowMatrix {
        let columns = TabularEstimatorCoreBridge.columnar(table)
        var design = RowMatrix(rows: table.count, columns: featureNames.count)
        for (index, name) in featureNames.enumerated() {
            guard let column = columns.column(name) else {
                throw TabularFittingError.noFeatureColumn(name)
            }
            guard let values = column.numeric else {
                throw TabularFittingError.featureIsCategorical(name)
            }
            let missing = values.filter { $0 == nil }.count
            if missing > 0 {
                throw TabularFittingError.featureHasMissingValues(name, missing)
            }
            for row in 0..<table.count {
                design[row, index] = values[row] ?? 0
            }
        }
        return design
    }

    /// The predictions for a table of the same shape, as a column of doubles.
    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let design = try Self.design(table, featureNames: featureColumns)
        return MLUntypedColumn(Self.predict(model, design).map { MLDataValue.double($0) })
    }

    /// The metrics of a labelled table. The framework's own is non-throwing and reports a table it
    /// cannot read through the metrics' `error`, which is what this does.
    public func evaluation(on labeledData: MLDataTable) -> MLRegressorMetrics {
        do {
            let set = try TabularEstimatorCoreBridge.make(labeledData, targetColumn: targetColumn,
                                                          featureColumns: featureColumns, classification: false)
            return MLRegressorMetrics(observations: set.targets, predictions: Self.predict(model, set.design))
        } catch {
            return Self.notComparable(error)
        }
    }

    /// Metrics that could not be computed, carrying the reason as their `error`.
    private static func notComparable(_ error: Error) -> MLRegressorMetrics {
        var metrics = MLRegressorMetrics(observations: [], predictions: [])
        metrics.error = error
        return metrics
    }

    /// The export is refused. The components' writer produces a `NeuralNetworkRegressor` of one inner
    /// product, and Core ML does not yet accept that shape (facts/CreateML/Export.md), so writing it
    /// would hand the caller a file that fails at load time.
    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}
