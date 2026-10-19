import Foundation

public enum BoostingLoss {
    case squaredError
    case logLoss

    public func negativeGradient(targets: [Double], predictions: [Double]) -> [Double] {
        switch self {
        case .squaredError:
            return zip(targets, predictions).map { $0 - $1 }
        case .logLoss:
            return zip(targets, predictions).map { $0 - RowMatrix.logistic([$1])[0] }
        }
    }

    public func baseScore(targets: [Double], labels: [String], labelOrder: [String]) -> Double {
        switch self {
        case .squaredError:
            return RowMatrix.mean(targets)
        case .logLoss:
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

public struct BoostedTreeModel {
    public let trees: [DecisionTreeModel]
    public let baseScore: Double
    public let learningRate: Double
    public let loss: BoostingLoss
    public let featureNames: [String]
    public let isClassification: Bool
    public let labelOrder: [String]
    public let labels: [String]

    public func predictAll(_ design: RowMatrix) -> [Double] {
        (0..<design.rows).map { predict(design, index: $0) }
    }

    public func predict(_ design: RowMatrix, index: Int) -> Double {
        guard isClassification else {
            var score = baseScore
            for tree in trees { score += learningRate * tree.predict(design, index: index) }
            return score
        }
        return score(for: labels.first ?? "", design: design, index: index)
    }

    public func score(for label: String, design: RowMatrix, index: Int) -> Double {
        var score = baseScore
        for tree in trees { score += learningRate * tree.predict(design, index: index) }
        return score
    }

    public func labelProbabilities(_ design: RowMatrix, index: Int) -> [String: Double] {
        guard !labelOrder.isEmpty else { return [:] }
        var raw = [Double](repeating: 0, count: labelOrder.count)
        for (position, label) in labelOrder.enumerated() {
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
