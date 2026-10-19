import Foundation

public struct RandomForestModel {
    public let trees: [DecisionTreeModel]
    public let featureNames: [String]
    public let isClassification: Bool
    public let labelOrder: [String]
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

    public func labelProbabilities(_ design: RowMatrix) -> [[String: Double]] {
        (0..<design.rows).map { labelProbabilities(design, index: $0) }
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

public enum ForestFeatures: Equatable {
    case all
    case sqrt(Int)
    case log2(Int)
    case number(Int)
    case fraction(Double)

    public static func all(_ total: Int) -> ForestFeatures { .all }

    public func count(of total: Int) -> Int {
        switch self {
        case .all: return total
        case .sqrt(let factor): return max(1, Int((Double(total) * Double(factor)).squareRoot()))
        case .log2(let factor):
            return max(1, Int(Double(factor) * (log(Double(total)) / log(2))))
        case .number(let count): return max(1, min(count, total))
        case .fraction(let share):
            return max(1, min(total, Int((Double(total) * share).rounded())))
        }
    }
}

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

    public var treeParameters: TreeParameters {
        TreeParameters(maximumDepth: maximumDepth, minimumSamplesToSplit: 2, minimumSamplesToLeaf: 1,
                       minimumLossReduction: minimumLossReduction, seed: seed)
    }
}

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
