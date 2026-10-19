// DecisionTrees.swift — a CART decision tree, and the two things it is built from: the split search
// and the stopping rule.
//
// A tree here is an ordinary CART tree over the columns of a `TabularTrainingSet`, and the split
// search is the one that is actually used: a numeric column is cut at the midpoint between two
// neighbouring sorted values, a threshold that admits no gap a value could fall into, and a
// categorical column is cut at a subset of its categories found by the same impurity criterion.
//
// The impurity is the one the criterion's name says. A regression tree's is the variance of the
// targets, so a split is chosen to maximise the fall in it, and the prediction is the mean of the
// rows that reach the node. A classification tree's is the Gini impurity, so a split is chosen to
// maximise the fall in it, and the prediction is the most common label that reaches the node, with
// the label probabilities carried alongside so a forest can average distributions rather than
// majority-vote labels.

import Foundation

/// A node of a fitted tree.
public indirect enum TreeNode {
    case leaf(value: Double, probabilities: [String: Double], count: Int)
    case split(feature: Int, threshold: Double, categories: [String]?, left: TreeNode, right: TreeNode)

    public var isLeaf: Bool { if case .leaf = self { return true } else { return false } }

    /// The value this node answers, and the label distribution behind it: a leaf has both, a split
    /// has neither and asks its children.
    public func evaluate(_ row: RowMatrix, rowIndex: Int, featureNames: [String]) -> (value: Double, probabilities: [String: Double]) {
        switch self {
        case .leaf(let value, let probabilities, _):
            return (value, probabilities)
        case .split(let feature, let threshold, let categories, let left, let right):
            let value = row[rowIndex, feature]
            let goesLeft: Bool
            if let categories = categories {
                // A categorical split: the left child holds the named categories. The name of the
                // category is the numeric value's own string, so the two kinds of split are read
                // off the same matrix and the choice between them is the node's, not the row's.
                goesLeft = categories.contains(TrainingColumn.describe(value))
            } else {
                goesLeft = value <= threshold
            }
            return goesLeft ? left.evaluate(row, rowIndex: rowIndex, featureNames: featureNames)
                            : right.evaluate(row, rowIndex: rowIndex, featureNames: featureNames)
        }
    }
}

/// What a tree is allowed to be.
public struct TreeParameters {
    /// How deep the tree may go. Zero means no limit, which is what the framework's own default of
    /// six becomes once a caller asks for a tree grown until it cannot split.
    public var maximumDepth: Int
    /// The fewest rows a node may hold and still be split. One is a leaf-per-sample tree.
    public var minimumSamplesToSplit: Int
    /// The fewest rows a leaf may hold.
    public var minimumSamplesToLeaf: Int
    /// The smallest fall in impurity a split has to buy to be taken — the framework's
    /// `minLossReduction`. Zero splits on any fall, which is what a pure-CART search does; a larger
    /// value is the cheap guard against a split that separates one row from the rest and predicts
    /// nothing.
    public var minimumLossReduction: Double
    /// The framework's `minChildWeight`: a bound on the summed hessian of a leaf.
    ///
    /// For a squared-error loss and for a count objective the hessian is constant per row, so the
    /// summed hessian *is* the number of rows and the bound is one. The framework's own default of
    /// 0.1 is then below one row and does not constrain anything, which is worth saying rather than
    /// quietly rounding it up: a caller who wants a leaf to hold ten rows asks for ten.
    public var minimumChildWeight: Double
    public var seed: UInt64

    public init(maximumDepth: Int = 0, minimumSamplesToSplit: Int = 2, minimumSamplesToLeaf: Int = 1,
                minimumLossReduction: Double = 0, minimumChildWeight: Double = 0,
                seed: UInt64 = SeededGenerator.timestampSeed()) {
        self.maximumDepth = maximumDepth
        self.minimumSamplesToSplit = minimumSamplesToSplit
        self.minimumSamplesToLeaf = minimumSamplesToLeaf
        self.minimumLossReduction = minimumLossReduction
        self.minimumChildWeight = minimumChildWeight
        self.seed = seed
    }

    /// A maximum depth of zero means "no limit", which is what the framework's own default says: a
    /// tree grown until it cannot split is a tree, and a depth of one would be a stump.
    public var depthLimit: Int? { maximumDepth > 0 ? maximumDepth : nil }

    /// The fewest rows a leaf may hold, from both of the framework's row bounds: the explicit
    /// `minimumSamplesToLeaf` and the `minChildWeight` read as a hessian sum, which for every loss
    /// this package fits is a count of rows.
    public var leafRowLimit: Int {
        Swift.max(minimumSamplesToLeaf, Int(minimumChildWeight.rounded(.up)))
    }
}

/// A fitted decision tree, for a regression or a classification.
public struct DecisionTreeModel {
    public let root: TreeNode
    public let featureNames: [String]
    public let isClassification: Bool
    /// The label order of a classification tree, so that a probability vector from one tree lines up
    /// with a probability vector from another.
    public let labelOrder: [String]

    public func predict(_ row: RowMatrix, index: Int) -> Double {
        root.evaluate(row, rowIndex: index, featureNames: featureNames).value
    }

    public func predictProbabilities(_ row: RowMatrix, index: Int) -> [String: Double] {
        root.evaluate(row, rowIndex: index, featureNames: featureNames).probabilities
    }

    public func predict(_ features: [Double]) -> Double {
        let row = RowMatrix(features, rows: 1, columns: features.count)
        return predict(row, index: 0)
    }

    /// The label this tree answers for a row, and the distribution behind it: the most probable
    /// label, with a tie broken by the label order rather than by floating point, so the same model
    /// answers the same label twice.
    public func predictLabel(_ row: RowMatrix, index: Int) -> String {
        guard !labelOrder.isEmpty else { return "" }
        let distribution = root.evaluate(row, rowIndex: index, featureNames: featureNames).probabilities
        var best = labelOrder[0]
        var bestProbability = -Double.infinity
        for label in labelOrder {
            let p = distribution[label] ?? 0
            if p > bestProbability {
                bestProbability = p
                best = label
            }
        }
        return best
    }

    /// Every prediction, in row order.
    public func predictAll(_ design: RowMatrix) -> [Double] {
        (0..<design.rows).map { predict(design, index: $0) }
    }
}

/// The impurity of a node, and the fall a split buys.
public enum Impurity {
    /// The variance of the targets, with zero for an empty node.
    ///
    /// Divided by the node's own count rather than left as a sum of squares, so that a node's
    /// impurity is comparable with another's and the weighted sum a split is scored by is the
    /// weighted *mean* — which is what makes the sum of a split's two children's impurities
    /// comparable with the parent's.
    public static func variance(_ targets: [Double], rows: [Int]) -> Double {
        guard rows.count > 1 else { return 0 }
        var values = [Double](repeating: 0, count: rows.count)
        for (offset, row) in rows.enumerated() { values[offset] = targets[row] }
        return RowMatrix.variance(values)
    }

    /// The Gini impurity of a label distribution, `1 - sum(p_i^2)`.
    ///
    /// Not entropy, because the Gini criterion is the one a decision *tree* is defined by here, and
    /// a boosted tree that used one for classification and the other for feature importance would be
    /// answering two different questions.
    public static func gini(_ labels: [String], rows: [Int], labelOrder: [String]) -> Double {
        guard !rows.isEmpty else { return 1 }
        var counts = [String: Int]()
        for row in rows {
            let label = labels[row]
            counts[label, default: 0] += 1
        }
        let n = Double(rows.count)
        var sumOfSquares = 0.0
        for label in labelOrder {
            let p = Double(counts[label] ?? 0) / n
            sumOfSquares += p * p
        }
        return 1 - sumOfSquares
    }
}

/// The running statistics of one side of a split, so that a sweep over a sorted column scores every
/// threshold without rebuilding either side's impurity.
///
/// A regression's side needs a count, a sum and a sum of squares: its variance is
/// `(sum^2/n - sumsq)/n`, which is the one form a running total can be turned into in constant time.
/// A classification's side needs a count and a histogram, because the Gini impurity is
/// `1 - sum(p^2)`. Both are carried as the same value so the sweep's scoring line is one line.
public struct SplitSide {
    public var count: Int = 0
    public var total: Double = 0
    public var totalSquares: Double = 0
    public var labels: [String: Int] = [:]

    public init(count: Int = 0, total: Double = 0, totalSquares: Double = 0, labels: [String: Int] = [:]) {
        self.count = count
        self.total = total
        self.totalSquares = totalSquares
        self.labels = labels
    }

    public init(values: [Double], labelOrder: [String]? = nil) {
        count = values.count
        if let labelOrder = labelOrder {
            for label in labelOrder { labels[label] = 0 }
            self.labelOrder = labelOrder
        }
        for value in values {
            total += value
            totalSquares += value * value
        }
    }

    /// The labels a classification side counts, in a fixed order. A regression side has none, and
    /// `impurity` answers its variance instead.
    public var labelOrder: [String]?

    public mutating func add(target: Double, label: String?) {
        count += 1
        total += target
        totalSquares += target * target
        if let label = label { labels[label, default: 0] += 1 }
    }

    public mutating func remove(target: Double, label: String?) {
        count -= 1
        total -= target
        totalSquares -= target * target
        if let label = label { labels[label, default: 0] -= 1 }
    }

    /// The Gini impurity of a classification side, or the variance of a regression side.
    ///
    /// The variance is clamped at zero: a sum of accumulated doubles can land a hair below the
    /// true value, and a negative impurity would make every further split on this column look
    /// worthless when it is not.
    public func impurity() -> Double {
        guard let order = labelOrder else {
            guard count > 1 else { return 0 }
            let n = Double(count)
            // `(sum of squares) - (sum)^2/n`, over `n - 1`: the unbiased variance, rearranged so
            // that a running count, sum and sum-of-squares can produce it in constant time. The two
            // terms are subtracted in this order because the first is the larger of the two for any
            // column that has spread at all, and the difference is then clamped at zero — a sum of
            // accumulated doubles can land a hair under the true variance, and a negative impurity
            // would make every later split on the column look worthless.
            let spread = (totalSquares - total * total / n) / (n - 1)
            return spread > 0 ? spread : 0
        }
        guard count > 0 else { return 1 }
        var sumOfSquares = 0.0
        for label in order {
            let p = Double(labels[label] ?? 0) / Double(count)
            sumOfSquares += p * p
        }
        return 1 - sumOfSquares
    }
}

/// The split search.
public enum SplitSearch {
    /// The best split of `rows` over the features of `design`, or nil when none buys enough.
    ///
    /// A numeric feature is cut at the midpoint between two neighbouring distinct values, so no
    /// observation can equal the threshold and no re-ordering of the data changes which side of it a
    /// row falls on. A categorical feature is cut at a subset of its categories, built by the
    /// standard greedy forward search from the empty set: start from no category, keep the one whose
    /// addition buys the most, and stop when the best addition buys nothing. That is exhaustive for
    /// a single category, which is the case a small-cardinality label has, and it is the ordering
    /// the search's own name implies for the rest.
    public static func best(of training: TabularTrainingSet,
                            rows: [Int],
                            labels: [String],
                            labelOrder: [String],
                            parameters: TreeParameters) -> (feature: Int, threshold: Double, categories: [String]?)?
    {
        guard rows.count >= parameters.minimumSamplesToSplit else { return nil }
        let isClassification = training.isClassification
        let weight = Double(rows.count)
        let parent = side(of: training, rows: rows, labels: labels, labelOrder: labelOrder).impurity()
        var bestScore = parameters.minimumLossReduction
        var best: (feature: Int, threshold: Double, categories: [String]?)?

        for feature in 0..<training.design.columns {
            // A NaN in a feature cannot be compared, so it cannot be split on. It is not dropped
            // from the node's rows either: that would silently change what the node is made of, so
            // the column is passed over and the impurity it leaves behind is the tree's answer
            // about that feature.
            if rows.contains(where: { training.design[$0, feature].isNaN }) { continue }
            let order = rows.sorted { training.design[$0, feature] < training.design[$1, feature] }
            var left = SplitSide(values: [], labelOrder: isClassification ? labelOrder : nil)
            var right = side(of: training, rows: order, labels: labels, labelOrder: labelOrder)
            var index = 0
            while index < order.count {
                // Advance past the whole run of equal values, so a threshold is only ever offered
                // between two *distinct* values: a threshold inside a run of equals would put a row
                // on one side and its twin on the other, which is not a split any data can express.
                let value = training.design[order[index], feature]
                var end = index
                while end < order.count, training.design[order[end], feature] == value {
                    let row = order[end]
                    left.add(target: isClassification ? 0 : training.targets[row],
                             label: isClassification ? labels[row] : nil)
                    right.remove(target: isClassification ? 0 : training.targets[row],
                                 label: isClassification ? labels[row] : nil)
                    end += 1
                }
                guard end < order.count else { break }
                if left.count >= parameters.leafRowLimit,
                   right.count >= parameters.leafRowLimit {
                    let score = parent - (left.impurity() * Double(left.count) / weight
                                          + right.impurity() * Double(right.count) / weight)
                    if score > bestScore {
                        bestScore = score
                        best = (feature, (value + training.design[order[end], feature]) / 2, nil)
                    }
                }
                index = end
            }

            // The categorical reading of the same column: a subset of its distinct values, held in
            // the left child. Above the cardinality a subset search is worth doing, the tree splits
            // this column numerically, and the reason is written down rather than left to be
            // guessed at: a subset search is 2^k candidates, and a feature with a hundred distinct
            // values has more of them than a table of any size this port is asked to train on has
            // rows.
            let distinct = Set(order.map { TrainingColumn.describe(training.design[$0, feature]) }).sorted()
            if distinct.count > 1, distinct.count <= 32 {
                let byCategory = Dictionary(grouping: rows) {
                    TrainingColumn.describe(training.design[$0, feature])
                }
                var chosen: Set<String> = []
                var current = parent
                while chosen.count < distinct.count - 1 {
                    var bestCategory: String?
                    var bestGain = 0.0
                    for category in distinct where !chosen.contains(category) {
                        var trial = chosen
                        trial.insert(category)
                        let leftRows = trial.flatMap { byCategory[$0] ?? [] }
                        guard leftRows.count >= parameters.leafRowLimit,
                              rows.count - leftRows.count >= parameters.leafRowLimit else { continue }
                        let leftSide = side(of: training, rows: leftRows, labels: labels, labelOrder: labelOrder)
                        let rightRows = rows.filter { !trial.contains(TrainingColumn.describe(training.design[$0, feature])) }
                        let rightSide = side(of: training, rows: rightRows, labels: labels, labelOrder: labelOrder)
                        let score = current - (leftSide.impurity() * Double(leftRows.count) / weight
                                              + rightSide.impurity() * Double(rightRows.count) / weight)
                        if score > bestGain {
                            bestGain = score
                            bestCategory = category
                        }
                    }
                    guard let category = bestCategory, bestGain > 0 else { break }
                    chosen.insert(category)
                    current -= bestGain
                    // The fall of this subset against the parent's own impurity, which is the same
                    // quantity the numeric sweep above compares, so the two searches rank a
                    // categorical split and a numeric one against each other on one scale.
                    let score = parent - current
                    if score > bestScore {
                        bestScore = score
                        best = (feature, 0, chosen.sorted())
                    }
                }
            }
        }
        return best
    }

    /// The running statistics of a node's rows.
    private static func side(of training: TabularTrainingSet, rows: [Int], labels: [String],
                             labelOrder: [String]) -> SplitSide {
        let isClassification = training.isClassification
        var side = SplitSide(values: [], labelOrder: isClassification ? labelOrder : nil)
        for row in rows {
            side.add(target: isClassification ? 0 : training.targets[row],
                     label: isClassification ? labels[row] : nil)
        }
        return side
    }
}

/// Grows a decision tree.
public enum DecisionTreeFitter {
    public static func fit(_ training: TabularTrainingSet,
                           parameters: TreeParameters,
                           generator: inout SeededGenerator) -> DecisionTreeModel {
        let labelOrder = Array(Set(training.targetLabels)).sorted()
        let all = Array(0..<training.design.rows)
        let root = build(training: training, rows: all, labels: training.targetLabels,
                         labelOrder: labelOrder, parameters: parameters, depth: 0,
                         generator: &generator)
        return DecisionTreeModel(root: root, featureNames: training.featureNames,
                                 isClassification: training.isClassification, labelOrder: labelOrder)
    }

    static func build(training: TabularTrainingSet, rows: [Int], labels: [String],
                              labelOrder: [String], parameters: TreeParameters, depth: Int,
                              generator: inout SeededGenerator) -> TreeNode {
        let value = training.isClassification ? 0 : mean(training.targets, rows)
        let probabilities = training.isClassification
            ? distribution(labels, rows, labelOrder: labelOrder)
            // A regression tree carries an empty distribution rather than a made-up one: its leaves
            // are numbers, and a distribution over labels there would be a second, wrong answer.
            : [:]
        let atMaximumDepth = parameters.depthLimit.map { depth >= $0 } ?? false
        if atMaximumDepth || rows.count < parameters.minimumSamplesToSplit {
            return .leaf(value: value, probabilities: probabilities, count: rows.count)
        }
        guard let split = SplitSearch.best(of: training, rows: rows, labels: labels,
                                           labelOrder: labelOrder, parameters: parameters) else {
            return .leaf(value: value, probabilities: probabilities, count: rows.count)
        }
        var leftRows: [Int] = []
        var rightRows: [Int] = []
        switch split.categories {
        case .some(let categories):
            let chosen = Set(categories)
            for row in rows {
                if chosen.contains(TrainingColumn.describe(training.design[row, split.feature])) {
                    leftRows.append(row)
                } else {
                    rightRows.append(row)
                }
            }
        case .none:
            for row in rows {
                if training.design[row, split.feature] <= split.threshold {
                    leftRows.append(row)
                } else {
                    rightRows.append(row)
                }
            }
        }
        // A split that puts nothing on one side is not a split: the search ranks by the impurity it
        // leaves, and a degenerate one cannot improve, but the guard is kept because the criterion
        // and the partition are two pieces of code and only one of them is the search.
        if leftRows.isEmpty || rightRows.isEmpty {
            return .leaf(value: value, probabilities: probabilities, count: rows.count)
        }
        return .split(feature: split.feature, threshold: split.threshold, categories: split.categories,
                      left: build(training: training, rows: leftRows, labels: labels, labelOrder: labelOrder,
                                  parameters: parameters, depth: depth + 1, generator: &generator),
                      right: build(training: training, rows: rightRows, labels: labels, labelOrder: labelOrder,
                                   parameters: parameters, depth: depth + 1, generator: &generator))
    }

    public static func mean(_ values: [Double], _ rows: [Int]) -> Double {
        guard !rows.isEmpty else { return 0 }
        var total = 0.0
        for row in rows { total += values[row] }
        return total / Double(rows.count)
    }

    public static func distribution(_ labels: [String], _ rows: [Int], labelOrder: [String]) -> [String: Double] {
        var counts = [String: Double]()
        for label in labelOrder { counts[label] = 0 }
        for row in rows { counts[labels[row], default: 0] += 1 }
        let n = Double(rows.count)
        for label in counts.keys { counts[label] = counts[label]! / n }
        return counts
    }
}
