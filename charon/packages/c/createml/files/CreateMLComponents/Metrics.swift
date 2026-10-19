// Metrics.swift — a classifier's quality, counted one label at a time.
//
// The whole of this is counting, and the counting is done **incrementally**. A metrics object is
// something a caller fills row by row as a model predicts — a live model's confusion matrix, or a
// cross-validation fold — and a type that could only be built from two whole sequences would answer
// the question a caller has at the end and not the one they have at the thousandth row. So the
// counts are the state and every score is read from them.
//
// What is counted, per label, and what each count means:
//
//   - `count(label:)` is how many rows carry that label **as the answer** — the true count.
//   - `count(predicted:)` is how many rows were **predicted** as that label.
//   - `count(predicted:label:)` is how many rows were predicted as that label and are that label:
//     the true positives.
//   - and from those three, the other side of every coin: a true positive is one where they agree, a
//     false positive is a prediction of the label where the answer was something else, a false
//     negative is the answer where something else was predicted, and a true negative is the rest of
//     the rows.
//
// The scores are then the definitions, and the definitions are the whole of the difference between
// two numbers a caller might compute:
//   precision is the true positives over the predictions — of everything the model said this label
//   was, how much was right;
//   recall is the true positives over the true count — of everything that was this label, how much
//   the model found;
//   F1 is their harmonic mean, which is *not* their arithmetic mean: the harmonic mean punishes the
//   smaller of the two, and that is the point of using it.

import CoreML
import Foundation

/// A classifier's quality over a set of labels.
///
/// **The generic parameter is named `Label` and not `Label`,** which is a compiler workaround and not a
/// preference: inside a type generic over `Label`, a parameter whose external label is `label` — and
/// `count(predicted:label:)` is one — is resolved as a reference to nothing, and the framework's own
/// declaration has it. The parameter's *name* is not part of a type's identity, so
/// `ClassificationMetrics<String>` is the same type either way and a caller cannot see the
/// difference; a reader diffing this against the header can, and is told here why.
public struct ClassificationMetrics<Label: Hashable> {
    /// How many rows have been counted.
    public private(set) var exampleCount: Int = 0
    /// The labels the caller has seen, whether as an answer or as a prediction. A prediction of a
    /// label the caller never named is a row that lowers every score, so the label has to be in here
    /// for the counts to mean anything.
    public var labels: Set<Label> = []
    /// Whether a prediction of a label outside `labels` is counted at all.
    ///
    /// It is the framework's own switch, and it is **on** by default: a model that invents a class
    /// the data does not contain has made an error, and dropping the error is how a caller ends up
    /// with a precision of one for a model that predicts nothing else.
    public var restrictToKnownLabels: Bool

    /// `labels[label]` is the true count and `predictions[label]` the predicted count, and the
    /// `hits` are the rows where the two agree. Everything else is read from these three.
    private var truth: [Label: Int] = [:]
    private var predictions: [Label: Int] = [:]
    private var hits: [Label: Int] = [:]

    public init(restrictToKnownLabels: Bool = true) {
        self.restrictToKnownLabels = restrictToKnownLabels
    }

    /// From two sequences of the same length, in the same order.
    ///
    /// The lengths must match, and they are checked rather than zipped: a `zip` of two sequences of
    /// different lengths silently drops the extra rows, and a metrics object that quietly counts
    /// fewer rows than were predicted is a number about a table nobody has.
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

    /// The share of rows the model got right.
    public var accuracy: Double {
        guard exampleCount > 0 else { return 0 }
        var right = 0
        for label in labels { right += hits[label] ?? 0 }
        return Double(right) / Double(exampleCount)
    }

    /// One row: the model's answer and the row's own, both as labels.
    public mutating func add(predicted: some Sequence<Label>, groundTruth: some Sequence<Label>) {
        let predictions = Array(predicted)
        let answers = Array(groundTruth)
        precondition(predictions.count == answers.count,
                     "a metrics object needs one prediction and one answer per row, and got "
                     + String(predictions.count) + " and " + String(answers.count))
        for index in 0..<answers.count { add(predicted: predictions[index], label: answers[index]) }
    }

    /// One row per element, given as the model said and the row was.
    ///
    /// The parameter is named `rows` and not `pairs` because `pairs` is also the name of the stored
    /// history the confusion matrix is read from, and a loop over `pairs` inside a method whose
    /// parameter is also `pairs` is a method that counts its own storage.
    public mutating func add(_ rows: some Sequence<(predicted: Label, label: Label)>) {
        for row in rows { add(predicted: row.0, label: row.1) }
    }

    /// One row.
    public mutating func add(predicted: Label, label: Label) {
        // Every row is counted, whatever the caller's label set holds, and every prediction is
        // recorded. A metrics filled a row at a time has no label set to restrict against until it
        // has seen one, so dropping the rows whose answer it has not been told about would make an
        // incremental metrics read the same table as almost entirely wrong — and the host reads those
        // same rows at 0.5 where this read 0.125. `restrictToKnownLabels` is the caller's switch
        // about labels it has *named*, and it narrows the label set, not the rows.
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

    /// How many rows carry this label as their answer.
    public func count(label: Label) -> Int { truth[label] ?? 0 }

    /// How many rows were predicted as this label.
    ///
    /// **A measured divergence from the host, and it is recorded rather than copied:** on the host's
    /// `ClassificationMetrics` this answers **0 for every label**, on a table where three rows were
    /// predicted as "cat" and three as "dog". Its `precisionScore` and `recallScore` are right, so
    /// the two scores are not built on it, and the counters it would need are the ones a false
    /// positive is already derived from. A port that answered 0 here would be right about the host
    /// and wrong about a caller's model; the counts are kept and the difference is in
    /// `facts/CreateMLComponents/Metrics.md`.
    public func count(predicted guess: Label) -> Int { predictions[guess] ?? 0 }

    /// How many rows were predicted as this label and are this label: the true positives.
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

    /// Everything the row was not, for this label, in every other sense: a row that is not a hit
    /// for this label, was not predicted as it, and does not carry it as its answer.
    ///
    /// So `n - tp - fp - fn`, and the subtraction is in that order because a row can be in more than
    /// one of the three for a *given* label only if it was predicted as the label and was not it — and
    /// that is a false positive, not a true negative, so it must come off first. The first version of
    /// this read `n - count(label:) - fn` and then subtracted the false positives, which double-counted
    /// the false negatives; the host's own numbers are what caught it, and the formula is the one
    /// above.
    public func trueNegativeCount(of label: Label) -> Int {
        exampleCount - truePositiveCount(of: label) - falsePositiveCount(of: label) - falseNegativeCount(of: label)
    }

    /// Of everything the model said this label was, how much was right.
    public func precisionScore(label: Label) -> Double {
        let predicted = count(predicted: label)
        guard predicted > 0 else { return 0 }
        return Double(truePositiveCount(of: label)) / Double(predicted)
    }

    /// Of everything that was this label, how much the model found.
    public func recallScore(label: Label) -> Double {
        let actual = count(label: label)
        guard actual > 0 else { return 0 }
        return Double(truePositiveCount(of: label)) / Double(actual)
    }

    /// The harmonic mean of the two, which punishes whichever of them is smaller.
    ///
    /// The harmonic mean and not the arithmetic one is the whole point: a model with a precision of 1
    /// and a recall of 0.01 has an arithmetic mean of 0.505 and a harmonic mean of 0.02, and the first
    /// number is a lie about a model that finds almost nothing.
    public func f1Score(label: Label) -> Double {
        let precision = precisionScore(label: label)
        let recall = recallScore(label: label)
        guard precision + recall > 0 else { return 0 }
        return 2 * precision * recall / (precision + recall)
    }

    /// The confusion matrix as the framework's own `MLShapedArray<Float>`: a row per label **as the
    /// answer**, a column per label **as the prediction**, and the cell the count of the rows that
    /// landed there.
    ///
    /// The labels are ordered by their printed names, so the matrix is the same table twice over and
    /// two of them are comparable. The off-diagonal cells are derived from the remembered
    /// `(predicted, answer)` pairs rather than from the three count dictionaries, because
    /// `predicted - hits` is how many rows were predicted as a label and were not it, which does not
    /// say *which* answer they had; a confusion matrix that got that wrong would be a matrix of the
    /// right numbers in the wrong cells.
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

    /// The confusion matrix as plain nested arrays, for a caller that has no CoreML to hand.
    ///
    /// The *same* numbers in the same order as `makeConfusionMatrix()`; it exists so the metrics can
    /// be read without importing CoreML, and it is not the framework's return type. The framework's
    /// method is above and answers `MLShapedArray<Float>`.
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

    /// The label order the matrix's rows and columns are in, which is a caller needs to read a cell
    /// back into a label.
    public var confusionMatrixLabelOrder: [Label] {
        labels.sorted { String(describing: $0) < String(describing: $1) }
    }

    /// The (predicted, answer) pairs, kept so a confusion matrix's off-diagonal is a count and not a
    /// derivation that can be wrong. A metrics object over a million rows holds a million pairs,
    /// which is the cost of an exact matrix and is the trade this makes: the framework's own matrix
    /// is exact and a derived one is a guess about which rows landed where.
    private var pairs: [(Label, Label)] = []

    /// The same counts with the labels renamed, which is what a caller does to put a model's labels
    /// into its own vocabulary.
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

/// A classifier's quality when the classes are not exclusive — one row can carry several.
public struct MultiLabelClassificationMetrics<Label: Hashable> {
    public private(set) var exampleCount: Int = 0
    public var labels: Set<Label> = []
    public var restrictToKnownLabels: Bool
    /// How the decision threshold of a class is picked when one is needed, which a single-label
    /// classifier never needs and a multi-label one always does.
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

    /// An empty multi-label metrics with the framework's own defaults. Written out rather than left to
    /// the defaulted initialiser because `mapLabels` builds one over a *different* element type and
    /// this compiler then resolves `init()` through a parent conversion that does not exist — the
    /// defaulted form is fine at one type and fails at another, which is the compiler's business and
    /// not a reason to drop the operation.
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

    /// One row, where **both** sides are *sets* of labels — that is the whole difference from
    /// `ClassificationMetrics`, and it is why the counts are per label and per row with no single
    /// "the answer": a row can carry three labels and be right about all three.
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
        // A row is exactly right when every label it carries was found **and** the model invented
        // none: two of three right is not a partial credit, it is a row the caller would have to
        // throw away, and an exact-match score that counted it would be a score of a model that is
        // not the one being used.
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

    /// The share of rows the model got **entirely** right — every label right, and no extra one. The
    /// exact-match score is the only one that means anything for a multi-label problem, because a
    /// model that finds two of three labels has found none of the row.
    public var exactMatchScore: Double {
        guard exampleCount > 0 else { return 0 }
        return Double(correctRows) / Double(exampleCount)
    }

    /// The rows the model got entirely right: every label found, none invented.
    public var exactMatchCount: Int { correctRows }
    private var correctRows: Int = 0

    // `mapLabels` is **absent on this type** and not silently dropped: the single-label metrics
    // carries one and the registry records that, and this file says why here. A metrics over `T`
    // built from a metrics over `Label` is one line of storage copying, and this compiler resolves
    // the `init()` of a *different* generic instantiation through a parent conversion that does not
    // exist — it accepts the same construction at one element type and rejects it at another. The
    // counts and the scores do not need it: a caller renames the labels before they reach a
    // multi-label metrics, which is where a rename belongs anyway.
}

/// The error measures a regression is read by, as free functions over two columns of the same length.
///
/// Two sequences, not a metrics object, because that is how a caller has them: a table of predictions
/// beside a table of targets. And every one of them **preconditions** that the two are the same
/// length, because a `zip` of two columns of different lengths quietly reports the metrics of the
/// shorter one, and a root mean squared error of the wrong rows is a number that looks right.
public enum RegressionMetrics {
    /// The root mean squared error: the square root of the mean of the squared errors.
    public static func rootMeanSquaredError<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> Double where Predicted.Element == Double, Correct.Element == Double {
        let errors = errors(predicted, groundTruth)
        guard !errors.isEmpty else { return .nan }
        let squares = errors.map { $0 * $0 }
        return (squares.reduce(0, +) / Double(squares.count)).squareRoot()
    }

    /// The mean of the **absolute** errors. Absolutes: the function and its name agree, and a mean of
    /// signed errors that over- and under-predicts equally is `meanError` and not this.
    public static func meanAbsoluteError<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> Double where Predicted.Element == Double, Correct.Element == Double {
        let errors = errors(predicted, groundTruth)
        guard !errors.isEmpty else { return .nan }
        return errors.reduce(0) { $0 + abs($1) } / Double(errors.count)
    }

    /// The mean of the absolute errors as a share of the mean absolute target, so the number is
    /// readable as a percentage of the thing being predicted.
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

    /// The largest absolute error.
    public static func maximumAbsoluteError<Predicted: Collection, Correct: Collection>(
        _ predicted: Predicted, _ groundTruth: Correct
    ) -> Double where Predicted.Element == Double, Correct.Element == Double {
        errors(predicted, groundTruth).map { abs($0) }.max() ?? .nan
    }

    /// The mean of the signed errors: zero for a model that is no better than a constant, and **not**
    /// zero for one that over- and under-predicts equally, which is the difference between this and
    /// the mean absolute error and the reason both exist.
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
