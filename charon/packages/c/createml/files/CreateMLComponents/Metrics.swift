import CoreML
import Foundation

public struct ClassificationMetrics<Label: Hashable> {
    public private(set) var exampleCount: Int = 0
    public var labels: Set<Label> = []
    public var restrictToKnownLabels: Bool

    private var truth: [Label: Int] = [:]
    private var predictions: [Label: Int] = [:]
    private var hits: [Label: Int] = [:]

    public init(restrictToKnownLabels: Bool = true) {
        self.restrictToKnownLabels = restrictToKnownLabels
    }

    public init<Predicted: Sequence, Correct: Sequence>(_ predicted: Predicted, _ groundTruth: Correct)
        where Label == Predicted.Element, Predicted.Element == Correct.Element {
        self.restrictToKnownLabels = true
        add(predicted: predicted, groundTruth: groundTruth)
    }

    public init<Predicted: Sequence, Correct: Sequence>(predicted: Predicted, groundTruth: Correct,
                                                        labels: Set<Label>)
        where Label == Predicted.Element, Predicted.Element == Correct.Element {
        self.restrictToKnownLabels = true
        self.labels = labels
        add(predicted: predicted, groundTruth: groundTruth)
    }

    public init(_ pairs: some Sequence<(predicted: Label, label: Label)>) {
        self.restrictToKnownLabels = true
        add(pairs)
    }

    public init(_ pairs: some Sequence<(predicted: Label, label: Label)>, labels: Set<Label>) {
        self.restrictToKnownLabels = true
        self.labels = labels
        add(pairs)
    }

    public var accuracy: Double {
        guard exampleCount > 0 else { return 0 }
        var right = 0
        for label in labels { right += hits[label] ?? 0 }
        return Double(right) / Double(exampleCount)
    }

    public mutating func add(predicted: some Sequence<Label>, groundTruth: some Sequence<Label>) {
        let predictions = Array(predicted)
        let answers = Array(groundTruth)
        precondition(predictions.count == answers.count,
                     "a metrics object needs one prediction and one answer per row, and got "
                     + String(predictions.count) + " and " + String(answers.count))
        for index in 0..<answers.count { add(predicted: predictions[index], label: answers[index]) }
    }

    public mutating func add(_ rows: some Sequence<(predicted: Label, label: Label)>) {
        for row in rows { add(predicted: row.0, label: row.1) }
    }

    public mutating func add(predicted: Label, label: Label) {
        exampleCount += 1
        truth[label, default: 0] += 1
        labels.insert(label)
        labels.insert(predicted)
        if predicted == label {
            hits[label, default: 0] += 1
        }
        predictions[predicted, default: 0] += 1
        pairs.append((predicted, label))
    }

    public func count(label: Label) -> Int { truth[label] ?? 0 }

    public func count(predicted guess: Label) -> Int { predictions[guess] ?? 0 }

    public func count(predicted guess: Label, label answer: Label) -> Int {
        guess == answer ? (hits[answer] ?? 0) : 0
    }

    public func truePositiveCount(of label: Label) -> Int { hits[label] ?? 0 }

    public func falsePositiveCount(of label: Label) -> Int {
        max(0, (predictions[label] ?? 0) - (hits[label] ?? 0))
    }

    public func falseNegativeCount(of label: Label) -> Int {
        max(0, (truth[label] ?? 0) - (hits[label] ?? 0))
    }

    public func trueNegativeCount(of label: Label) -> Int {
        exampleCount - truePositiveCount(of: label) - falsePositiveCount(of: label) - falseNegativeCount(of: label)
    }

    public func precisionScore(label: Label) -> Double {
        let predicted = count(predicted: label)
        guard predicted > 0 else { return 0 }
        return Double(truePositiveCount(of: label)) / Double(predicted)
    }

    public func recallScore(label: Label) -> Double {
        let actual = count(label: label)
        guard actual > 0 else { return 0 }
        return Double(truePositiveCount(of: label)) / Double(actual)
    }

    public func f1Score(label: Label) -> Double {
        let precision = precisionScore(label: label)
        let recall = recallScore(label: label)
        guard precision + recall > 0 else { return 0 }
        return 2 * precision * recall / (precision + recall)
    }

    public func makeConfusionMatrix() -> MLShapedArray<Float> {
        let order = labels.sorted { String(describing: $0) < String(describing: $1) }
        let count = order.count
        var cells = [Float](repeating: 0, count: count * count)
        for (row, answer) in order.enumerated() {
            for (column, guess) in order.enumerated() {
                let cell = pairs.reduce(0) { total, pair in
                    pair.1 == answer && pair.0 == guess ? total + 1 : total
                }
                cells[row * count + column] = Float(cell)
            }
        }
        return MLShapedArray(scalars: cells, shape: [count, count])
    }

    public func makeConfusionMatrixRows() -> [[Int]] {
        let order = labels.sorted { String(describing: $0) < String(describing: $1) }
        return order.map { answer in
            order.map { guess in
                pairs.reduce(0) { total, pair in
                    pair.1 == answer && pair.0 == guess ? total + 1 : total
                }
            }
        }
    }

    public var confusionMatrixLabelOrder: [Label] {
        labels.sorted { String(describing: $0) < String(describing: $1) }
    }

    private var pairs: [(Label, Label)] = []

    public func mapLabels<T: Hashable>(_ transform: (Label) throws -> T) rethrows -> ClassificationMetrics<T> {
        var out = ClassificationMetrics<T>(restrictToKnownLabels: restrictToKnownLabels)
        out.labels = try Set(labels.map(transform))
        for label in labels {
            out.truth[try transform(label)] = count(label: label)
            out.predictions[try transform(label)] = count(predicted: label)
            out.hits[try transform(label)] = count(predicted: label, label: label)
        }
        out.pairs = try pairs.map { (try transform($0.0), try transform($0.1)) }
        out.exampleCount = exampleCount
        return out
    }
}

public struct MultiLabelClassificationMetrics<Label: Hashable> {
    public private(set) var exampleCount: Int = 0
    public var labels: Set<Label> = []
    public var restrictToKnownLabels: Bool
    public enum ThresholdSelectionStrategy: String, Hashable, Codable {
        case takeHighest
        case takeAll
    }
    public var selectionStrategy: ThresholdSelectionStrategy

    private var truth: [Label: Int] = [:]
    private var predicted: [Label: Int] = [:]
    private var hits: [Label: Int] = [:]

    public init(restrictToKnownLabels: Bool = true,
                selectionStrategy: ThresholdSelectionStrategy = .takeHighest) {
        self.restrictToKnownLabels = restrictToKnownLabels
        self.selectionStrategy = selectionStrategy
    }

    public init() {
        self.restrictToKnownLabels = true
        self.selectionStrategy = .takeHighest
    }

    public mutating func add(predicted: some Sequence<Label>, groundTruth: some Sequence<Label>) {
        let predictions = Array(predicted)
        let answers = Array(groundTruth)
        precondition(predictions.count == answers.count,
                     "a metrics object needs one prediction and one answer per row, and got "
                     + String(predictions.count) + " and " + String(answers.count))
        for index in 0..<answers.count { add(predicted: [predictions[index]], label: [answers[index]]) }
    }

    public mutating func add(predicted: Set<Label>, label: Set<Label>) {
        exampleCount += 1
        labels.formUnion(label)
        labels.formUnion(predicted)
        for answer in label { truth[answer, default: 0] += 1 }
        for guess in predicted { self.predicted[guess, default: 0] += 1 }
        var found = 0
        for answer in label where predicted.contains(answer) {
            hits[answer, default: 0] += 1
            found += 1
        }
        if found == label.count, found == predicted.count { correctRows += 1 }
    }

    public func count(label: Label) -> Int { truth[label] ?? 0 }
    public func count(predicted guess: Label) -> Int { self.predicted[guess] ?? 0 }
    public func count(predicted guess: Label, label answer: Label) -> Int {
        guess == answer ? (hits[answer] ?? 0) : 0
    }
    public func truePositiveCount(of label: Label) -> Int { hits[label] ?? 0 }
    public func falsePositiveCount(of label: Label) -> Int {
        max(0, (self.predicted[label] ?? 0) - (hits[label] ?? 0))
    }
    public func falseNegativeCount(of label: Label) -> Int {
        max(0, (truth[label] ?? 0) - (hits[label] ?? 0))
    }

    public func precisionScore(label: Label) -> Double {
        let predictedCount = count(predicted: label)
        guard predictedCount > 0 else { return 0 }
        return Double(truePositiveCount(of: label)) / Double(predictedCount)
    }

    public func recallScore(label: Label) -> Double {
        let actual = count(label: label)
        guard actual > 0 else { return 0 }
        return Double(truePositiveCount(of: label)) / Double(actual)
    }

    public func f1Score(label: Label) -> Double {
        let precision = precisionScore(label: label)
        let recall = recallScore(label: label)
        guard precision + recall > 0 else { return 0 }
        return 2 * precision * recall / (precision + recall)
    }

    public var exactMatchScore: Double {
        guard exampleCount > 0 else { return 0 }
        return Double(correctRows) / Double(exampleCount)
    }

    public var exactMatchCount: Int { correctRows }
    private var correctRows: Int = 0
}

public enum RegressionMetrics {
    public static func rootMeanSquaredError<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> Double where Predicted.Element == Double, Correct.Element == Double {
        let errors = errors(predicted, groundTruth)
        guard !errors.isEmpty else { return .nan }
        let squares = errors.map { $0 * $0 }
        return (squares.reduce(0, +) / Double(squares.count)).squareRoot()
    }

    public static func meanAbsoluteError<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> Double where Predicted.Element == Double, Correct.Element == Double {
        let errors = errors(predicted, groundTruth)
        guard !errors.isEmpty else { return .nan }
        return errors.reduce(0) { $0 + abs($1) } / Double(errors.count)
    }

    public static func meanAbsolutePercentageError<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> Double where Predicted.Element == Double, Correct.Element == Double {
        let errors = errors(predicted, groundTruth)
        let answers = Array(groundTruth)
        guard !errors.isEmpty else { return .nan }
        let scale = answers.reduce(0.0) { $0 + abs($1) } / Double(answers.count)
        guard scale > 0 else { return .nan }
        let total = zip(errors, answers).reduce(0.0) { $0 + abs($1.0) / abs($1.1) }
        return total / Double(errors.count)
    }

    public static func maximumAbsoluteError<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> Double where Predicted.Element == Double, Correct.Element == Double {
        errors(predicted, groundTruth).map { abs($0) }.max() ?? .nan
    }

    public static func meanError<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> Double where Predicted.Element == Double, Correct.Element == Double {
        let errors = errors(predicted, groundTruth)
        guard !errors.isEmpty else { return .nan }
        return errors.reduce(0, +) / Double(errors.count)
    }

    private static func errors<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> [Double] where Predicted.Element == Double, Correct.Element == Double {
        let predictions = Array(predicted)
        let answers = Array(groundTruth)
        precondition(predictions.count == answers.count,
                     "a metric needs one prediction and one answer per row, and got "
                     + String(predictions.count) + " and " + String(answers.count))
        return zip(predictions, answers).map { $1 - $0 }
    }
}
