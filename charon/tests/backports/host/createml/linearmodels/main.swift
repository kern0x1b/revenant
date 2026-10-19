import Foundation
import PortCreateMLComponents
import PortCoreML

var checks = 0
var failures = 0

func check(_ what: String, _ equal: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if !equal {
        failures += 1
        print("FAIL \(what)\(detail().isEmpty ? "" : ": \(detail())")")
    }
}

func checkEqual<T: Equatable>(_ what: String, _ a: T, _ b: T) {
    check(what, a == b, "the port answers \(a)")
}

func checkCloseClose(_ what: String, _ a: Double, _ b: Double, _ tolerance: Double) {
    checkClose(what, a, b, tolerance)
}

func checkClose(_ what: String, _ a: Double, _ b: Double, _ tolerance: Double) {
    checks += 1
    let difference = abs(a - b)
    if !(difference <= tolerance) {
        failures += 1
        print("FAIL \(what): the port answers \(a), the closed form says \(b), a difference of \(difference)")
    }
}

typealias Annotated = PortCreateMLComponents.AnnotatedFeature<PortCoreML.MLShapedArray<Double>, Double>

func feature(_ values: [Double]) -> PortCoreML.MLShapedArray<Double> {
    PortCoreML.MLShapedArray(scalars: values, shape: [values.count])
}

do {
    var generator = PortCreateMLComponents.SeededGenerator(seed: 11)
    var rows = [Annotated]()
    var targets = [Double]()
    for _ in 0..<200 {
        let x1 = generator.nextUniform()
        let x2 = generator.nextUniform()
        let y = 3 + 2 * x1 - 1.5 * x2 + generator.nextGaussian(mean: 0, standardDeviation: 0.001)
        rows.append(Annotated(feature: feature([x1, x2]), annotation: y))
        targets.append(y)
    }

    let regressor = PortCreateMLComponents.LinearRegressor<Double>(
        configuration: .init(l2Penalty: 0, l1Penalty: 0))
    let model = try regressor.fitted(to: rows)

    checkEqual("the feature count", model.featureCount, 2)
    checkEqual("the coefficient count, intercept first", model.coefficients.count, 3)
    checkClose("the intercept", Double(model.coefficients[0]), 3, 1e-3)
    checkClose("the first weight", Double(model.coefficients[1]), 2, 1e-3)
    checkClose("the second weight", Double(model.coefficients[2]), -1.5, 1e-3)

    let predictions = try model.prediction(from: rows.map { $0.feature })
    checkEqual("one prediction per row", predictions.count, targets.count)
    var worst = 0.0
    for (index, prediction) in predictions.enumerated() {
        worst = max(worst, abs(Double(prediction) - targets[index]))
    }
    check("the predictions reproduce the table's own target", worst < 0.01,
          "the largest error over \(targets.count) rows is \(worst)")

    checkClose("a one-feature model built by hand, on a row of it",
               try PortCreateMLComponents.LinearRegressorModel<Double>(coefficients: [10, 1])
                   .prediction(from: feature([5])), 15, 1e-12)

    let oneFeature = (0..<50).map { index -> Annotated in
        let x = Double(index)
        return Annotated(feature: feature([x]), annotation: 2 * x)
    }
    let ridge = PortCreateMLComponents.LinearRegressor<Double>(configuration: .init(l2Penalty: 100))
    let ridgeModel = try ridge.fitted(to: oneFeature)
    let unpenalized = try PortCreateMLComponents.LinearRegressor<Double>(configuration: .init(l2Penalty: 0))
        .fitted(to: oneFeature)
    let heavy = try PortCreateMLComponents.LinearRegressor<Double>(configuration: .init(l2Penalty: 1000))
        .fitted(to: oneFeature)
    let plain = Double(unpenalized.coefficients[1])
    let light = Double(ridgeModel.coefficients[1])
    let harder = Double(heavy.coefficients[1])
    check("a ridge penalty shrinks the slope", light < plain, "\(light) is not below \(plain)")
    check("a bigger ridge penalty shrinks it further", harder < light,
          "\(harder) is not below \(light)")
    checkCloseClose("no penalty recovers the slope the data was made with", plain, 2, 1e-9)

    var widthRefused = false
    do {
        _ = try model.prediction(from: feature([1.0]))
    } catch let error as PortCreateMLComponents.LinearModelError {
        widthRefused = true
        let text = "\(error)"
        check("the width refusal names both widths", text.contains("2") && text.contains("1"),
              "the port answers \(error)")
    } catch {}
    check("a model of the wrong width refuses rather than truncating", widthRefused)

    let unpenalised = try PortCreateMLComponents.LinearRegressor<Double>(
        configuration: .init(l2Penalty: 0, l1Penalty: 0, maximumIterations: 500)).fitted(to: rows)
    let penalised = try PortCreateMLComponents.LinearRegressor<Double>(
        configuration: .init(l2Penalty: 0, l1Penalty: 0.5, maximumIterations: 200000,
                             stepSize: 0.1, convergenceThreshold: 1e-8)).fitted(to: rows)

    var reported = false
    do {
        let impatient = PortCreateMLComponents.LinearRegressor<Double>(
            configuration: .init(l2Penalty: 0, l1Penalty: 0.5, maximumIterations: 50,
                                 stepSize: 0.1, convergenceThreshold: 1e-14))
        _ = try impatient.fitted(to: rows)
    } catch let error as PortCreateMLComponents.LinearModelError {
        reported = true
        let text = "\(error)"
        check("and the refusal says the coefficients are not the minimum", text.contains("minimum"),
              "the port answers \(error)")
    } catch {}
    check("an L1 fit that cannot reach its tolerance says so rather than answering the point it reached",
          reported)
    let width = rows.first?.feature.scalars.count ?? 0
    checkEqual("an L1 fit answers one coefficient per feature and an intercept",
               penalised.coefficients.count, width + 1)
    var moved = 0.0
    for index in 0..<penalised.coefficients.count {
        moved = max(moved, abs(Double(penalised.coefficients[index]) - Double(unpenalised.coefficients[index])))
    }
    check("and the penalty moved the answer", moved > 0.0, "the largest change is \(moved)")
    let interceptMoved = abs(Double(penalised.coefficients[0]) - Double(unpenalised.coefficients[0]))
    var weightsMoved = 0.0
    for index in 1..<penalised.coefficients.count {
        weightsMoved = max(weightsMoved,
                           abs(Double(penalised.coefficients[index]) - Double(unpenalised.coefficients[index])))
    }
    check("the penalty skipped the intercept, as the convention says", interceptMoved < weightsMoved,
          "the intercept moved by \(interceptMoved) and a weight by \(weightsMoved)")

    var singularRefused = false
    do {
        let repeated = (0..<20).map { index -> Annotated in
            let x = Double(index)
            return Annotated(feature: feature([x, x]), annotation: 2 * x)
        }
        _ = try PortCreateMLComponents.LinearRegressor<Double>(configuration: .init(l2Penalty: 0))
            .fitted(to: repeated)
    } catch let error as PortCreateMLComponents.LinearModelError {
        singularRefused = true
        check("the singular refusal names a column", "\(error)".contains("column"),
              "the port answers \(error)")
    } catch {}
    check("a rank-deficient design is reported, not answered", singularRefused)

    var classifierRows = [PortCreateMLComponents.AnnotatedFeature<PortCoreML.MLShapedArray<Double>, String>]()
    var labels = [String]()
    for index in 0..<200 {
        let x = Double(index) / 200.0
        let point = x + Double((index * 7) % 13) / 400.0 - 0.015
        let label = point > 0.5 ? "high" : "low"
        classifierRows.append(PortCreateMLComponents.AnnotatedFeature(feature: feature([point]), annotation: label))
        labels.append(label)
    }
    let classifier = PortCreateMLComponents.LogisticRegressionClassifier<Double, String>(
        configuration: .init(l2Penalty: 0.01))
    let classifierModel = try classifier.fitted(to: classifierRows)
    checkEqual("the classifier's feature count", classifierModel.featureCount, 1)
    checkEqual("the classifier's coefficient count, one intercept and one weight per class",
               classifierModel.coefficients.count, 3)

    var right = 0
    for (index, row) in classifierRows.enumerated() {
        if try classifierModel.prediction(from: row.feature).label == labels[index] { right += 1 }
    }
    check("the classifier separates a linearly separable table",
          Double(right) / Double(labels.count) >= 0.95,
          "the port gets \(right) of \(labels.count) right")

    var sumsToOne = true
    var picksTheBest = true
    for row in classifierRows.prefix(20) {
        let distribution = try classifierModel.prediction(from: row.feature)
        let total = distribution.probabilities.values.reduce(0, +)
        if abs(total - 1) > 1e-9 { sumsToOne = false }
        var best = distribution.probabilities[distribution.label] ?? 0
        for value in distribution.probabilities.values where value > best {
            best = value
            picksTheBest = false
        }
    }
    check("the class probabilities sum to one", sumsToOne)
    check("the label it answers is the most probable one", picksTheBest)

    var classifierWidthRefused = false
    do {
        _ = try classifierModel.prediction(from: feature([1, 2]))
    } catch {
        classifierWidthRefused = true
    }
    check("a classifier of the wrong width refuses", classifierWidthRefused)

    var matrix = PortCoreML.MLShapedArray(scalars: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], shape: [2, 3])
    checkEqual("a shaped array's shape", matrix.shape, [2, 3])
    checkEqual("a shaped array's strides, in elements", matrix.strides, [3, 1])
    checkEqual("a shaped array's count is the product of its shape", matrix.count, 6)
    checkClose("a shaped array read by index per dimension", matrix[indices: 1, 2], 6, 1e-12)
    matrix[indices: 1, 2] = 60
    checkClose("a shaped array written by index per dimension", matrix[indices: 1, 2], 60, 1e-12)
    checkClose("a shaped array's buffer, row-major", matrix.scalars[5], 60, 1e-12)
    let block = PortCoreML.MLShapedArray(scalars: [1, 2, 3, 4, 5, 6], shape: [2, 3])
    let row = block.slice(0..<2, along: 1)
    checkEqual("a sub-block's shape replaces the sliced dimension's extent", row.shape, [2, 2])
    checkEqual("a sub-block's values are the block's, in order", row.values, [1, 2, 4, 5])
    checkEqual("a sub-block's count", row.count, 4)
    checkEqual("a sub-block along the other axis is a different block",
               block.slice(0..<2, along: 0).values, [1, 2, 3, 4, 5, 6])
    checkEqual("a sub-block along the other axis has that block's shape",
               block.slice(0..<2, along: 0).shape, [2, 3])
    let flatFirstRow = Array(matrix.scalars[0..<3])
    let leadingFirstRow = block[leadingRange: 0..<1]
    checkEqual("a whole leading-dimension slice is one-dimensional", leadingFirstRow.shape, [3])
    checkEqual("and is that row's values", leadingFirstRow.values, [1, 2, 3])
    let secondRow = block[leadingRange: 1..<2]
    checkEqual("the second row too", secondRow.values, [4, 5, 6])
    checkEqual("a block's rows", block.rows.map { $0.values }, [[1, 2, 3], [4, 5, 6]])
    checkEqual("the reused leading-dimension arithmetic: scalars per leading index",
               block.scalarsPerLeadingIndex, 3)
    checkEqual("and the flat offset of an index in it", block.scalarOffset(forLeadingIndex: 1), 3)
    let leadingRange = block.scalarRange(forLeadingRange: 1..<2)
    checkEqual("and the flat range a leading range covers", leadingRange.lowerBound, 3)
    checkEqual("up to", leadingRange.upperBound, 6)
    let zeroDimensional = PortCoreML.MLShapedArray(scalars: [9.0], shape: [])
    checkEqual("a zero-dimensional array's shape is empty", zeroDimensional.shape, [])
    checkEqual("and it holds one scalar", zeroDimensional.count, 1)
    checkEqual("and spans no leading index", zeroDimensional.scalarsPerLeadingIndex, 0)
    checkEqual("a one-dimensional array spans one scalar per index", feature([1, 2, 3]).scalarsPerLeadingIndex, 1)
    checkEqual("a whole extent is the identity", block.slice(0..<3, along: 1).scalars, [1, 2, 3, 4, 5, 6])
    let asArray = row.array
    checkEqual("a sub-block reshaped as an array keeps its values", asArray.scalars, [1, 2, 4, 5])
    checkEqual("a sub-block reshaped as an array keeps its shape", asArray.shape, [2, 2])
    let cube = PortCoreML.MLShapedArray(scalars: (0..<24).map { Double($0) }, shape: [2, 3, 4])
    let plane = cube.slice(0..<2, along: 2)
    checkEqual("a plane's shape keeps the sliced dimension's new extent", plane.shape, [2, 3, 2])
    checkEqual("a plane's values are the block's, in the array's order", plane.values,
               [0, 1, 4, 5, 8, 9, 12, 13, 16, 17, 20, 21])
    checkEqual("a plane reshaped as an array keeps its count", plane.array.scalars.count, 12)
    checkEqual("a plane reshaped as an array keeps its shape", plane.array.shape, [2, 3, 2])
    checkEqual("a range of a shaped array's rows", matrix[slice: 0..<2].count, 2)
    checkEqual("a shaped array of a constant", feature([0, 0, 0]).scalars, [0, 0, 0])
    checkEqual("the strides of a one-row shape",
              PortCoreML.MLShapedArray<Double>.strides(for: [4]), [1])
    checkEqual("the count of a shape", PortCoreML.MLShapedArray<Double>.count(of: [2, 3, 4]), 24)
} catch {
    print("FAIL the linear-model comparison threw: \(error)")
    failures += 1
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
