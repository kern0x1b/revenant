import CoreML
import Foundation

public protocol LinearScalar: MLShapedArrayScalar, BinaryFloatingPoint {}

extension Float: LinearScalar {}
extension Double: LinearScalar {}

extension AnnotatedFeature: Equatable where Feature: Equatable, Annotation: Equatable {}
extension AnnotatedPrediction: Equatable where Feature: Equatable, Annotation: Equatable {}

public protocol Classifier {
    associatedtype Input
    associatedtype Label: Hashable
    associatedtype Output

    func prediction(from input: Input) throws -> Output

    func prediction<InputSequence: Sequence>(from inputs: InputSequence) throws -> [Output]
        where InputSequence.Element == Input
}

public struct AnnotatedFeature<Feature, Annotation> {
    public var feature: Feature
    public var annotation: Annotation

    public init(feature: Feature, annotation: Annotation) {
        self.feature = feature
        self.annotation = annotation
    }
}

public struct AnnotatedPrediction<Feature, Annotation> {
    public var prediction: Feature
    public var annotation: Annotation

    public init(prediction: Feature, annotation: Annotation) {
        self.prediction = prediction
        self.annotation = annotation
    }
}

public protocol Regressor {
    associatedtype Input
    associatedtype Output: BinaryFloatingPoint

    func prediction(from input: Input) throws -> Output

    func prediction<InputSequence: Sequence>(from inputs: InputSequence) throws -> [Output]
        where InputSequence.Element == Input
}

public struct LinearRegressorModel<Scalar: LinearScalar>: Regressor {
    public typealias Input = MLShapedArray<Scalar>
    public typealias Output = Scalar

    public var featureCount: Int { weights.count - 1 }

    public var coefficients: [Scalar] { weights }

    private let weights: [Scalar]

    public init<C: Sequence>(coefficients: C) where C.Element == Scalar {
        let values = Array(coefficients)
        precondition(values.count > 1,
                     "a linear regressor needs an intercept and at least one coefficient, and this has "
                     + String(values.count) + " value(s)")
        self.weights = values
    }

    public func write(to fileURL: URL,
                      metadata: MLModelMetadata? = nil) throws {
        let writer = ModelWriter.model(
            featureName: "x",
            outputName: "prediction",
            weights: weights.dropFirst().map { Float($0) },
            bias: Float(weights[0]),
            author: metadata?.author ?? "charon CreateML",
            version: metadata?.version ?? "1.0",
            description: metadata?.shortDescription
                ?? "a linear model fitted by charmon CreateML")
        try Data(writer.bytes).write(to: fileURL)
    }

    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        try write(to: URL(fileURLWithPath: path), metadata: metadata)
    }

    init(weights: [Scalar]) {
        precondition(weights.count > 1,
                     "a linear regressor needs an intercept and at least one coefficient")
        self.weights = weights
    }

    public func applied(to input: MLShapedArray<Scalar>) throws -> Scalar {
        try prediction(from: input)
    }

    public func prediction(from input: MLShapedArray<Scalar>) throws -> Scalar {
        let features = input.scalars
        guard features.count == featureCount else {
            throw LinearModelError.shapeMismatch(expected: featureCount, found: features.count)
        }
        var total = weights[0]
        for (index, value) in features.enumerated() {
            total += value * weights[index + 1]
        }
        return total
    }

    public func prediction<InputSequence: Sequence>(from inputs: InputSequence) throws -> [Scalar]
        where InputSequence.Element == Input {
        var out = [Scalar]()
        for input in inputs { out.append(try prediction(from: input)) }
        return out
    }
}

public enum LinearModelError: Error, CustomStringConvertible, Equatable {
    case shapeMismatch(expected: Int, found: Int)
    case notEnoughRows(Int)
    case singular(Int)
    case l1PenaltyDidNotConverge(Int)

    public var description: String {
        switch self {
        case .shapeMismatch(let expected, let found):
            return "The model was fitted on " + String(expected) + " feature(s) and was given "
                + String(found) + "."
        case .notEnoughRows(let count):
            return String(count) + " rows is too few to fit a line through."
        case .singular(let column):
            return "The design matrix has no answer in column " + String(column)
                + ": two features are the same, or one is a multiple of another."
        case .l1PenaltyDidNotConverge(let iterations):
            return "The L1 fit ran its " + String(iterations) + " iteration(s) and did not reach a "
                + "minimum - the KKT residual of the point it stopped at is above the tolerance - so "
                + "the coefficients are the point the run reached and not the L1 solution. Raise "
                + "maximumIterations or convergenceThreshold."
        }
    }
}

public struct LinearRegressorConfiguration: Hashable, Codable {
    public var l2Penalty: Double
    public var l1Penalty: Double
    public var maximumIterations: Int
    public var stepSize: Double
    public var convergenceThreshold: Double
    public var earlyStopIterationCount: Int
    public var scaleFeatures: Bool
    public var optimizationStrategy: OptimizationStrategy

    public enum OptimizationStrategy: String, Hashable, Codable {
        case normal
        case conjugateGradient
        case batchGradientDescent
        case lbfgs
    }

    public init(l2Penalty: Double = 0, l1Penalty: Double = 0, maximumIterations: Int = 100,
                stepSize: Double = 0.01, convergenceThreshold: Double = 0.01,
                earlyStopIterationCount: Int = 50, scaleFeatures: Bool = true,
                optimizationStrategy: OptimizationStrategy = .normal) {
        self.l2Penalty = l2Penalty
        self.l1Penalty = l1Penalty
        self.maximumIterations = maximumIterations
        self.stepSize = stepSize
        self.convergenceThreshold = convergenceThreshold
        self.earlyStopIterationCount = earlyStopIterationCount
        self.scaleFeatures = scaleFeatures
        self.optimizationStrategy = optimizationStrategy
    }
}

public struct LinearRegressor<Scalar: LinearScalar> {
    public typealias Transformer = LinearRegressorModel<Scalar>
    public typealias Annotation = Scalar

    public var configuration: LinearRegressorConfiguration

    public init(configuration: LinearRegressorConfiguration = LinearRegressorConfiguration()) {
        self.configuration = configuration
    }

    public func fitted<Input: Sequence, Validation: Sequence>(
        to input: Input, validateOn validation: Validation
    ) throws -> LinearRegressorModel<Scalar> where Validation.Element == Input.Element,
                                              Input.Element == MLShapedArray<Scalar> {
        let (solution, _) = try fit(rows: Array(input), targets: nil, validation: Array(validation))
        return LinearRegressorModel<Scalar>(weights: solution)
    }

    public func fitted<Input: Sequence>(to input: Input) throws -> LinearRegressorModel<Scalar>
        where Input.Element == MLShapedArray<Scalar> {
        let (solution, _) = try fit(rows: Array(input), targets: nil, validation: nil)
        return LinearRegressorModel<Scalar>(weights: solution)
    }

    public func fitted<Input: Sequence>(to input: Input) throws -> LinearRegressorModel<Scalar>
        where Input.Element == AnnotatedFeature<MLShapedArray<Scalar>, Scalar> {
        let rows = Array(input)
        let (solution, _) = try fit(rows: rows.map(\.feature), targets: rows.map(\.annotation),
                                    validation: nil)
        return LinearRegressorModel<Scalar>(weights: solution)
    }

    private func fit(rows: [MLShapedArray<Scalar>], targets: [Scalar]?,
                     validation: [MLShapedArray<Scalar>]?) throws -> ([Scalar], Int) {
        let width = rows.first?.scalars.count ?? 0
        guard width > 0 else { throw LinearModelError.shapeMismatch(expected: 1, found: 0) }
        guard rows.count > width else { throw LinearModelError.notEnoughRows(rows.count) }
        for row in rows where row.scalars.count != width {
            throw LinearModelError.shapeMismatch(expected: width, found: row.scalars.count)
        }
        guard let targets = targets else {
            throw LinearModelError.shapeMismatch(expected: rows.count, found: 0)
        }
        guard targets.count == rows.count else {
            throw LinearModelError.shapeMismatch(expected: rows.count, found: targets.count)
        }
        let observations = targets.map { Double($0) }
        let design = designMatrix(rows, width: width)
        if configuration.l1Penalty > 0 {
            let l1 = configuration.l1Penalty / (2.0 * Double(observations.count))
            let l2 = configuration.l2Penalty / (2.0 * Double(observations.count))
            let (weights, _, converged) = ProximalSolver.ridgeL1(
                design: design, targets: observations,
                l1Penalty: l1, l2Penalty: l2,
                iterations: configuration.maximumIterations,
                step: configuration.stepSize > 0 ? configuration.stepSize : nil,
                tolerance: configuration.convergenceThreshold > 0 ? configuration.convergenceThreshold : 1e-10)
            if !converged {
                throw LinearModelError.l1PenaltyDidNotConverge(configuration.maximumIterations)
            }
            return (weights.map { Scalar($0) }, 0)
        }
        let (solution, info) = RowMatrix.ridgeLeastSquares(
            design: design, targets: observations,
            penalty: configuration.l2Penalty / (2.0 * Double(observations.count)))
        if info != 0 { throw LinearModelError.singular(width) }
        return (solution.map { Scalar($0) }, info)
    }

    private func designMatrix(_ rows: [MLShapedArray<Scalar>], width: Int) -> RowMatrix {
        var design = RowMatrix(rows: rows.count, columns: width + 1)
        for (index, row) in rows.enumerated() {
            design[index, 0] = 1
            for feature in 0..<width {
                design[index, feature + 1] = Double(row.scalars[feature])
            }
        }
        return design
    }
}

public struct ClassificationDistribution<Label: Hashable> {
    public var label: Label
    public var probabilities: [Label: Double]

    public init(label: Label, probabilities: [Label: Double] = [:]) {
        self.label = label
        self.probabilities = probabilities
    }

    public var double: Double { probabilities[label] ?? 0 }
}

public struct LogisticRegressionClassifierModel<Scalar: LinearScalar, Label: Hashable>: Classifier {
    public typealias Output = ClassificationDistribution<Label>
    public typealias Input = MLShapedArray<Scalar>

    public var featureCount: Int {
        guard !labels.isEmpty else { return 0 }
        return (weights.count - 1) / labels.count
    }

    public var coefficients: [Scalar] { weights }

    private let weights: [Scalar]
    private let labels: [Label]

    public init(coefficients: some Sequence<Scalar>, labels: some Sequence<Label>) {
        let values = Array(coefficients)
        let names = Array(labels)
        precondition(values.count > 1, "a logistic classifier needs an intercept and at least one coefficient")
        precondition(!names.isEmpty, "a logistic classifier needs at least one class")
        precondition((values.count - 1) % names.count == 0,
                     "a logistic classifier has an intercept per class and one weight per class per "
                     + "feature, and " + String(values.count) + " coefficients do not divide into "
                     + String(names.count) + " classes")
        self.weights = values
        self.labels = names
    }

    public func prediction(from input: MLShapedArray<Scalar>) throws -> ClassificationDistribution<Label> {
        let features = input.scalars
        guard features.count == featureCount else {
            throw LinearModelError.shapeMismatch(expected: featureCount, found: features.count)
        }
        var scores = [Double](repeating: 0, count: labels.count)
        for position in 0..<labels.count {
            var score = Double(weights[position])
            for (index, value) in features.enumerated() {
                score += Double(value) * Double(weights[1 + position + index * labels.count])
            }
            scores[position] = score
        }
        let probabilities = RowMatrix.logistic(scores)
        var best = 0
        for index in 1..<labels.count where probabilities[index] > probabilities[best] {
            best = index
        }
        var named = [Label: Double]()
        for (position, label) in labels.enumerated() { named[label] = probabilities[position] }
        return ClassificationDistribution(label: labels[best], probabilities: named)
    }

    public func prediction<InputSequence: Sequence>(from inputs: InputSequence) throws -> [Output]
        where InputSequence.Element == Input {
        var out = [Output]()
        for input in inputs { out.append(try prediction(from: input)) }
        return out
    }
}

public struct LogisticRegressionClassifierConfiguration: Hashable, Codable {
    public var l2Penalty: Double
    public var l1Penalty: Double
    public var maximumIterations: Int
    public var stepSize: Double
    public var convergenceThreshold: Double

    public init(l2Penalty: Double = 0, l1Penalty: Double = 0, maximumIterations: Int = 100,
                stepSize: Double = 0.01, convergenceThreshold: Double = 0.01) {
        self.l2Penalty = l2Penalty
        self.l1Penalty = l1Penalty
        self.maximumIterations = maximumIterations
        self.stepSize = stepSize
        self.convergenceThreshold = convergenceThreshold
    }
}

public struct LogisticRegressionClassifier<Scalar: LinearScalar, Label: Hashable> {
    public typealias Transformer = LogisticRegressionClassifierModel<Scalar, Label>
    public typealias Annotation = Label

    public var configuration: LogisticRegressionClassifierConfiguration

    public init(configuration: LogisticRegressionClassifierConfiguration = LogisticRegressionClassifierConfiguration()) {
        self.configuration = configuration
    }

    public func fitted<Input: Sequence>(to input: Input) throws -> LogisticRegressionClassifierModel<Scalar, Label>
        where Input.Element == AnnotatedFeature<MLShapedArray<Scalar>, Label> {
        let rows = Array(input)
        guard let width = rows.first?.feature.scalars.count, width > 0 else {
            throw LinearModelError.shapeMismatch(expected: 1, found: 0)
        }
        guard rows.count > width else { throw LinearModelError.notEnoughRows(rows.count) }
        for row in rows where row.feature.scalars.count != width {
            throw LinearModelError.shapeMismatch(expected: width, found: row.feature.scalars.count)
        }
        let labels = Array(Set(rows.map(\.annotation))).sorted { String(describing: $0) < String(describing: $1) }
        guard labels.count > 1 else { throw LinearModelError.shapeMismatch(expected: 2, found: 1) }

        var coefficients = [Double](repeating: 0, count: 1 + width * labels.count)
        for (position, label) in labels.enumerated() {
            let targets = rows.map { $0.annotation == label ? 1.0 : 0.0 }
            var design = RowMatrix(rows: rows.count, columns: width + 1)
            for (index, row) in rows.enumerated() {
                design[index, 0] = 1
                for feature in 0..<width {
                    design[index, feature + 1] = Double(row.feature.scalars[feature])
                }
            }
            let (solution, info): ([Double], Int)
            if configuration.l1Penalty > 0 {
                let samples = Double(targets.count)
                let (weights, _, converged) = ProximalSolver.logisticL1(
                    design: design, targets: targets,
                    l1Penalty: configuration.l1Penalty / (2.0 * samples),
                    l2Penalty: configuration.l2Penalty / (2.0 * samples),
                    iterations: configuration.maximumIterations,
                    step: configuration.stepSize > 0 ? configuration.stepSize : nil,
                    tolerance: configuration.convergenceThreshold > 0
                        ? configuration.convergenceThreshold : 1e-10)
                if !converged {
                    throw LinearModelError.l1PenaltyDidNotConverge(configuration.maximumIterations)
                }
                solution = weights
                info = 0
            } else {
                let solved = RowMatrix.ridgeLeastSquares(design: design, targets: targets,
                                                        penalty: configuration.l2Penalty)
                solution = solved.0
                info = solved.1
            }
            if info != 0 { throw LinearModelError.singular(position) }
            guard solution.count == width + 1 else {
                throw LinearModelError.shapeMismatch(expected: width + 1, found: solution.count)
            }
            coefficients[position] = solution[0]
            for feature in 0..<width {
                coefficients[1 + position + feature * labels.count] = solution[feature + 1]
            }
        }
        return LogisticRegressionClassifierModel<Scalar, Label>(coefficients: coefficients.map { Scalar($0) },
                                                               labels: labels)
    }
}
