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

    let hostMatrix = theirs.makeConfusionMatrix()
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
            checkEqual("the cell (\(answer), \(guess))", portMatrix[row][column], hostCells[row * count + column])
        }
    }

    var incremental = PortCreateMLComponents.ClassificationMetrics<String>()
    incremental.restrictToKnownLabels = true
    for index in 0..<predicted.count {
        incremental.add(predicted: predicted[index], label: truth[index])
    }
    checkEqual("a row-at-a-time count equals the two-sequence one", incremental.exampleCount, mine.exampleCount)
    checkClose("a row-at-a-time accuracy equals the two-sequence one", incremental.accuracy, mine.accuracy, 1e-12)

    var open = PortCreateMLComponents.ClassificationMetrics<String>()
    open.add(predicted: ["cat", "cat"], groundTruth: ["cat", "wolf"])
    checkEqual("an unnamed answer still counts the row", open.exampleCount, 2)
    checkEqual("an unnamed answer's true count", open.count(label: "wolf"), 1)
    checkEqual("an unnamed answer has no precision to claim", open.precisionScore(label: "wolf"), 0)

    let renamed = mine.mapLabels { "label_" + $0 }
    checkEqual("the renamed example count", renamed.exampleCount, mine.exampleCount)
    checkEqual("the renamed label count", renamed.labels.count, mine.labels.count)
    checkClose("the renamed accuracy", renamed.accuracy, mine.accuracy, 1e-12)
    checkEqual("the renamed true count", renamed.count(label: "label_cat"), mine.count(label: "cat"))
} catch {
    print("FAIL the classification metrics comparison threw: \(error)")
    failures += 1
}

do {
    let answers = [10.0, 20.0, 30.0, 40.0]
    let guesses = [12.0, 18.0, 33.0, 38.0]
    let errors = [-2.0, 2.0, -3.0, 2.0]
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
    check("the mean error cancels where the mean absolute error does not",
          abs(PortCreateMLComponents.RegressionMetrics.meanError(guesses, answers)) < 0.5
              && PortCreateMLComponents.RegressionMetrics.meanAbsoluteError(guesses, answers) > 2.0,
          "the mean error is " + String(PortCreateMLComponents.RegressionMetrics.meanError(guesses, answers)))

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
