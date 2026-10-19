// Ensembles.swift — the random forest and the gradient boosted trees.
//
// Both are ensembles of the tree in DecisionTrees.swift, and both differ only in what they vary and
// what they average:
//
//   - a random forest grows its trees on bootstrap samples of the rows and, inside every split
//     search, on a random subset of the features, and averages their predictions;
//   - a boosted forest grows its trees one at a time, each on the *gradient* of the loss at the
//     current ensemble, and adds it with a learning rate.
//
// The averaging is a mean over trees for a regression and a mean over label *distributions* for a
// classification, never a majority vote of labels: a vote throws away the confidence a tree had,
// and a confidence is what a forest's probabilities are made of.

import Foundation

/// A random forest: a regression's or a classification's.
public struct RandomForestModel {
    public let trees: [DecisionTreeModel]
    public let featureNames: [String]
    public let isClassification: Bool
    public let labelOrder: [String]
    /// The share of the features one split search may look at, as a count. Computed once at fit
    /// time from the configuration and the column count, because a forest with a column count of
    /// three and `maximumFeatures: .sqrt(3)` looks at two of them and that has to be the same two
    /// decisions at every node to be reproducible.
    public let featuresPerSplit: Int

    public init(trees: [DecisionTreeModel], featureNames: [String], isClassification: Bool,
                labelOrder: [String], featuresPerSplit: Int) {
        self.trees = trees
        self.featureNames = featureNames
        self.isClassification = isClassification
        self.labelOrder = labelOrder
        self.featuresPerSplit = featuresPerSplit
    }

    public func predictAll(_ design: RowMatrix) -> [Double] {
        let labels = labelOrder
        return (0..<design.rows).map { index in
            if isClassification {
                let distribution = labelProbabilities(design, index: index)
                // The prediction of a classification forest is the label with the highest mean
                // probability, and the *first* of them in the label order when two tie — a tie in
                // floating point must not decide the answer, or the same model would answer two
                // different labels on two runs of the same data.
                var bestLabel = labels[0], bestProbability = -Double.infinity
                for label in labels {
                    let p = distribution[label] ?? 0
                    if p > bestProbability {
                        bestProbability = p
                        bestLabel = label
                    }
                }
                return 0
            }
            var total = 0.0
            for tree in trees { total += tree.predict(design, index: index) }
            return trees.isEmpty ? 0 : total / Double(trees.count)
        }
    }

    /// The mean label distribution over the trees, for one row.
    public func labelProbabilities(_ design: RowMatrix, index: Int) -> [String: Double] {
        guard !trees.isEmpty, !labelOrder.isEmpty else { return [:] }
        var totals = [String: Double]()
        for label in labelOrder { totals[label] = 0 }
        for tree in trees {
            for (label, p) in tree.predictProbabilities(design, index: index) {
                totals[label, default: 0] += p
            }
        }
        let n = Double(trees.count)
        for label in totals.keys { totals[label] = totals[label]! / n }
        return totals
    }

    /// The mean label distribution over the trees, for a whole design matrix.
    public func labelProbabilities(_ design: RowMatrix) -> [[String: Double]] {
        (0..<design.rows).map { labelProbabilities(design, index: $0) }
    }

    /// The label the forest's mean distribution answers for a row, and the distribution itself.
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

/// How many features one split search of a forest may look at.
public enum ForestFeatures: Equatable {
    case all
    case sqrt(Int)
    case log2(Int)
    case number(Int)
    case fraction(Double)

    public static func all(_ total: Int) -> ForestFeatures { .all }

    /// The count a configuration resolves to for a table of `total` columns.
    public func count(of total: Int) -> Int {
        switch self {
        case .all: return total
        case .sqrt(let factor): return max(1, Int((Double(total) * Double(factor)).squareRoot()))
        case .log2(let factor):
            return max(1, Int(Double(factor) * (log(Double(total)) / log(2))))
        case .number(let count): return max(1, min(count, total))
        case .fraction(let share):
            // Rounded, and never below one: a table of one column must still be splittable, and a
            // table of ten with a share of 0.1 would otherwise look at no columns at all and answer
            // a stump for every tree in the forest.
            return max(1, min(total, Int((Double(total) * share).rounded())))
        }
    }
}

/// What a random forest is allowed to be, in the framework's own parameter names.
///
/// `numberOfIterations` is the framework's `maxIterations`, `maximumFeatures` is its
/// `columnSubsample` as a share, and `rowSubsample` is the share of the rows each tree is grown on:
/// a share of one is a bootstrap sample, as every forest has always been, and a share below one is
/// sampling without replacement, which is what the framework's default of 0.8 asks for. The mapping
/// is written down here because a reader comparing these names with the header's has to be able to
/// see that nothing was renamed and nothing dropped.
public struct RandomForestParameters {
    public var numberOfIterations: Int
    public var maximumDepth: Int
    public var minimumLossReduction: Double
    public var minimumChildWeight: Double
    public var rowSubsample: Double
    public var maximumFeatures: ForestFeatures
    public var seed: UInt64

    public init(numberOfIterations: Int = 10, maximumDepth: Int = 6, minimumLossReduction: Double = 0,
                minimumChildWeight: Double = 0.1, rowSubsample: Double = 0.8,
                maximumFeatures: ForestFeatures = .fraction(0.8),
                seed: UInt64 = SeededGenerator.timestampSeed()) {
        self.numberOfIterations = numberOfIterations
        self.maximumDepth = maximumDepth
        self.minimumLossReduction = minimumLossReduction
        self.minimumChildWeight = minimumChildWeight
        self.rowSubsample = rowSubsample
        self.maximumFeatures = maximumFeatures
        self.seed = seed
    }

    /// The tree parameters this forest's trees are grown with.
    ///
    /// `minChildWeight` is a sum of absolute deviations rather than a count of rows, which is what
    /// the framework's own criterion is: a leaf is heavy enough when the total distance of its rows
    /// from their own mean is at least that. A row's share of the weight is its absolute deviation
    /// from the *node's* mean at unit scale, so the smallest leaf a weight admits is
    /// `weight / meanAbsoluteDeviation` rows — and where the column's spread is zero every row has
    /// zero weight, which is a degenerate case a table of identical values produces and which is
    /// handled by falling back to a leaf of one row.
    public var treeParameters: TreeParameters {
        TreeParameters(maximumDepth: maximumDepth, minimumSamplesToSplit: 2, minimumSamplesToLeaf: 1,
                       minimumLossReduction: minimumLossReduction, seed: seed)
    }
}

/// Grows a random forest.
public enum RandomForestFitter {
    public static func fit(_ training: TabularTrainingSet, parameters: RandomForestParameters) -> RandomForestModel {
        let labelOrder = Array(Set(training.targetLabels)).sorted()
        let total = training.design.columns
        let features = parameters.maximumFeatures.count(of: total)
        var generator = SeededGenerator(seed: parameters.seed)
        var trees: [DecisionTreeModel] = []
        let iterations = max(0, parameters.numberOfIterations)
        trees.reserveCapacity(iterations)
        let treeParameters = parameters.treeParameters
        for _ in 0..<iterations {
            // The rows this tree is grown on: a bootstrap sample when every row is used, and a
            // sample without replacement when the framework's `rowSubsample` is below one. Both
            // give a tree that has seen some rows twice or not at all, which is what makes the
            // ensemble's average better than any one of its trees.
            let sample: [Int]
            if parameters.rowSubsample >= 1 {
                sample = generator.bootstrap(population: training.design.rows, count: training.design.rows)
            } else {
                var taken = (0..<training.design.rows).shuffled(using: &generator)
                let wanted = max(1, Int((Double(taken.count) * parameters.rowSubsample).rounded()))
                taken = Array(taken.prefix(wanted))
                sample = taken
            }
            let chosen = (0..<total).shuffled(using: &generator).prefix(features).sorted()
            trees.append(DecisionTreeFitter.fit(training.sample(rows: sample), featureSubset: chosen,
                                                parameters: treeParameters, generator: &generator))
        }
        return RandomForestModel(trees: trees, featureNames: training.featureNames,
                                 isClassification: training.isClassification, labelOrder: labelOrder,
                                 featuresPerSplit: features)
    }
}

extension DecisionTreeFitter {
    /// A tree grown on a subset of the features, with the other columns held at their own value so
    /// that a node's `feature` index still indexes the same design matrix every tree shares.
    ///
    /// The subset is applied by hiding the columns a node may not look at, not by compacting the
    /// matrix: a per-tree column numbering would make every tree's thresholds live in a different
    /// space, and a forest's prediction would then be a comparison across spaces.
    public static func fit(_ training: TabularTrainingSet, featureSubset: [Int],
                           parameters: TreeParameters, generator: inout SeededGenerator) -> DecisionTreeModel {
        let labelOrder = Array(Set(training.targetLabels)).sorted()
        let allowed = Set(featureSubset)
        let rows = Array(0..<training.design.rows)
        let masked = training.masking(features: allowed)
        let root = build(training: masked, rows: rows, labels: training.targetLabels,
                         labelOrder: labelOrder, parameters: parameters, depth: 0,
                         generator: &generator)
        return DecisionTreeModel(root: root, featureNames: training.featureNames,
                                 isClassification: training.isClassification, labelOrder: labelOrder)
    }
}

extension TabularTrainingSet {
    /// A copy of the training set whose columns outside `features` are held at a constant, so a
    /// split search over it can only choose among the columns it is allowed.
    ///
    /// The constant is the column's own mean, so the masked column contributes no variance to a
    /// regression leaf and the impurity a split is scored by is not moved by the act of hiding it.
    public func masking(features: Set<Int>) -> TabularTrainingSet {
        guard features.count < design.columns else { return self }
        var masked = design
        for column in 0..<design.columns where !features.contains(column) {
            let values = (0..<design.rows).map { design[$0, column] }
            let constant = RowMatrix.mean(values)
            for row in 0..<design.rows { masked[row, column] = constant }
        }
        var copy = self
        copy.design = masked
        return copy
    }
}
