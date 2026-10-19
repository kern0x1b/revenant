import CoreML
import Foundation
import CreateMLComponents

public struct MLTrainingDataSplit {
    public var proportion: Double
    public var strategy: MLSplitStrategy
    public var seed: UInt64

    public init(proportion: Double = 0.8, strategy: MLSplitStrategy = .automatic, seed: UInt64 = CreateMLComponents.SeededGenerator.timestampSeed()) {
        self.proportion = proportion
        self.strategy = strategy
        self.seed = seed
    }
}

public enum MLSplitStrategy: String, CaseIterable {
    case random
    case stratified
    case automatic
}

public struct MLTrainingDataValidation {
    public var table: MLDataTable
    public var metrics: [String: Double]
}

public struct MLTrainingDataValidationData {
    public enum Validation {
        case split(proportion: Double, strategy: MLSplitStrategy, seed: UInt64)
        case none
    }

    public var validationData: MLDataTable?
    public var validation: Validation

    public init(validationData: MLDataTable? = nil,
                validation: Validation = .split(proportion: 0.8, strategy: .automatic,
                                                seed: CreateMLComponents.SeededGenerator.timestampSeed())) {
        self.validationData = validationData
        self.validation = validation
    }

    public static func split(proportion: Double = 0.8, strategy: MLSplitStrategy = .automatic,
                             seed: UInt64 = CreateMLComponents.SeededGenerator.timestampSeed()) -> Validation {
        .split(proportion: proportion, strategy: strategy, seed: seed)
    }
}

public struct MLRegressorMetrics: CustomStringConvertible, CustomDebugStringConvertible {
    public var maximumError: Double
    public var rootMeanSquaredError: Double
    public var error: Error?

    public init(maximumError: Double, rootMeanSquaredError: Double) {
        self.maximumError = maximumError
        self.rootMeanSquaredError = rootMeanSquaredError
        self.error = nil
    }

    public var isValid: Bool { error == nil }

    public init(observations: [Double], predictions: [Double]) {
        guard observations.count == predictions.count, !observations.isEmpty else {
            maximumError = .nan
            rootMeanSquaredError = .nan
            error = MLRegressorMetricsError.notComparable(observations.count, predictions.count)
            return
        }
        var squared = 0.0
        var largest = 0.0
        for (target, prediction) in zip(observations, predictions) {
            let difference = prediction - target
            squared += difference * difference
            largest = max(largest, abs(difference))
        }
        maximumError = largest
        rootMeanSquaredError = (squared / Double(observations.count)).squareRoot()
        error = nil
    }

    public var description: String { "Maximum error: \(maximumError)\nRoot mean squared error: \(rootMeanSquaredError)" }
    public var debugDescription: String { description }
    public var playgroundDescription: Any { debugDescription }
}

public enum MLRegressorMetricsError: Error, CustomStringConvertible {
    case notComparable(Int, Int)
    case noValidationSet

    public var description: String {
        switch self {
        case .notComparable(let observations, let predictions):
            return "\(observations) observations and \(predictions) predictions are not the same length."
        case .noValidationSet:
            return "The model was fitted without a validation set, so there are no validation metrics."
        }
    }
}

public struct MLClassifierMetrics: CustomStringConvertible, CustomDebugStringConvertible {
    public var classificationError: Double
    public var confusion: MLDataTable
    public var precisionRecall: MLDataTable
    public var error: Error?

    public init(classificationError: Double, confusion: MLDataTable, precisionRecall: MLDataTable) {
        self.classificationError = classificationError
        self.confusion = confusion
        self.precisionRecall = precisionRecall
        self.error = nil
    }

    public var isValid: Bool { error == nil }

    public var accuracy: Double { 1 - classificationError }

    public init(observations: [String], predictions: [String], labelOrder: [String]) {
        guard observations.count == predictions.count, !observations.isEmpty else {
            classificationError = .nan
            confusion = MLDataTable()
            precisionRecall = MLDataTable()
            error = MLClassifierMetricsError.notComparable(observations.count, predictions.count)
            return
        }
        var right = 0
        var counted = [String: [String: Int]]()
        for label in labelOrder { counted[label] = [:] }
        for (target, prediction) in zip(observations, predictions) {
            if target == prediction { right += 1 }
            counted[target, default: [:]][prediction, default: 0] += 1
        }
        classificationError = 1 - Double(right) / Double(observations.count)

        var confusion = MLDataTable()
        let corner = labelOrder.isEmpty ? "True\\Predict" : "True\\(labelOrder[0])"
        var first = MLUntypedColumn([MLDataValue.string(corner)], name: "True\\Predict")
        for label in labelOrder {
            first.append(contentsOf: MLUntypedColumn([MLDataValue.string(label)]))
        }
        confusion.addColumn(first, named: "True\\Predict")
        for label in labelOrder {
            var row = MLUntypedColumn([MLDataValue.string(label)], name: "label")
            for predicted in labelOrder {
                row.append(contentsOf: MLUntypedColumn([MLDataValue.int(Int64(counted[label]?[predicted] ?? 0))]))
            }
            confusion.addColumn(row, named: label)
        }
        self.confusion = confusion

        var table = MLDataTable()
        table.addColumn(MLUntypedColumn(labelOrder.map { MLDataValue.string($0) }, name: "Class"),
                        named: "Class")
        var precisions = [MLDataValue]()
        var recalls = [MLDataValue]()
        for label in labelOrder {
            let predicted = labelOrder.reduce(0) { $0 + (counted[$1]?[label] ?? 0) }
            let actual = labelOrder.reduce(0) { $0 + (counted[label]?[$1] ?? 0) }
            precisions.append(.double(predicted > 0 ? Double(counted[label]?[label] ?? 0) / Double(predicted) : 0))
            recalls.append(.double(actual > 0 ? Double(counted[label]?[label] ?? 0) / Double(actual) : 0))
        }
        table.addColumn(MLUntypedColumn(precisions, name: "precision"), named: "precision")
        table.addColumn(MLUntypedColumn(recalls, name: "recall"), named: "recall")
        self.precisionRecall = table
        self.error = nil
    }

    public var description: String { "Classification error: \(classificationError)" }
    public var debugDescription: String { description }
    public var playgroundDescription: Any { debugDescription }
}

public enum MLClassifierMetricsError: Error, CustomStringConvertible {
    case notComparable(Int, Int)

    public var description: String {
        switch self {
        case .notComparable(let observations, let predictions):
            return "\(observations) labels and \(predictions) predictions are not the same length."
        }
    }
}

public enum MLCreateError: Error, CustomStringConvertible, Equatable {
    case invalidTrainingDataTable(String)
    case invalidFeatureColumns(String)
    case invalidTargetColumn(String)
    case modelCompatibility(String)
    case notSupportedOnThisDevice(String)
    case cannotWriteModel(String)
    case penaltyNotMatched(String)

    public var description: String {
        switch self {
        case .invalidTrainingDataTable(let text): return text
        case .invalidFeatureColumns(let text): return text
        case .invalidTargetColumn(let text): return text
        case .modelCompatibility(let text): return text
        case .notSupportedOnThisDevice(let text): return text
        case .cannotWriteModel(let text): return text
        case .penaltyNotMatched(let text): return text
        }
    }
}

public let MLCreateErrorDomain = "MLCreateErrorDomain"

public enum MLCreateErrorCode: Int, CaseIterable {
    case invalidTrainingDataInCreate = 1
    case invalidFeatureColumnsInCreate = 2
    case invalidTargetColumnInCreate = 3
    case modelCompatibilityError = 4
    case notSupportedOnThisDevice = 5
    case cannotWriteModel = 6

    public var error: MLCreateError {
        switch self {
        case .invalidTrainingDataInCreate:
            return .invalidTrainingDataTable("The training data table is not usable: its columns are of different lengths, or it has no rows.")
        case .invalidFeatureColumnsInCreate:
            return .invalidFeatureColumns("The feature columns are not usable: one of them is not in the table, or holds something other than numbers.")
        case .invalidTargetColumnInCreate:
            return .invalidTargetColumn("The target column is not usable: it is not in the table, or holds something other than numbers.")
        case .modelCompatibilityError:
            return .modelCompatibility("The model is not compatible with this device's Core ML.")
        case .notSupportedOnThisDevice:
            return .notSupportedOnThisDevice("This estimator is not supported on this device.")
        case .cannotWriteModel:
            return .cannotWriteModel("The model cannot be written from this build of CreateML.")
        }
    }
}

public enum TabularEstimatorCore {
    public static func split(_ table: MLDataTable, classification: Bool,
                             strategy: MLSplitStrategy, seed: UInt64) -> (MLDataTable, MLDataTable?) {
        guard table.count > 1 else { return (table, nil) }
        switch strategy {
        case .random:
            return table.randomSplit(by: 0.8, seed: seed)
        case .stratified:
            guard classification, let target = table["target"] else {
                return table.randomSplit(by: 0.8, seed: seed)
            }
            let parts = table.stratifiedSplit(proportions: [0.8, 0.2], on: target, seed: seed)
            return (parts[0], parts.count > 1 ? parts[1] : nil)
        case .automatic:
            return classification && table["target"] != nil
                ? split(table, classification: true, strategy: .stratified, seed: seed)
                : split(table, classification: false, strategy: .random, seed: seed)
        }
    }
}

public struct MLDecisionTreeRegressor {
    public struct ModelParameters {
        public var validationData: MLDataTable?
        public var validation: MLTrainingDataValidationData.Validation
        public var maxDepth: Int
        public var minLossReduction: Double
        public var minChildWeight: Double
        public var randomSeed: Int

        public init(validation: MLTrainingDataValidationData.Validation, maxDepth: Int = 6,
                    minLossReduction: Double = 0, minChildWeight: Double = 0.1, randomSeed: Int = 42) {
            self.validationData = nil
            self.validation = validation
            self.maxDepth = maxDepth
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
        }

        public init(validationData: MLDataTable? = nil, maxDepth: Int = 6, minLossReduction: Double = 0,
                    minChildWeight: Double = 0.1, randomSeed: Int = 42) {
            self.validationData = validationData
            self.validation = .none
            self.maxDepth = maxDepth
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
        }
    }
    public var targetColumn: String
    public var featureColumns: [String]
    public var modelParameters: ModelParameters
    public private(set) var model: MLDecisionTreeModel
    public private(set) var trainingMetrics: MLRegressorMetrics
    public private(set) var validationMetrics: MLRegressorMetrics?


    public init(trainingData: MLDataTable, targetColumn: String, featureColumns: [String]? = nil,
                parameters: ModelParameters = ModelParameters()) throws {
        let (training, validation) = TabularEstimatorCore.split(
            trainingData, classification: false, strategy: .automatic, seed: UInt64(bitPattern: Int64(parameters.randomSeed)))
        let (model, trainingSet) = try Self.fit(training, targetColumn: targetColumn,
                                                featureColumns: featureColumns, parameters: parameters)
        self.targetColumn = targetColumn
        self.featureColumns = trainingSet.featureNames
        self.modelParameters = parameters
        self.model = model
        self.trainingMetrics = MLRegressorMetrics(
            observations: trainingSet.targets, predictions: model.predictAll(trainingSet.design))
        if let validation = validation, let validationSet = try? Self.set(validation, targetColumn: targetColumn,
                                                                         featureColumns: trainingSet.featureNames) {
            self.validationMetrics = MLRegressorMetrics(
                observations: validationSet.targets, predictions: model.predictAll(validationSet.design))
        } else {
            self.validationMetrics = nil
        }
    }

    private static func set(_ table: MLDataTable, targetColumn: String, featureColumns: [String]?) throws -> TabularTrainingSet {
        try TabularEstimatorCoreBridge.make(table, targetColumn: targetColumn,
                                            featureColumns: featureColumns, classification: false)
    }

    private static func fit(_ table: MLDataTable, targetColumn: String, featureColumns: [String]?,
                            parameters: ModelParameters) throws -> (MLDecisionTreeModel, TabularTrainingSet) {
        let trainingSet = try Self.set(table, targetColumn: targetColumn, featureColumns: featureColumns)
        var generator = CreateMLComponents.SeededGenerator(seed: UInt64(bitPattern: Int64(parameters.randomSeed)))
        let model = CreateMLComponents.DecisionTreeFitter.fit(
            trainingSet,
            parameters: CreateMLComponents.TreeParameters(maximumDepth: parameters.maxDepth,
                                                           minimumSamplesToSplit: 2, minimumSamplesToLeaf: 1,
                                                           minimumLossReduction: parameters.minLossReduction,
                                                           seed: UInt64(bitPattern: Int64(parameters.randomSeed))),
            generator: &generator)
        return (MLDecisionTreeModel(model, trainingSet.featureNames), trainingSet)
    }

    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let set = try Self.set(table, targetColumn: targetColumn, featureColumns: featureColumns)
        return MLUntypedColumn(model.predictAll(set.design).map { MLDataValue.double($0) })
    }

    public func evaluation(on labeledData: MLDataTable) -> MLRegressorMetrics {
        guard let set = try? Self.set(labeledData, targetColumn: targetColumn, featureColumns: featureColumns) else {
            return MLRegressorMetrics(observations: [], predictions: [])
        }
        return MLRegressorMetrics(observations: set.targets, predictions: model.predictAll(set.design))
    }

    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}

public struct MLDecisionTreeModel {
    public let tree: CreateMLComponents.DecisionTreeModel
    public let featureNames: [String]

    public init(_ tree: CreateMLComponents.DecisionTreeModel, _ featureNames: [String]) {
        self.tree = tree
        self.featureNames = featureNames
    }

    public func predictAll(_ design: CreateMLComponents.RowMatrix) -> [Double] {
        tree.predictAll(design)
    }
}

public struct MLRandomForestRegressor {
    public struct ModelParameters {
        public var validationData: MLDataTable?
        public var validation: MLTrainingDataValidationData.Validation
        public var maxDepth: Int
        public var maxIterations: Int
        public var minLossReduction: Double
        public var minChildWeight: Double
        public var randomSeed: Int
        public var rowSubsample: Double
        public var columnSubsample: Double

        public init(validation: MLTrainingDataValidationData.Validation, maxDepth: Int = 6,
                    maxIterations: Int = 10, minLossReduction: Double = 0, minChildWeight: Double = 0.1,
                    randomSeed: Int = 42, rowSubsample: Double = 0.8, columnSubsample: Double = 0.8) {
            self.validationData = nil
            self.validation = validation
            self.maxDepth = maxDepth
            self.maxIterations = maxIterations
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
            self.rowSubsample = rowSubsample
            self.columnSubsample = columnSubsample
        }

        public init(validationData: MLDataTable? = nil, maxDepth: Int = 6, maxIterations: Int = 10,
                    minLossReduction: Double = 0, minChildWeight: Double = 0.1, randomSeed: Int = 42,
                    rowSubsample: Double = 0.8, columnSubsample: Double = 0.8) {
            self.validationData = validationData
            self.validation = .none
            self.maxDepth = maxDepth
            self.maxIterations = maxIterations
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
            self.rowSubsample = rowSubsample
            self.columnSubsample = columnSubsample
        }
    }
    public var targetColumn: String
    public var featureColumns: [String]
    public private(set) var model: MLRandomForestModel
    public private(set) var trainingMetrics: MLRegressorMetrics
    public private(set) var validationMetrics: MLRegressorMetrics?


    public init(trainingData: MLDataTable, targetColumn: String, featureColumns: [String]? = nil,
                parameters: ModelParameters = ModelParameters()) throws {
        let (training, validation) = TabularEstimatorCore.split(
            trainingData, classification: false, strategy: .automatic, seed: UInt64(bitPattern: Int64(parameters.randomSeed)))
        let set = try TabularEstimatorCoreBridge.make(training, targetColumn: targetColumn,
                                                      featureColumns: featureColumns, classification: false)
        let forest = CreateMLComponents.RandomForestFitter.fit(set, parameters: CreateMLComponents.RandomForestParameters(
            numberOfIterations: parameters.maxIterations, maximumDepth: parameters.maxDepth,
            minimumLossReduction: parameters.minLossReduction, minimumChildWeight: parameters.minChildWeight,
            rowSubsample: parameters.rowSubsample,
            maximumFeatures: .fraction(parameters.columnSubsample),
            seed: UInt64(bitPattern: Int64(parameters.randomSeed))))
        self.targetColumn = targetColumn
        self.featureColumns = set.featureNames
        self.model = MLRandomForestModel(forest, set.featureNames)
        self.trainingMetrics = MLRegressorMetrics(observations: set.targets, predictions: forest.predictAll(set.design))
        if let validation = validation,
           let validationSet = try? TabularEstimatorCoreBridge.make(validation, targetColumn: targetColumn,
                                                                    featureColumns: set.featureNames, classification: false) {
            self.validationMetrics = MLRegressorMetrics(observations: validationSet.targets,
                                                         predictions: forest.predictAll(validationSet.design))
        } else {
            self.validationMetrics = nil
        }
    }

    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let set = try TabularEstimatorCoreBridge.make(table, targetColumn: targetColumn,
                                                       featureColumns: featureColumns, classification: false)
        return MLUntypedColumn(model.predictAll(set.design).map { MLDataValue.double($0) })
    }

    public func evaluation(on labeledData: MLDataTable) -> MLRegressorMetrics {
        guard let set = try? TabularEstimatorCoreBridge.make(labeledData, targetColumn: targetColumn,
                                                             featureColumns: featureColumns, classification: false) else {
            return MLRegressorMetrics(observations: [], predictions: [])
        }
        return MLRegressorMetrics(observations: set.targets, predictions: model.predictAll(set.design))
    }

    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}

public struct MLRandomForestModel {
    public let forest: CreateMLComponents.RandomForestModel
    public let featureNames: [String]

    public init(_ forest: CreateMLComponents.RandomForestModel, _ featureNames: [String]) {
        self.forest = forest
        self.featureNames = featureNames
    }

    public func predictAll(_ design: CreateMLComponents.RowMatrix) -> [Double] {
        forest.predictAll(design)
    }
}

public struct MLBoostedTreeRegressor {
    public struct ModelParameters {
        public var validationData: MLDataTable?
        public var validation: MLTrainingDataValidationData.Validation
        public var maxDepth: Int
        public var maxIterations: Int
        public var minLossReduction: Double
        public var minChildWeight: Double
        public var randomSeed: Int
        public var stepSize: Double
        public var earlyStoppingRounds: Int?
        public var rowSubsample: Double
        public var columnSubsample: Double

        public init(validation: MLTrainingDataValidationData.Validation, maxDepth: Int = 6,
                    maxIterations: Int = 10, minLossReduction: Double = 0, minChildWeight: Double = 0.1,
                    randomSeed: Int = 42, stepSize: Double = 0.3, earlyStoppingRounds: Int? = nil,
                    rowSubsample: Double = 1.0, columnSubsample: Double = 1.0) {
            self.validationData = nil
            self.validation = validation
            self.maxDepth = maxDepth
            self.maxIterations = maxIterations
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
            self.stepSize = stepSize
            self.earlyStoppingRounds = earlyStoppingRounds
            self.rowSubsample = rowSubsample
            self.columnSubsample = columnSubsample
        }

        public init(validationData: MLDataTable? = nil, maxDepth: Int = 6, maxIterations: Int = 10,
                    minLossReduction: Double = 0, minChildWeight: Double = 0.1, randomSeed: Int = 42,
                    stepSize: Double = 0.3, earlyStoppingRounds: Int? = nil,
                    rowSubsample: Double = 1.0, columnSubsample: Double = 1.0) {
            self.validationData = validationData
            self.validation = .none
            self.maxDepth = maxDepth
            self.maxIterations = maxIterations
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
            self.stepSize = stepSize
            self.earlyStoppingRounds = earlyStoppingRounds
            self.rowSubsample = rowSubsample
            self.columnSubsample = columnSubsample
        }
    }
    public var targetColumn: String
    public var featureColumns: [String]
    public private(set) var model: MLBoostedTreeModel
    public private(set) var trainingMetrics: MLRegressorMetrics
    public private(set) var validationMetrics: MLRegressorMetrics?


    public init(trainingData: MLDataTable, targetColumn: String, featureColumns: [String]? = nil,
                parameters: ModelParameters = ModelParameters()) throws {
        let (training, validation) = TabularEstimatorCore.split(
            trainingData, classification: false, strategy: .automatic, seed: UInt64(bitPattern: Int64(parameters.randomSeed)))
        let set = try TabularEstimatorCoreBridge.make(training, targetColumn: targetColumn,
                                                      featureColumns: featureColumns, classification: false)
        let forest = CreateMLComponents.BoostedTreeFitter.fit(set, parameters: CreateMLComponents.BoostedTreeParameters(
            numberOfIterations: parameters.maxIterations, maximumDepth: parameters.maxDepth,
            minimumLossReduction: parameters.minLossReduction, learningRate: parameters.stepSize,
            rowSubsample: parameters.rowSubsample, columnSubsample: parameters.columnSubsample,
            loss: .squaredError, seed: UInt64(bitPattern: Int64(parameters.randomSeed))))
        self.targetColumn = targetColumn
        self.featureColumns = set.featureNames
        self.model = MLBoostedTreeModel(forest, set.featureNames)
        self.trainingMetrics = MLRegressorMetrics(observations: set.targets, predictions: forest.predictAll(set.design))
        if let validation = validation,
           let validationSet = try? TabularEstimatorCoreBridge.make(validation, targetColumn: targetColumn,
                                                                    featureColumns: set.featureNames, classification: false) {
            self.validationMetrics = MLRegressorMetrics(observations: validationSet.targets,
                                                         predictions: forest.predictAll(validationSet.design))
        } else {
            self.validationMetrics = nil
        }
    }

    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let set = try TabularEstimatorCoreBridge.make(table, targetColumn: targetColumn,
                                                       featureColumns: featureColumns, classification: false)
        return MLUntypedColumn(model.predictAll(set.design).map { MLDataValue.double($0) })
    }

    public func evaluation(on labeledData: MLDataTable) -> MLRegressorMetrics {
        guard let set = try? TabularEstimatorCoreBridge.make(labeledData, targetColumn: targetColumn,
                                                             featureColumns: featureColumns, classification: false) else {
            return MLRegressorMetrics(observations: [], predictions: [])
        }
        return MLRegressorMetrics(observations: set.targets, predictions: model.predictAll(set.design))
    }

    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}

public struct MLBoostedTreeModel {
    public let forest: CreateMLComponents.BoostedTreeModel
    public let featureNames: [String]

    public init(_ forest: CreateMLComponents.BoostedTreeModel, _ featureNames: [String]) {
        self.forest = forest
        self.featureNames = featureNames
    }

    public func predictAll(_ design: CreateMLComponents.RowMatrix) -> [Double] {
        forest.predictAll(design)
    }
}

public struct MLDecisionTreeClassifier {
    public struct ModelParameters {
        public var validationData: MLDataTable?
        public var validation: MLTrainingDataValidationData.Validation
        public var maxDepth: Int
        public var minLossReduction: Double
        public var minChildWeight: Double
        public var randomSeed: Int

        public init(validation: MLTrainingDataValidationData.Validation, maxDepth: Int = 6,
                    minLossReduction: Double = 0, minChildWeight: Double = 0.1, randomSeed: Int = 42) {
            self.validationData = nil
            self.validation = validation
            self.maxDepth = maxDepth
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
        }

        public init(validationData: MLDataTable? = nil, maxDepth: Int = 6, minLossReduction: Double = 0,
                    minChildWeight: Double = 0.1, randomSeed: Int = 42) {
            self.validationData = validationData
            self.validation = .none
            self.maxDepth = maxDepth
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
        }
    }
    public var targetColumn: String
    public var featureColumns: [String]
    public private(set) var model: MLDecisionTreeClassifierModel
    public private(set) var trainingMetrics: MLClassifierMetrics
    public private(set) var validationMetrics: MLClassifierMetrics?


    public init(trainingData: MLDataTable, targetColumn: String, featureColumns: [String]? = nil,
                parameters: ModelParameters = ModelParameters()) throws {
        let (training, validation) = TabularEstimatorCore.split(
            trainingData, classification: true, strategy: .automatic, seed: UInt64(bitPattern: Int64(parameters.randomSeed)))
        let set = try TabularEstimatorCoreBridge.make(training, targetColumn: targetColumn,
                                                      featureColumns: featureColumns, classification: true)
        let seed = UInt64(bitPattern: Int64(parameters.randomSeed))
        var generator = CreateMLComponents.SeededGenerator(seed: seed)
        let tree = CreateMLComponents.DecisionTreeFitter.fit(set, parameters: CreateMLComponents.TreeParameters(
            maximumDepth: parameters.maxDepth, minimumSamplesToSplit: 2, minimumSamplesToLeaf: 1,
            minimumLossReduction: parameters.minLossReduction,
            seed: UInt64(bitPattern: Int64(parameters.randomSeed))), generator: &generator)
        self.targetColumn = targetColumn
        self.featureColumns = set.featureNames
        self.model = MLDecisionTreeClassifierModel(tree, set.featureNames)
        self.trainingMetrics = MLClassifierMetrics(observations: set.targetLabels,
                                                    predictions: (0..<set.design.rows).map { tree.predictLabel(set.design, index: $0) },
                                                    labelOrder: tree.labelOrder)
        if let validation = validation,
           let validationSet = try? TabularEstimatorCoreBridge.make(validation, targetColumn: targetColumn,
                                                                    featureColumns: set.featureNames, classification: true) {
            self.validationMetrics = MLClassifierMetrics(
                observations: validationSet.targetLabels,
                predictions: (0..<validationSet.design.rows).map { tree.predictLabel(validationSet.design, index: $0) },
                labelOrder: tree.labelOrder)
        } else {
            self.validationMetrics = nil
        }
    }

    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let set = try TabularEstimatorCoreBridge.make(table, targetColumn: targetColumn,
                                                       featureColumns: featureColumns, classification: true)
        return MLUntypedColumn((0..<set.design.rows).map { index in
            MLDataValue.string(model.predictLabel(set.design, index: index))
        })
    }

    public func evaluation(on labeledData: MLDataTable) -> MLClassifierMetrics {
        guard let set = try? TabularEstimatorCoreBridge.make(labeledData, targetColumn: targetColumn,
                                                             featureColumns: featureColumns, classification: true) else {
            return MLClassifierMetrics(observations: [], predictions: [], labelOrder: [])
        }
        return MLClassifierMetrics(
            observations: set.targetLabels,
            predictions: (0..<set.design.rows).map { model.predictLabel(set.design, index: $0) },
            labelOrder: model.labelOrder)
    }

    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}

public struct MLDecisionTreeClassifierModel {
    public let tree: CreateMLComponents.DecisionTreeModel
    public let featureNames: [String]
    public var labelOrder: [String] { tree.labelOrder }

    public init(_ tree: CreateMLComponents.DecisionTreeModel, _ featureNames: [String]) {
        self.tree = tree
        self.featureNames = featureNames
    }

    public func predictLabel(_ design: CreateMLComponents.RowMatrix, index: Int) -> String {
        tree.predictLabel(design, index: index)
    }
}

public struct MLRandomForestClassifier {
    public struct ModelParameters {
        public var validationData: MLDataTable?
        public var validation: MLTrainingDataValidationData.Validation
        public var maxDepth: Int
        public var maxIterations: Int
        public var minLossReduction: Double
        public var minChildWeight: Double
        public var randomSeed: Int
        public var rowSubsample: Double
        public var columnSubsample: Double

        public init(validation: MLTrainingDataValidationData.Validation, maxDepth: Int = 6,
                    maxIterations: Int = 10, minLossReduction: Double = 0, minChildWeight: Double = 0.1,
                    randomSeed: Int = 42, rowSubsample: Double = 0.8, columnSubsample: Double = 0.8) {
            self.validationData = nil
            self.validation = validation
            self.maxDepth = maxDepth
            self.maxIterations = maxIterations
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
            self.rowSubsample = rowSubsample
            self.columnSubsample = columnSubsample
        }

        public init(validationData: MLDataTable? = nil, maxDepth: Int = 6, maxIterations: Int = 10,
                    minLossReduction: Double = 0, minChildWeight: Double = 0.1, randomSeed: Int = 42,
                    rowSubsample: Double = 0.8, columnSubsample: Double = 0.8) {
            self.validationData = validationData
            self.validation = .none
            self.maxDepth = maxDepth
            self.maxIterations = maxIterations
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
            self.rowSubsample = rowSubsample
            self.columnSubsample = columnSubsample
        }
    }
    public var targetColumn: String
    public var featureColumns: [String]
    public private(set) var model: MLRandomForestClassifierModel
    public private(set) var trainingMetrics: MLClassifierMetrics
    public private(set) var validationMetrics: MLClassifierMetrics?


    public init(trainingData: MLDataTable, targetColumn: String, featureColumns: [String]? = nil,
                parameters: ModelParameters = ModelParameters()) throws {
        let (training, validation) = TabularEstimatorCore.split(
            trainingData, classification: true, strategy: .automatic, seed: UInt64(bitPattern: Int64(parameters.randomSeed)))
        let set = try TabularEstimatorCoreBridge.make(training, targetColumn: targetColumn,
                                                      featureColumns: featureColumns, classification: true)
        let forest = CreateMLComponents.RandomForestFitter.fit(set, parameters: CreateMLComponents.RandomForestParameters(
            numberOfIterations: parameters.maxIterations, maximumDepth: parameters.maxDepth,
            minimumLossReduction: parameters.minLossReduction, minimumChildWeight: parameters.minChildWeight,
            rowSubsample: parameters.rowSubsample,
            maximumFeatures: .fraction(parameters.columnSubsample),
            seed: UInt64(bitPattern: Int64(parameters.randomSeed))))
        self.targetColumn = targetColumn
        self.featureColumns = set.featureNames
        self.model = MLRandomForestClassifierModel(forest, set.featureNames)
        self.trainingMetrics = MLClassifierMetrics(
            observations: set.targetLabels,
            predictions: (0..<set.design.rows).map { forest.predictLabel(set.design, index: $0) },
            labelOrder: forest.labelOrder)
        if let validation = validation,
           let validationSet = try? TabularEstimatorCoreBridge.make(validation, targetColumn: targetColumn,
                                                                    featureColumns: set.featureNames, classification: true) {
            self.validationMetrics = MLClassifierMetrics(
                observations: validationSet.targetLabels,
                predictions: (0..<validationSet.design.rows).map { forest.predictLabel(validationSet.design, index: $0) },
                labelOrder: forest.labelOrder)
        } else {
            self.validationMetrics = nil
        }
    }

    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let set = try TabularEstimatorCoreBridge.make(table, targetColumn: targetColumn,
                                                       featureColumns: featureColumns, classification: true)
        return MLUntypedColumn((0..<set.design.rows).map { index in
            MLDataValue.string(model.predictLabel(set.design, index: index))
        })
    }

    public func evaluation(on labeledData: MLDataTable) -> MLClassifierMetrics {
        guard let set = try? TabularEstimatorCoreBridge.make(labeledData, targetColumn: targetColumn,
                                                             featureColumns: featureColumns, classification: true) else {
            return MLClassifierMetrics(observations: [], predictions: [], labelOrder: [])
        }
        return MLClassifierMetrics(
            observations: set.targetLabels,
            predictions: (0..<set.design.rows).map { model.predictLabel(set.design, index: $0) },
            labelOrder: model.labelOrder)
    }

    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}

public struct MLRandomForestClassifierModel {
    public let forest: CreateMLComponents.RandomForestModel
    public let featureNames: [String]
    public var labelOrder: [String] { forest.labelOrder }

    public init(_ forest: CreateMLComponents.RandomForestModel, _ featureNames: [String]) {
        self.forest = forest
        self.featureNames = featureNames
    }

    public func predictLabel(_ design: CreateMLComponents.RowMatrix, index: Int) -> String {
        forest.predictLabel(design, index: index)
    }
}

public struct MLBoostedTreeClassifier {
    public struct ModelParameters {
        public var validationData: MLDataTable?
        public var validation: MLTrainingDataValidationData.Validation
        public var maxDepth: Int
        public var maxIterations: Int
        public var minLossReduction: Double
        public var minChildWeight: Double
        public var randomSeed: Int
        public var stepSize: Double
        public var earlyStoppingRounds: Int?
        public var rowSubsample: Double
        public var columnSubsample: Double

        public init(validation: MLTrainingDataValidationData.Validation, maxDepth: Int = 6,
                    maxIterations: Int = 10, minLossReduction: Double = 0, minChildWeight: Double = 0.1,
                    randomSeed: Int = 42, stepSize: Double = 0.3, earlyStoppingRounds: Int? = nil,
                    rowSubsample: Double = 1.0, columnSubsample: Double = 1.0) {
            self.validationData = nil
            self.validation = validation
            self.maxDepth = maxDepth
            self.maxIterations = maxIterations
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
            self.stepSize = stepSize
            self.earlyStoppingRounds = earlyStoppingRounds
            self.rowSubsample = rowSubsample
            self.columnSubsample = columnSubsample
        }

        public init(validationData: MLDataTable? = nil, maxDepth: Int = 6, maxIterations: Int = 10,
                    minLossReduction: Double = 0, minChildWeight: Double = 0.1, randomSeed: Int = 42,
                    stepSize: Double = 0.3, earlyStoppingRounds: Int? = nil,
                    rowSubsample: Double = 1.0, columnSubsample: Double = 1.0) {
            self.validationData = validationData
            self.validation = .none
            self.maxDepth = maxDepth
            self.maxIterations = maxIterations
            self.minLossReduction = minLossReduction
            self.minChildWeight = minChildWeight
            self.randomSeed = randomSeed
            self.stepSize = stepSize
            self.earlyStoppingRounds = earlyStoppingRounds
            self.rowSubsample = rowSubsample
            self.columnSubsample = columnSubsample
        }
    }
    public var targetColumn: String
    public var featureColumns: [String]
    public private(set) var model: MLBoostedTreeClassifierModel
    public private(set) var trainingMetrics: MLClassifierMetrics
    public private(set) var validationMetrics: MLClassifierMetrics?


    public init(trainingData: MLDataTable, targetColumn: String, featureColumns: [String]? = nil,
                parameters: ModelParameters = ModelParameters()) throws {
        let (training, validation) = TabularEstimatorCore.split(
            trainingData, classification: true, strategy: .automatic, seed: UInt64(bitPattern: Int64(parameters.randomSeed)))
        let set = try TabularEstimatorCoreBridge.make(training, targetColumn: targetColumn,
                                                      featureColumns: featureColumns, classification: true)
        let forest = CreateMLComponents.BoostedTreeFitter.fit(set, parameters: CreateMLComponents.BoostedTreeParameters(
            numberOfIterations: parameters.maxIterations, maximumDepth: parameters.maxDepth,
            minimumLossReduction: parameters.minLossReduction, learningRate: parameters.stepSize,
            rowSubsample: parameters.rowSubsample, columnSubsample: parameters.columnSubsample,
            loss: .logLoss, seed: UInt64(bitPattern: Int64(parameters.randomSeed))))
        self.targetColumn = targetColumn
        self.featureColumns = set.featureNames
        self.model = MLBoostedTreeClassifierModel(forest, set.featureNames)
        self.trainingMetrics = MLClassifierMetrics(
            observations: set.targetLabels,
            predictions: (0..<set.design.rows).map { forest.predictLabel(set.design, index: $0) },
            labelOrder: forest.labelOrder)
        if let validation = validation,
           let validationSet = try? TabularEstimatorCoreBridge.make(validation, targetColumn: targetColumn,
                                                                    featureColumns: set.featureNames, classification: true) {
            self.validationMetrics = MLClassifierMetrics(
                observations: validationSet.targetLabels,
                predictions: (0..<validationSet.design.rows).map { forest.predictLabel(validationSet.design, index: $0) },
                labelOrder: forest.labelOrder)
        } else {
            self.validationMetrics = nil
        }
    }

    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let set = try TabularEstimatorCoreBridge.make(table, targetColumn: targetColumn,
                                                       featureColumns: featureColumns, classification: true)
        return MLUntypedColumn((0..<set.design.rows).map { index in
            MLDataValue.string(model.predictLabel(set.design, index: index))
        })
    }

    public func evaluation(on labeledData: MLDataTable) -> MLClassifierMetrics {
        guard let set = try? TabularEstimatorCoreBridge.make(labeledData, targetColumn: targetColumn,
                                                             featureColumns: featureColumns, classification: true) else {
            return MLClassifierMetrics(observations: [], predictions: [], labelOrder: [])
        }
        return MLClassifierMetrics(
            observations: set.targetLabels,
            predictions: (0..<set.design.rows).map { model.predictLabel(set.design, index: $0) },
            labelOrder: model.labelOrder)
    }

    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}

public struct MLBoostedTreeClassifierModel {
    public let forest: CreateMLComponents.BoostedTreeModel
    public let featureNames: [String]
    public var labelOrder: [String] { forest.labelOrder }

    public init(_ forest: CreateMLComponents.BoostedTreeModel, _ featureNames: [String]) {
        self.forest = forest
        self.featureNames = featureNames
    }

    public func predictLabel(_ design: CreateMLComponents.RowMatrix, index: Int) -> String {
        forest.predictLabel(design, index: index)
    }
}

enum TabularEstimatorCoreBridge {
    static func make(_ table: MLDataTable, targetColumn: String, featureColumns: [String]?,
                     classification: Bool) throws -> TabularTrainingSet {
        guard table.column(targetColumn) != nil else {
            throw MLCreateErrorCode.invalidTargetColumnInCreate.error
        }
        return try TabularFitting.make(columnar(table), targetColumn: targetColumn,
                                       featureColumns: featureColumns, classification: classification)
    }

    static func columnar(_ table: MLDataTable) -> ColumnarTable {
        var training = ColumnarTable()
        for name in table.columnNames {
            guard let source = table.column(name) else { continue }
            switch source.type {
            case .int:
                training.set(.integers(source.values.map { $0.intValue }), named: name)
            case .double:
                training.set(.doubles(source.values.map { $0.doubleValue }), named: name)
            default:
                training.set(.strings(source.values.map { $0.stringValue }), named: name)
            }
        }
        return training
    }
}
