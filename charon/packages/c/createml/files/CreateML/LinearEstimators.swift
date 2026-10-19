import CoreML
import Foundation
import CreateMLComponents

public struct MLLinearRegressor {
    public enum ValidationData {
        case split(strategy: MLSplitStrategy)
        case table(MLDataTable)
        case none
    }

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
    public private(set) var model: LinearRegressorModel<Double>
    public private(set) var trainingMetrics: MLRegressorMetrics
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

    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let design = try Self.design(table, featureNames: featureColumns)
        return MLUntypedColumn(Self.predict(model, design).map { MLDataValue.double($0) })
    }

    public func evaluation(on labeledData: MLDataTable) -> MLRegressorMetrics {
        do {
            let set = try TabularEstimatorCoreBridge.make(labeledData, targetColumn: targetColumn,
                                                          featureColumns: featureColumns, classification: false)
            return MLRegressorMetrics(observations: set.targets, predictions: Self.predict(model, set.design))
        } catch {
            return Self.notComparable(error)
        }
    }

    private static func notComparable(_ error: Error) -> MLRegressorMetrics {
        var metrics = MLRegressorMetrics(observations: [], predictions: [])
        metrics.error = error
        return metrics
    }

    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}
