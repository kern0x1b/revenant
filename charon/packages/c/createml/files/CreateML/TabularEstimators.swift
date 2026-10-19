// TabularEstimators.swift — the six tabular estimators CreateML's own API names, over the training
// core in CreateMLComponents.
//
// The split between the two modules is the framework's: `CreateMLComponents` has the estimators and
// their transformers, and `CreateML` has the types an application names — `MLDecisionTreeRegressor`
// and its five siblings — which take an `MLDataTable` and give back predictions as columns. The
// arithmetic is not here; each of these is a call into `TabularFitting` and the fitter it names.
//
// What these do *not* have is the `.mlmodel` export. `write(to:)` is declared and throws the
// framework's own "not supported" error rather than writing a file no CoreML can read: the
// specification writer belongs to the CoreML package, and a table that wrote a file with the right
// extension and the wrong bytes would be worse than one that says it cannot.

import CoreML
import Foundation
import CreateMLComponents

/// How a training set is divided into the part that trains and the part that validates.
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

/// How the rows are chosen for a split.
public enum MLSplitStrategy: String, CaseIterable {
    /// The rows are split at random, the way `randomSplit(by:seed:)` does.
    case random
    /// The rows are split so that the classes keep their proportions, which is what a classifier
    /// with a rare class needs: a random split can put every copy of it on one side.
    case stratified
    /// The framework's own choice, which is stratified for a classifier and random for a regression
    /// — a numeric target has no classes to keep in proportion.
    case automatic
}

/// The validation data of a fit, and the metrics it produced.
public struct MLTrainingDataValidation {
    public var table: MLDataTable
    public var metrics: [String: Double]
}

/// The data a fit validates on, as the framework's `ModelParameters` carries it.
///
/// `.split` is a hold-out: the rows are divided and the part that validates is never trained on.
/// `.none` trains on everything, which is what a caller with a separate test table wants — and which
/// is why there are two initialisers answering the same question in two ways, one taking the data
/// table and the other the division, exactly as the framework's own do.
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

/// What a trained regressor's quality is measured as.
///
/// The two members are the ones the framework names — `maximumError` and `rootMeanSquaredError` — and
/// not the three a statistics textbook would offer. The mean absolute error is deliberately not
/// among them: it is not a member of this type, and a caller who wants it divides the two it has by
/// the count, which is why the count is not needed here.
public struct MLRegressorMetrics: CustomStringConvertible, CustomDebugStringConvertible {
    /// The largest absolute error of the fit.
    public var maximumError: Double
    /// The root mean squared error of the fit.
    public var rootMeanSquaredError: Double
    /// Set when the metrics could not be computed — an empty set of observations, or a set of
    /// predictions of a different length from the targets. A caller that reads `isValid` and not the
    /// numbers is the caller that cannot be handed a `NaN` and believe it.
    public var error: Error?

    public init(maximumError: Double, rootMeanSquaredError: Double) {
        self.maximumError = maximumError
        self.rootMeanSquaredError = rootMeanSquaredError
        self.error = nil
    }

    public var isValid: Bool { error == nil }

    /// The metrics of a set of predictions against the targets they were made for.
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

/// Why a regression's metrics could not be computed.
public enum MLRegressorMetricsError: Error, CustomStringConvertible {
    case notComparable(Int, Int)
    /// The estimator was fitted without a validation set, so it has no validation metrics.
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

/// A classifier's quality, as the framework measures it.
///
/// `classificationError` is one minus the accuracy: the framework's own definition, read from its
/// interface rather than assumed, and it is the number a caller compares against a baseline. The
/// confusion and precision/recall tables are `MLDataTable`s because that is what the framework's
/// members are typed as, and they are built here rather than left empty.
public struct MLClassifierMetrics: CustomStringConvertible, CustomDebugStringConvertible {
    /// One minus the accuracy: the share of the rows whose prediction was not the right label.
    public var classificationError: Double
    /// A table whose rows are the true labels and whose columns are the predicted ones, with the
    /// count of the rows in each cell.
    public var confusion: MLDataTable
    /// A table of the precision and the recall of each class.
    public var precisionRecall: MLDataTable
    public var error: Error?

    public init(classificationError: Double, confusion: MLDataTable, precisionRecall: MLDataTable) {
        self.classificationError = classificationError
        self.confusion = confusion
        self.precisionRecall = precisionRecall
        self.error = nil
    }

    public var isValid: Bool { error == nil }

    /// The accuracy: one minus the error, which is how the framework defines the pair against each
    /// other. Named here because a differential compares it and a caller reads it, and spelled once
    /// so the two never drift apart.
    public var accuracy: Double { 1 - classificationError }

    /// The metrics of a set of predicted labels against the labels they were made for.
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

        // The confusion table, as the framework's own is shaped: a corner cell naming the axes, a
        // row per true label and a column per predicted one.
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

        // Precision and recall per class, each as a share of the column or the row it is a share of.
        // A class the model never predicts has no precision, and one it never sees has no recall;
        // both are zero rather than a division by nothing.
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

/// Why a classifier's metrics could not be computed.
public enum MLClassifierMetricsError: Error, CustomStringConvertible {
    case notComparable(Int, Int)

    public var description: String {
        switch self {
        case .notComparable(let observations, let predictions):
            return "\(observations) labels and \(predictions) predictions are not the same length."
        }
    }
}

/// Why an estimator could not be fitted.
public enum MLCreateError: Error, CustomStringConvertible, Equatable {
    case invalidTrainingDataTable(String)
    case invalidFeatureColumns(String)
    case invalidTargetColumn(String)
    case modelCompatibility(String)
    case notSupportedOnThisDevice(String)
    case cannotWriteModel(String)
    /// A penalised fit this build does not match the framework's answer to. The framework's penalised
    /// fit is not the closed-form ridge or L1 solution, so it is refused rather than answered
    /// differently (facts/CreateML/LinearModels.md, "The penalties").
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

/// The error domain CreateML's own errors carry.
public let MLCreateErrorDomain = "MLCreateErrorDomain"

/// The six errors above, as the framework's own numbering.
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

// MARK: - The shared shape of the six

/// The parts every one of the six has: the table, the target column, the feature columns, the
/// training and validation metrics, and the three questions a caller asks it.
public enum TabularEstimatorCore {
    /// The training and validation halves of a fit, and the metrics of each.
    /// The rows a fit trains on and the rows it validates on, given the strategy.
    ///
    /// `.automatic` is stratified for a classifier and random for a regression, and the reason is in
    /// the file: a numeric target has no classes to keep in proportion, while a class that is one
    /// row in fifty can land entirely on one side of a random split.
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

// MARK: - The regressors

/// A decision-tree regressor: one tree, over the columns of an `MLDataTable`.
public struct MLDecisionTreeRegressor {
    /// What a single tree is allowed to be, in the framework's own names and defaults: a depth, a
    /// loss reduction a split has to buy, a child weight a leaf has to reach, and a seed.
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

    /// The predictions for a table of the same shape, as a column of doubles.
    public func predictions(from table: MLDataTable) throws -> MLUntypedColumn {
        let set = try Self.set(table, targetColumn: targetColumn, featureColumns: featureColumns)
        return MLUntypedColumn(model.predictAll(set.design).map { MLDataValue.double($0) })
    }

    /// The metrics of a labelled table.
    public func evaluation(on labeledData: MLDataTable) -> MLRegressorMetrics {
        guard let set = try? Self.set(labeledData, targetColumn: targetColumn, featureColumns: featureColumns) else {
            return MLRegressorMetrics(observations: [], predictions: [])
        }
        return MLRegressorMetrics(observations: set.targets, predictions: model.predictAll(set.design))
    }

    /// The model's export. **Refused, and the reason is which kind of model it is.** A forest and a
    /// booster are a `TreeEnsembleRegressor` (field 302) with a different layer set, and a
    /// classifier is a `NeuralNetworkClassifier` (field 403) with a string label output. A file that
    /// said `NeuralNetworkRegressor` and carried one of those would be a model Core ML loads and
    /// answers with the **wrong arithmetic** — so the writer is not used here. The one estimator it
    /// *is* used by is the linear model, in `CreateMLComponents.LinearModels.swift`, because a linear
    /// model *is* a single inner-product layer. See `facts/CreateML/Export.md`.
    public func write(to fileURL: URL, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        throw MLCreateErrorCode.cannotWriteModel.error
    }
}

/// A decision tree over doubles, as the six estimators hold it.
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

/// A random-forest regressor.
public struct MLRandomForestRegressor {
    /// What a forest is allowed to be: the tree's parameters plus how many of them, and the shares
    /// of the rows and the columns each one sees. The framework's default subsample of 0.8 is a
    /// sample *without* replacement, which is what the core's `rowSubsample` below one does.
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

/// A gradient-boosted-tree regressor.
public struct MLBoostedTreeRegressor {
    /// A forest's parameters plus the step size each added tree is scaled by, and the early stopping
    /// round count, which is nil for "never stop early" — the framework's own default.
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

// MARK: - The classifiers

/// A decision-tree classifier.
public struct MLDecisionTreeClassifier {
    /// What a single tree is allowed to be, in the framework's own names and defaults: a depth, a
    /// loss reduction a split has to buy, a child weight a leaf has to reach, and a seed.
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

/// A random-forest classifier.
public struct MLRandomForestClassifier {
    /// What a forest is allowed to be: the tree's parameters plus how many of them, and the shares
    /// of the rows and the columns each one sees. The framework's default subsample of 0.8 is a
    /// sample *without* replacement, which is what the core's `rowSubsample` below one does.
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

/// A gradient-boosted-tree classifier.
public struct MLBoostedTreeClassifier {
    /// A forest's parameters plus the step size each added tree is scaled by, and the early stopping
    /// round count, which is nil for "never stop early" — the framework's own default.
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

/// The bridge from an `MLDataTable` to the training core: one function, called by all six.
enum TabularEstimatorCoreBridge {
    static func make(_ table: MLDataTable, targetColumn: String, featureColumns: [String]?,
                     classification: Bool) throws -> TabularTrainingSet {
        guard table.column(targetColumn) != nil else {
            throw MLCreateErrorCode.invalidTargetColumnInCreate.error
        }
        return try TabularFitting.make(columnar(table), targetColumn: targetColumn,
                                       featureColumns: featureColumns, classification: classification)
    }

    /// The table's columns as the training core reads them: a column of doubles, of integers or of
    /// strings, with a missing value for a cell that has none. There is no second representation of a
    /// table between here and there. Predictions use it too, for a table with no target column.
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
