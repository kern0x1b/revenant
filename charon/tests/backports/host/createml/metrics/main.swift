// metrics.swift — the port's classification metrics against the host's own, row for row.
//
// The host has `ClassificationMetrics` in its `CreateMLComponents`, so this is a straight differential:
// the same (predicted, truth) pairs go into both objects and every count and every score is compared.
// The regression measures are compared against the closed form, because the host's are free functions
// over CreateML's own `MLDataTable` and the port's are over two columns, and the numbers are the claim
// either way.
import Foundation
import PortCreateMLComponents
import CreateMLComponents

var checks = 0
var failures = 0

func check(_ what: String, _ equal: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if !equal {
        failures += 1
        print("FAIL \(what)\(detail().isEmpty ? "" : ": \(detail())")")
    }
}

func checkClose(_ what: String, _ a: Double, _ b: Double, _ tolerance: Double) {
    checks += 1
    let difference = abs(a - b)
    if !(difference <= tolerance) {
        failures += 1
        print("FAIL \(what): the port answers \(a), the host \(b), a difference of \(difference)")
    }
}

func checkEqual<T: Equatable>(_ what: String, _ a: T, _ b: T) {
    check(what, a == b, "the port answers \(a), the host \(b)")
}

// A table with four labels, every kind of row in it: a hit, a miss, a label predicted that never
// occurs as an answer, a label that occurs as an answer and is never predicted, and a row whose
// answer is outside the set the caller named.
let predicted = ["cat", "dog", "cat", "bird", "dog", "cat", "fox", "dog"]
let truth =    ["cat", "cat", "dog", "bird", "dog", "bird", "fox", "cat"]
let labelSet: Set<String> = ["cat", "dog", "bird", "fox"]

do {
    var mine = PortCreateMLComponents.ClassificationMetrics<String>()
    mine.labels = labelSet
    mine.add(predicted: predicted, groundTruth: truth)
    let theirs: CreateMLComponents.ClassificationMetrics<String> =
        CreateMLComponents.ClassificationMetrics(predicted: predicted, groundTruth: truth,
                                                labels: labelSet)
    checkEqual("the example count", mine.exampleCount, theirs.exampleCount)
    checkEqual("the labels seen", mine.labels, theirs.labels)
    checkClose("the accuracy", mine.accuracy, theirs.accuracy, 1e-12)

    for label in labelSet.sorted() {
        checkEqual("the true count of \(label)", mine.count(label: label), theirs.count(label: label))
        // The host's `count(predicted:)` answers 0 for every label, on a table where rows were
        // predicted as three of these four labels. It is a measured divergence and the port keeps the
        // real number; what is compared is that the port's is the real number, by counting the rows.
        let predictedHere = predicted.filter { $0 == label }.count
        checkEqual("the port's predicted count of \(label), counted from the rows",
                   mine.count(predicted: label), predictedHere)
        check("the host's count(predicted:) is not that, and is recorded",
              theirs.count(predicted: label) != predictedHere,
              "the host answers " + String(theirs.count(predicted: label)) + " where the rows say "
              + String(predictedHere))
        checkEqual("the true positives of \(label)", mine.truePositiveCount(of: label),
                   theirs.truePositiveCount(of: label))
        checkEqual("the false positives of \(label)", mine.falsePositiveCount(of: label),
                   theirs.falsePositiveCount(of: label))
        checkEqual("the false negatives of \(label)", mine.falseNegativeCount(of: label),
                   theirs.falseNegativeCount(of: label))
        checkEqual("the true negatives of \(label)", mine.trueNegativeCount(of: label),
                   theirs.trueNegativeCount(of: label))
        checkClose("the precision of \(label)", mine.precisionScore(label: label),
                   theirs.precisionScore(label: label), 1e-12)
        checkClose("the recall of \(label)", mine.recallScore(label: label),
                   theirs.recallScore(label: label), 1e-12)
        checkClose("the F1 of \(label)", mine.f1Score(label: label), theirs.f1Score(label: label), 1e-12)
    }

    // The confusion matrix, as a table of counts. The host's is an `MLShapedArray<Float>`; it is read
    // here position by position, which is the same table and does not need the port's shaped array to
    // exist in the same process.
    let hostMatrix = theirs.makeConfusionMatrix()
    // The port's matrix is the framework's own `MLShapedArray<Float>`, read through its own strides.
    let portShaped = mine.makeConfusionMatrix()
    checkEqual("the port's matrix is a shaped array of the row by the column",
               portShaped.shape, [labelSet.count, labelSet.count])
    checkEqual("with the strides a row-major two-dimensional block has", portShaped.strides, [labelSet.count, 1])
    var portMatrix = [[Int]]()
    for row in 0..<labelSet.count {
        var cells = [Int]()
        for column in 0..<labelSet.count { cells.append(Int(portShaped[indices: row, column])) }
        portMatrix.append(cells)
    }
    // And the plain-array reading is the same numbers in the same order, so a caller without CoreML
    // is not being given a second answer.
    checkEqual("the plain-array matrix is the shaped array's, cell for cell",
               mine.makeConfusionMatrixRows(), portMatrix)
    checkEqual("and the label order is published", mine.confusionMatrixLabelOrder.count, labelSet.count)
    checkEqual("the confusion matrix's shape", portMatrix.map { $0.count },
               Array(repeating: labelSet.count, count: labelSet.count))
    let count = labelSet.count
    var hostCells = [Int](repeating: 0, count: count * count)
    hostMatrix.withUnsafeShapedBufferPointer { buffer, _, _ in
        for index in 0..<min(buffer.count, hostCells.count) {
            hostCells[index] = Int(buffer[index])
        }
    }
    let order = labelSet.sorted()
    for (row, answer) in order.enumerated() {
        for (column, guess) in order.enumerated() {
            // The host's matrix indexes by a *label* on both axes, which is what its own subscript
            // `subscript(answer: String, label: String)` is for; `scalarAt` is the position form.
            // The host's matrix is a shaped array, and the one member that gives its scalars in
            // storage order is `withUnsafeShapedBufferPointer`; its `subscript(indices:)` answers a
            // *slice*, which is a one-element view and not the number a cell is.
            checkEqual("the cell (\(answer), \(guess))", portMatrix[row][column], hostCells[row * count + column])
        }
    }

    // The same object filled a row at a time must equal the one built from two sequences, and the
    // incremental path is the one a live model uses.
    var incremental = PortCreateMLComponents.ClassificationMetrics<String>()
    incremental.restrictToKnownLabels = true
    for index in 0..<predicted.count {
        incremental.add(predicted: predicted[index], label: truth[index])
    }
    checkEqual("a row-at-a-time count equals the two-sequence one", incremental.exampleCount, mine.exampleCount)
    checkClose("a row-at-a-time accuracy equals the two-sequence one", incremental.accuracy, mine.accuracy, 1e-12)

    // A label the caller never named: the row is counted, the answer's true count is recorded, and no
    // precision is claimed for a class that was never predicted.
    var open = PortCreateMLComponents.ClassificationMetrics<String>()
    open.add(predicted: ["cat", "cat"], groundTruth: ["cat", "wolf"])
    checkEqual("an unnamed answer still counts the row", open.exampleCount, 2)
    checkEqual("an unnamed answer's true count", open.count(label: "wolf"), 1)
    checkEqual("an unnamed answer has no precision to claim", open.precisionScore(label: "wolf"), 0)

    // `mapLabels`: the same counts under different names, which is what a caller does to put a
    // model's labels into its own vocabulary.
    let renamed = mine.mapLabels { "label_" + $0 }
    checkEqual("the renamed example count", renamed.exampleCount, mine.exampleCount)
    checkEqual("the renamed label count", renamed.labels.count, mine.labels.count)
    checkClose("the renamed accuracy", renamed.accuracy, mine.accuracy, 1e-12)
    checkEqual("the renamed true count", renamed.count(label: "label_cat"), mine.count(label: "cat"))
} catch {
    print("FAIL the classification metrics comparison threw: \(error)")
    failures += 1
}

// The regression measures, against the closed form: predictions beside targets, every row an error
// the port can write down.
do {
    let answers = [10.0, 20.0, 30.0, 40.0]
    let guesses = [12.0, 18.0, 33.0, 38.0]
    let errors = [-2.0, 2.0, -3.0, 2.0]   // prediction - target, as the functions define it
    let absolute = [2.0, 2.0, 3.0, 2.0]

    checkClose("the root mean squared error",
               PortCreateMLComponents.RegressionMetrics.rootMeanSquaredError(guesses, answers),
               (errors.map { $0 * $0 }.reduce(0, +) / 4).squareRoot(), 1e-12)
    checkClose("the mean absolute error",
               PortCreateMLComponents.RegressionMetrics.meanAbsoluteError(guesses, answers),
               absolute.reduce(0, +) / 4, 1e-12)
    checkClose("the maximum absolute error",
               PortCreateMLComponents.RegressionMetrics.maximumAbsoluteError(guesses, answers),
               absolute.max()!, 1e-12)
    checkClose("the mean error, which is not the mean absolute error",
               PortCreateMLComponents.RegressionMetrics.meanError(guesses, answers),
               errors.reduce(0, +) / 4, 1e-12)
    // The mean error cancels on a table where the model is as wrong high as it is wrong low, and the
    // mean absolute error does not: the difference between the two numbers *is* the point of having
    // both, and a test that did not separate them would not notice if one were wrong.
    check("the mean error cancels where the mean absolute error does not",
          abs(PortCreateMLComponents.RegressionMetrics.meanError(guesses, answers)) < 0.5
              && PortCreateMLComponents.RegressionMetrics.meanAbsoluteError(guesses, answers) > 2.0,
          "the mean error is " + String(PortCreateMLComponents.RegressionMetrics.meanError(guesses, answers)))

    // A multi-label table, where a row can carry several labels and only an exact match counts.
    var multi = PortCreateMLComponents.MultiLabelClassificationMetrics<String>()
    multi.add(predicted: ["a", "b"], label: ["a", "b"])
    multi.add(predicted: ["a", "c"], label: ["a", "b"])
    multi.add(predicted: ["c"], label: ["c"])
    checkEqual("a multi-label row count", multi.exampleCount, 3)
    checkEqual("a multi-label row exactly right", multi.exactMatchCount, 2)
    checkClose("the exact-match score", multi.exactMatchScore, 2.0 / 3.0, 1e-12)
    checkEqual("a multi-label true count of a", multi.count(label: "a"), 2)
    checkEqual("a multi-label true positive of a", multi.truePositiveCount(of: "a"), 2)
    checkEqual("a multi-label false negative of b", multi.falseNegativeCount(of: "b"), 1)
    checkClose("a multi-label precision of a", multi.precisionScore(label: "a"), 1.0, 1e-12)
    checkClose("a multi-label recall of a", multi.recallScore(label: "a"), 1.0, 1e-12)
} catch {
    print("FAIL the regression measures threw: \(error)")
    failures += 1
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
