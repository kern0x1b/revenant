import Foundation

public indirect enum TreeNode {
    case leaf(value: Double, probabilities: [String: Double], count: Int)
    case split(feature: Int, threshold: Double, categories: [String]?, left: TreeNode, right: TreeNode)

    public var isLeaf: Bool { if case .leaf = self { return true } else { return false } }

    public func evaluate(_ row: RowMatrix, rowIndex: Int, featureNames: [String]) -> (value: Double, probabilities: [String: Double]) {
        switch self {
        case .leaf(let value, let probabilities, _):
            return (value, probabilities)
        case .split(let feature, let threshold, let categories, let left, let right):
            let value = row[rowIndex, feature]
            let goesLeft: Bool
            if let categories = categories {
                goesLeft = categories.contains(TrainingColumn.describe(value))
            } else {
                goesLeft = value <= threshold
            }
            return goesLeft ? left.evaluate(row, rowIndex: rowIndex, featureNames: featureNames)
                            : right.evaluate(row, rowIndex: rowIndex, featureNames: featureNames)
        }
    }
}

public struct TreeParameters {
    public var maximumDepth: Int
    public var minimumSamplesToSplit: Int
    public var minimumSamplesToLeaf: Int
    public var minimumLossReduction: Double
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

    public var depthLimit: Int? { maximumDepth > 0 ? maximumDepth : nil }

    public var leafRowLimit: Int {
        Swift.max(minimumSamplesToLeaf, Int(minimumChildWeight.rounded(.up)))
    }
}

public struct DecisionTreeModel {
    public let root: TreeNode
    public let featureNames: [String]
    public let isClassification: Bool
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

    public func predictAll(_ design: RowMatrix) -> [Double] {
        (0..<design.rows).map { predict(design, index: $0) }
    }
}

public enum Impurity {
    public static func variance(_ targets: [Double], rows: [Int]) -> Double {
        guard rows.count > 1 else { return 0 }
        var values = [Double](repeating: 0, count: rows.count)
        for (offset, row) in rows.enumerated() { values[offset] = targets[row] }
        return RowMatrix.variance(values)
    }

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

    public func impurity() -> Double {
        guard let order = labelOrder else {
            guard count > 1 else { return 0 }
            let n = Double(count)
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

public enum SplitSearch {
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
            if rows.contains(where: { training.design[$0, feature].isNaN }) { continue }
            let order = rows.sorted { training.design[$0, feature] < training.design[$1, feature] }
            var left = SplitSide(values: [], labelOrder: isClassification ? labelOrder : nil)
            var right = side(of: training, rows: order, labels: labels, labelOrder: labelOrder)
            var index = 0
            while index < order.count {
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
