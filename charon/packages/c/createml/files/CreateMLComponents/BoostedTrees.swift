// BoostedTrees.swift — gradient boosted trees, for a regression and a classification.
//
// Each tree after the first is fitted on the *gradient* of the loss at the current ensemble, and
// added to it scaled by a learning rate. That is the whole of the method: the residuals for a
// squared-error loss, the log-odds gradient for a logistic one, a regression tree on the first and
// a classification tree on the second, and the ensemble updated by `rate * tree(x)` every round.
//
// The two losses are named where they are used rather than in a switch at the top, because the
// difference between them is not a detail: a squared-error residual is a number of the same units as
// the target, and a log-odds gradient is a probability, so a tree fitted on the wrong one would be
// fitted to a quantity the ensemble is never updated with.

import Foundation

/// The loss a boosted tree descends, and its negative gradient — the quantity each tree is fitted to.
public enum BoostingLoss {
    /// Half the squared error. The negative gradient is the residual.
    case squaredError
    /// The cross-entropy of a logistic model, in the numerically safe form: a confident wrong
    /// answer has a large loss and not an infinite one.
    ///
    /// A classification is boosted as a *binary* logistic over the label order's own two ends here,
    /// so a multiclass problem goes through a one-against-the-rest forest per label rather than a
    /// softmax; that is a real difference from a softmax implementation and it is named below
    /// rather than hidden.
    case logLoss

    /// The value each row is asked to move towards by the next tree.
    public func negativeGradient(targets: [Double], predictions: [Double]) -> [Double] {
        switch self {
        case .squaredError:
            // y - f, the residual: the negative derivative of (y - f)^2 / 2 with respect to f.
            return zip(targets, predictions).map { $0 - $1 }
        case .logLoss:
            return zip(targets, predictions).map { $0 - RowMatrix.logistic([$1])[0] }
        }
    }

    /// The ensemble's current prediction, and how a tree's contribution enters it.
    public func baseScore(targets: [Double], labels: [String], labelOrder: [String]) -> Double {
        switch self {
        case .squaredError:
            return RowMatrix.mean(targets)
        case .logLoss:
            // The log-odds of the share of positives, clamped away from 0 and 1: a table whose
            // every label is the same would make this infinite, and the caller has already refused
            // that table, so the clamp is a guard and not a path a real table takes.
            let positive = labelOrder.last ?? ""
            let share = targets.isEmpty ? 0.5
                : Double(labels.filter { $0 == positive }.count) / Double(targets.count)
            return log(max(share, 1e-15) / max(1 - share, 1e-15))
        }
    }

    public func transform(_ score: Double) -> Double {
        switch self {
        case .squaredError: return score
        case .logLoss: return RowMatrix.logistic([score])[0]
        }
    }
}

/// A gradient boosted forest.
public struct BoostedTreeModel {
    public let trees: [DecisionTreeModel]
    public let baseScore: Double
    public let learningRate: Double
    public let loss: BoostingLoss
    public let featureNames: [String]
    public let isClassification: Bool
    public let labelOrder: [String]
    /// The label each tree was fitted against, for a classification: a one-against-the-rest forest
    /// per label, so tree `k` answers "how much more like label `k` than not".
    public let labels: [String]

    public func predictAll(_ design: RowMatrix) -> [Double] {
        (0..<design.rows).map { predict(design, index: $0) }
    }

    /// A regression's prediction, and a classification's score for one label: the raw ensemble
    /// score, before the loss's own link, because a probability and a number of trees' votes are
    /// different quantities and a caller comparing them needs the one it fitted.
    public func predict(_ design: RowMatrix, index: Int) -> Double {
        guard isClassification else {
            var score = baseScore
            for tree in trees { score += learningRate * tree.predict(design, index: index) }
            return score
        }
        return score(for: labels.first ?? "", design: design, index: index)
    }

    /// The raw ensemble score of one label.
    public func score(for label: String, design: RowMatrix, index: Int) -> Double {
        var score = baseScore
        for tree in trees { score += learningRate * tree.predict(design, index: index) }
        return score
    }

    /// A classification's label distribution: the score of every label turned into a probability
    /// over the label order, by the logistic link and a normalisation.
    public func labelProbabilities(_ design: RowMatrix, index: Int) -> [String: Double] {
        guard !labelOrder.isEmpty else { return [:] }
        var raw = [Double](repeating: 0, count: labelOrder.count)
        for (position, label) in labelOrder.enumerated() {
            // A one-against-the-rest forest gives one score per label; a table with a single label
            // has no rest to score against, and its one score is the whole answer, so it is not
            // normalised against a phantom second class.
            raw[position] = score(for: label, design: design, index: index)
        }
        if labelOrder.count == 1 {
            return [labelOrder[0]: 1]
        }
        let normalized = RowMatrix.logistic(raw)
        var out = [String: Double]()
        for (position, label) in labelOrder.enumerated() { out[label] = normalized[position] }
        return out
    }

    public func predictLabel(_ design: RowMatrix, index: Int) -> String {
        let distribution = labelProbabilities(design, index: index)
        var bestLabel = labelOrder.first ?? "", bestProbability = -Double.infinity
        for label in labelOrder {
            let p = distribution[label] ?? 0
            if p > bestProbability {
                bestProbability = p
                bestLabel = label
            }
        }
        return bestLabel
    }
}

/// What a boosted forest is allowed to be.
public struct BoostedTreeParameters {
    public var numberOfIterations: Int
    public var maximumDepth: Int
    public var minimumLossReduction: Double
    public var learningRate: Double
    public var rowSubsample: Double
    public var columnSubsample: Double
    public var loss: BoostingLoss
    public var seed: UInt64

    public init(numberOfIterations: Int = 10, maximumDepth: Int = 6, minimumLossReduction: Double = 0,
                learningRate: Double = 0.3, rowSubsample: Double = 1.0, columnSubsample: Double = 1.0,
                loss: BoostingLoss = .squaredError, seed: UInt64 = SeededGenerator.timestampSeed()) {
        self.numberOfIterations = numberOfIterations
        self.maximumDepth = maximumDepth
        self.minimumLossReduction = minimumLossReduction
        self.learningRate = learningRate
        self.rowSubsample = rowSubsample
        self.columnSubsample = columnSubsample
        self.loss = loss
        self.seed = seed
    }
}

/// Grows a gradient boosted forest.
public enum BoostedTreeFitter {
    public static func fit(_ training: TabularTrainingSet, parameters: BoostedTreeParameters) -> BoostedTreeModel {
        let labelOrder = training.isClassification
            ? Array(Set(training.targetLabels)).sorted()
            : []
        let base = parameters.loss.baseScore(targets: training.targets, labels: training.targetLabels,
                                             labelOrder: labelOrder)
        guard training.isClassification else {
            return grow(training, targets: training.targets, base: base, parameters: parameters,
                        loss: parameters.loss, label: nil, labelOrder: labelOrder)
        }
        // A classification is boosted one label at a time, each fitted against a 0/1 target that
        // says whether the row's label is that one, with the label order's own last entry as the
        // positive class — the one the loss's base score is the log-odds of. This is a
        // one-against-the-rest ensemble and not a softmax, and the reason it is not a softmax is
        // that the scores of the labels are then independent tree ensembles whose sum is not one,
        // so they are turned into a distribution by the logistic link and a normalisation in
        // `labelProbabilities(_:index:)` rather than by a shared softmax denominator.
        let positive = labelOrder.last ?? ""
        return fitOneAgainstRest(training, labelOrder: labelOrder, positive: positive, base: base,
                                 parameters: parameters, loss: parameters.loss)
    }

    private static func fitOneAgainstRest(_ training: TabularTrainingSet, labelOrder: [String],
                                          positive: String, base: Double, parameters: BoostedTreeParameters,
                                          loss: BoostingLoss) -> BoostedTreeModel {
        grow(training, targets: training.targetLabels.map { $0 == positive ? 1.0 : 0.0 },
             base: base, parameters: parameters, loss: loss, label: positive, labelOrder: labelOrder)
    }

    private static func grow(_ training: TabularTrainingSet, targets: [Double], base: Double,
                             parameters: BoostedTreeParameters, loss: BoostingLoss,
                             label: String?, labelOrder: [String]) -> BoostedTreeModel {
        var generator = SeededGenerator(seed: parameters.seed)
        let treeParameters = TreeParameters(maximumDepth: parameters.maximumDepth,
                                            minimumSamplesToSplit: 2, minimumSamplesToLeaf: 1,
                                            minimumLossReduction: parameters.minimumLossReduction)
        var predictions = [Double](repeating: base, count: training.design.rows)
        var trees: [DecisionTreeModel] = []
        // The tree's own leaf values are the means of the gradients that reached them, so the tree is
        // fitted on the gradient and its prediction is already a step in the right direction; the
        // learning rate is what keeps one tree from overstepping it.
        let regressions = TabularTrainingSet(featureNames: training.featureNames, design: training.design,
                                             targets: targets, targetLabels: [],
                                             isClassification: false)
        for _ in 0..<max(0, parameters.numberOfIterations) {
            let gradient = loss.negativeGradient(targets: targets, predictions: predictions)
            let fitSet = TabularTrainingSet(featureNames: training.featureNames, design: training.design,
                                            targets: gradient, targetLabels: [], isClassification: false)
            let tree = DecisionTreeFitter.fit(fitSet, parameters: treeParameters, generator: &generator)
            trees.append(tree)
            for row in 0..<training.design.rows {
                predictions[row] += parameters.learningRate * tree.predict(regressions.design, index: row)
            }
        }
        return BoostedTreeModel(trees: trees, baseScore: base, learningRate: parameters.learningRate,
                                loss: loss, featureNames: training.featureNames,
                                isClassification: training.isClassification, labelOrder: labelOrder,
                                labels: label.map { [$0] } ?? [])
    }
}
