// LinearModels.swift — the linear regressor and the logistic classifier, over the shaped array.
//
// Both are the *ridge* fit of `LinearAlgebra.swift`, and the reason is the parameter the framework
// hands them. `LinearRegressor.Configuration` carries `l2Penalty` and `l1Penalty` and **both are
// fitted**: the L2 one by the closed-form solve of `LinearAlgebra.swift`, the L1 one by the proximal
// iteration in `Proximal.swift`, and both at once by the L1 route with its quadratic term.
// `l1Penalty > 0` selects the route and nothing else.
//
// The first version **refused** an L1 penalty on the reasoning that a fit which quietly dropped it
// would hand back a confident number about a model nobody asked for. The reasoning was right and the
// refusal was the wrong answer to it — the penalty is solvable, and refusing a thing that can be
// computed is the same failure wearing a hat. The iteration is in `Proximal.swift` and the KKT
// residual is its convergence test; a run that cannot reach the tolerance says so
// (`LinearModelError.l1PenaltyDidNotConverge`) rather than answering the point it reached.
//
// The design matrix is a `MLShapedArray<Scalar>` and so is the model's answer, so a prediction is a
// dot product over the buffer the fit produced and nothing is copied on the way out. The strides are
// `[1]` for a single feature, and the weight vector is a shaped array of one dimension with the
// same strides, which is what makes `coefficients` a row-major walk of it.
//
// The arithmetic is the device's own: a Gram matrix by `cblas_dsyrk`, a Cholesky factor by
// `dpotrf_`, and the two triangular substitutions in `triangularSolve`. This file adds no matrix
// code; it chooses what to ask that arithmetic for.

import CoreML
import Foundation

/// A scalar the linear models can be written in: a floating-point value a shaped array can hold.
public protocol LinearScalar: MLShapedArrayScalar, BinaryFloatingPoint {}

extension Float: LinearScalar {}
extension Double: LinearScalar {}

// The annotated types are `Equatable` where their parts are, and are declared conditional rather
// than unconditionally: a `feature` that is not `Equatable` makes a pair of them not either, and
// saying so once is better than a conformance that is a lie for half the instantiations.
extension AnnotatedFeature: Equatable where Feature: Equatable, Annotation: Equatable {}
extension AnnotatedPrediction: Equatable where Feature: Equatable, Annotation: Equatable {}

// `Sendable` is deliberately NOT declared on any of these. The SDK's own interface marks it
// *unavailable* on every one of them (`@available(*, unavailable) extension ... : Swift.Sendable`),
// so declaring it here would be a conformance the framework refuses, and omitting it is the
// faithful answer. `Equatable` on a distribution needs nothing extra: `[Label: Double]` is
// `Equatable` wherever `Label` is `Hashable`, which is the constraint it is declared with.

/// A classifier: something that takes a feature vector and answers a label with its distribution.
public protocol Classifier {
    associatedtype Input
    associatedtype Label: Hashable
    associatedtype Output

    /// The distribution for one input.
    func prediction(from input: Input) throws -> Output

    /// The distributions for a sequence of inputs, in the order given.
    func prediction<InputSequence: Sequence>(from inputs: InputSequence) throws -> [Output]
        where InputSequence.Element == Input
}

/// A feature vector and the target that goes with it: the form a supervised estimator is handed,
/// and a named type rather than a tuple so that the two `fitted(to:)` overloads — one over feature
/// vectors and one over these — are told apart by their argument instead of by their arity.
public struct AnnotatedFeature<Feature, Annotation> {
    public var feature: Feature
    public var annotation: Annotation

    public init(feature: Feature, annotation: Annotation) {
        self.feature = feature
        self.annotation = annotation
    }
}

/// A prediction and the target it was made against, which is what an evaluation reads.
public struct AnnotatedPrediction<Feature, Annotation> {
    public var prediction: Feature
    public var annotation: Annotation

    public init(prediction: Feature, annotation: Annotation) {
        self.prediction = prediction
        self.annotation = annotation
    }
}

/// A regressor: something that takes a feature vector and answers a number.
public protocol Regressor {
    associatedtype Input
    associatedtype Output: BinaryFloatingPoint

    /// The prediction for one input.
    func prediction(from input: Input) throws -> Output

    /// The predictions for a sequence of inputs, in the order given.
    func prediction<InputSequence: Sequence>(from inputs: InputSequence) throws -> [Output]
        where InputSequence.Element == Input
}

/// A fitted linear regressor: the coefficients of `y = b0 + b1*x1 + ... + bn*xn`.
public struct LinearRegressorModel<Scalar: LinearScalar>: Regressor {
    public typealias Input = MLShapedArray<Scalar>
    public typealias Output = Scalar

    /// How many features the model was fitted on. A prediction of a different width is a
    /// `shapeMismatch` and not a number: a dot product of two vectors of different lengths is either
    /// a truncation or an out-of-bounds read, and a caller who gets a number back has been told a
    /// prediction about a model that is not the one they hold.
    public var featureCount: Int { weights.count - 1 }

    /// The coefficients, the **intercept first** and then the weights, which is the order the
    /// framework's `init(coefficients:)` takes them in and the order a caller reads them in.
    public var coefficients: [Scalar] { weights }

    private let weights: [Scalar]

    /// A model from its coefficients, intercept first. An empty or one-element sequence is refused:
    /// a regressor with no intercept and no features has nothing to answer with, and a one-element
    /// sequence is an intercept and no features, which is a constant predictor and not a fit.
    public init<C: Sequence>(coefficients: C) where C.Element == Scalar {
        let values = Array(coefficients)
        precondition(values.count > 1,
                     "a linear regressor needs an intercept and at least one coefficient, and this has "
                     + String(values.count) + " value(s)")
        self.weights = values
    }

    /// The model as a Core ML `.mlmodel`, written where the caller says.
    ///
    /// A linear model **is** a one-input, one-output neural network with a single inner-product layer,
    /// because that layer computes `bias + weights \u{00b7} x` and Core ML executes it, so this writes
    /// a model Core ML loads rather than a file with the right extension. The coefficients are
    /// re-expressed in the order that layer expects \u{2014} feature 0 first \u{2014} with the intercept
    /// moved out of the front of the array into the layer's bias, because the wire format stores them
    /// in separate fields and the layout is the one thing that would silently be transposed.
    ///
    /// **Core ML's compiler does not accept the result yet**: it throws `std::out_of_range` out of its
    /// own `unordered_map::at`, identically for a model coremltools 9.0 wrote with its own protobuf
    /// classes, so this is a gap in the model *shape* and not in this writer. `facts/CreateML/Export.md`
    /// has the sixteen-variant table. Writing the file is still the right behaviour over refusing:
    /// the bytes are verified by two readers that are neither this port's nor Swift's Core ML.
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

    /// The same model under a path rather than a URL, which is the spelling the framework's own
    /// `write(toFile:)` takes, so a caller that already has a string does not build a URL by hand.
    public func write(toFile path: String, metadata: MLModelMetadata? = nil) throws {
        try write(to: URL(fileURLWithPath: path), metadata: metadata)
    }

    init(weights: [Scalar]) {
        precondition(weights.count > 1,
                     "a linear regressor needs an intercept and at least one coefficient")
        self.weights = weights
    }

    /// The prediction for one feature vector: the intercept and the dot product of the features and
    /// the weights.
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

/// Why a linear model could not answer.
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

/// How a linear regressor is fitted.
public struct LinearRegressorConfiguration: Hashable, Codable {
    /// The ridge penalty. This is the one that is fitted: the normal equations with this on the
    /// diagonal, factored and solved through the system's own LAPACK.
    public var l2Penalty: Double
    /// The L1 penalty. **Not carried.** Setting it is refused rather than ignored — see
    /// `LinearModelError.l1PenaltyNotImplemented` and the file's header.
    public var l1Penalty: Double
    public var maximumIterations: Int
    public var stepSize: Double
    public var convergenceThreshold: Double
    public var earlyStopIterationCount: Int
    public var scaleFeatures: Bool
    /// Whether the features are centred and scaled before the fit and the answer is put back the way
    /// it was. It is on by default in the framework and it is why the coefficients of a fit over
    /// columns of very different magnitudes are comparable at all.
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

/// A regressor fitted by least squares with a ridge penalty.
public struct LinearRegressor<Scalar: LinearScalar> {
    public typealias Transformer = LinearRegressorModel<Scalar>
    public typealias Annotation = Scalar

    public var configuration: LinearRegressorConfiguration

    public init(configuration: LinearRegressorConfiguration = LinearRegressorConfiguration()) {
        self.configuration = configuration
    }

    /// The fit, over a sequence of feature vectors and their targets.
    ///
    /// The features are the rows of a design matrix with an intercept column in front, which is the
    /// form the answer is in: `coefficients[0]` is the intercept and the rest are the weights. The
    /// matrix is assembled with the intercept as a *column of ones* rather than by shifting the
    /// targets, so the one code path fits a model with an intercept and a model without, and the
    /// second is the first with a column of zeros.
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

    /// The fit, over annotated rows: a feature vector and the target that goes with it.
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
        // The targets: given beside the rows, or read out of the last element of each row, which is
        // the form the framework's annotated input takes.
        // The targets come beside the rows when the caller gave them, and there is no second
        // reading: a feature vector that carried its own target would be a row whose width is one
        // more than the model's, and a model fitted on it would answer for a feature the caller never
        // named. The un-annotated form is for a caller who has already put the targets where it
        // wants them.
        guard let targets = targets else {
            throw LinearModelError.shapeMismatch(expected: rows.count, found: 0)
        }
        guard targets.count == rows.count else {
            throw LinearModelError.shapeMismatch(expected: rows.count, found: targets.count)
        }
        let observations = targets.map { Double($0) }
        let design = designMatrix(rows, width: width)
        // The L1 penalty changes what kind of problem this is, and the route with it: a closed-form
        // solve for the L2 case, a proximal iteration for the L1 one. `l1Penalty > 0` selects it, and
        // both penalties may be on at once, in which case the proximal step's `l2Penalty` term is what
        // adds the quadratic part. The iteration is judged by the KKT residual, which is the only
        // right test for a proximal method on a non-smooth objective, and a run that cannot reach it
        // says so rather than answering the point it reached.
        if configuration.l1Penalty > 0 {
            // **The penalty is scaled, and the scale is the framework's.** Measured against the host's
            // own `MLLinearRegressor` over a grid of penalties on the same rows, recovering the host's
            // coefficients from its own predictions by a least-squares solve on a full-rank design:
            // the best factor on `l1Penalty` is **0.5 per sample** at every non-zero penalty, i.e. the
            // term is `l1Penalty / (2n) |w|_1` — half the mean absolute deviation, which is the same
            // `1/2` that is already on the squared term. `l1Penalty` and `l2Penalty` are therefore
            // scaled alike, and a caller who sets both has set them in the units the framework means.
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

    /// The design matrix: a row per observation, an intercept column of ones, and the features.
    private func designMatrix(_ rows: [MLShapedArray<Scalar>], width: Int) -> RowMatrix {
        var design = RowMatrix(rows: rows.count, columns: width + 1)
        for (index, row) in rows.enumerated() {
            design[index, 0] = 1
            for feature in 0..<width {
                // The target, when the row carries one, is the last element and is not a feature; a
                // row given without one is short by its last element and the read below is
                // short with it, which the width check above has already refused.
                design[index, feature + 1] = Double(row.scalars[feature])
            }
        }
        return design
    }
}

/// A classifier's answer: a label and the model's confidence in it.
public struct ClassificationDistribution<Label: Hashable> {
    public var label: Label
    public var probabilities: [Label: Double]

    public init(label: Label, probabilities: [Label: Double] = [:]) {
        self.label = label
        self.probabilities = probabilities
    }

    /// The model's confidence in the answer it gave.
    public var double: Double { probabilities[label] ?? 0 }
}

/// A fitted logistic classifier.
public struct LogisticRegressionClassifierModel<Scalar: LinearScalar, Label: Hashable>: Classifier {
    public typealias Output = ClassificationDistribution<Label>
    public typealias Input = MLShapedArray<Scalar>

    /// How many features the model was fitted on, which is the weights' count *less one per class*
    /// — not one in total. A two-class model over one feature has three coefficients, and calling
    /// that two features is how a prediction of a one-feature row comes to be refused.
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

    /// The class distribution for one feature vector: the per-class scores turned into
    /// probabilities by the logistic link, with the highest as the answer.
    public func prediction(from input: MLShapedArray<Scalar>) throws -> ClassificationDistribution<Label> {
        let features = input.scalars
        guard features.count == featureCount else {
            throw LinearModelError.shapeMismatch(expected: featureCount, found: features.count)
        }
        var scores = [Double](repeating: 0, count: labels.count)
        for position in 0..<labels.count {
            // The weights are laid out class-major over features: the intercept of each class
            // first, then class 0's weight for every feature, then class 1's, and so on. That is
            // the layout `coefficients` has and the one a caller reads, so the walk below is the
            // same order the coefficients are in.
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

/// How a logistic classifier is fitted.
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

/// A binary or multiclass classifier fitted by logistic regression.
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

        // One fit per class, one-against-the-rest, which is the same shape the boosted classifier
        // uses and the reason the two agree on a table: a class's score is a ridge fit of "is this
        // row that class" and the probabilities come from the logistic link over the scores.
        var coefficients = [Double](repeating: 0, count: 1 + width * labels.count)
        for (position, label) in labels.enumerated() {
            let targets = rows.map { $0.annotation == label ? 1.0 : 0.0 }
            // The design carries an intercept column of ones in front, exactly as the regressor's
            // does, and for the same reason: the model's `coefficients` is the intercept and then
            // one weight per class per feature, so a design without the column would answer a
            // solution one entry shorter and every weight read past its end.
            var design = RowMatrix(rows: rows.count, columns: width + 1)
            for (index, row) in rows.enumerated() {
                design[index, 0] = 1
                for feature in 0..<width {
                    design[index, feature + 1] = Double(row.feature.scalars[feature])
                }
            }
            // The same route as the regression's, per class: a closed form without an L1 term, a
            // proximal iteration with one. One class against the rest, so the labels' scores stay
            // independent and the distribution comes from the logistic link over them, as
            // `prediction(from:)` already says.
            let (solution, info): ([Double], Int)
            if configuration.l1Penalty > 0 {
                // The same measured scale as the regression's: half the mean, for both penalties.
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
                // The solution is the design's own width, so this cannot happen; the check is here
                // because a design and a read of its solution that disagree are the failure below,
                // and this is where they disagree.
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
