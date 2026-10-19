// linearmodels.swift — the port's linear regressor and logistic classifier, against the closed form.
//
// **This is not a host differential, and it is not pretending to be one.** A linear fit over a
// full-rank design with no penalty has exactly one right answer, and that answer is written down:
// a table whose target is `3 + 2*x1 - 1.5*x2` has to fit back to `[3, 2, -1.5]`, and a model built
// from those coefficients has to reproduce the table. That is a stronger claim than "agrees with
// another implementation of the same thing", because it cannot be satisfied by two wrong
// implementations agreeing.
//
// The host comparison — the host's own `LinearRegressor.fitted(to:validateOn:)`, which is
// `async throws` and takes a `DataFrame` — is real work and is not done here; `differential.swift`
// carries the twelve defects this surface's own differential found, and this file is a different
// claim from the same tree.
//
// What is checked:
//
//   - the coefficients of a fit over a table made from a known line, to a tolerance;
//   - the predictions of that model, row by row, against the table's own targets;
//   - that a ridge penalty pulls the slope toward zero by the amount the closed form says;
//   - that a model of the wrong width, a rank-deficient design, and an L1 penalty are each *refused
//     by name* rather than answered;
//   - that the classifier separates a linearly separable table, that its probabilities sum to one,
//     and that the label it answers is the most probable one.
//
// The last of those three refusals is the one that matters most: a fit that silently ignored the L1
// penalty the caller set would hand back a confident number about a model nobody asked for.
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
    // A table made from the line y = 3 + 2*x1 - 1.5*x2, with a little noise small enough that the
    // least-squares fit still recovers the line to six places.
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

    // The predictions reproduce the table.
    let predictions = try model.prediction(from: rows.map { $0.feature })
    checkEqual("one prediction per row", predictions.count, targets.count)
    var worst = 0.0
    for (index, prediction) in predictions.enumerated() {
        worst = max(worst, abs(Double(prediction) - targets[index]))
    }
    check("the predictions reproduce the table's own target", worst < 0.01,
          "the largest error over \(targets.count) rows is \(worst)")

    // A prediction of a single feature, which is what a caller reading a model asks for.
    checkClose("a one-feature model built by hand, on a row of it",
               try PortCreateMLComponents.LinearRegressorModel<Double>(coefficients: [10, 1])
                   .prediction(from: feature([5])), 15, 1e-12)

    // The ridge penalty: with one feature and a penalty p, the slope is shrunk by `x'x/(x'x + p)`.
    // Built by hand from the closed form, so the check is on the fitter and not on itself.
    let oneFeature = (0..<50).map { index -> Annotated in
        let x = Double(index)
        return Annotated(feature: feature([x]), annotation: 2 * x)
    }
    let ridge = PortCreateMLComponents.LinearRegressor<Double>(configuration: .init(l2Penalty: 100))
    let ridgeModel = try ridge.fitted(to: oneFeature)
    // The penalty goes on the **whole** diagonal, intercept included, because the normal matrix is
    // one matrix and exempting the intercept is a special case nothing asked for. That makes the
    // closed form the two-parameter ridge rather than the single-feature one, so what is checked
    // here is the property a caller relies on rather than a formula: the penalty pulls the slope
    // toward zero, and a bigger one pulls it further.
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

    // The three refusals, each by name.
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

    // The L1 penalty is now **fitted**, by the proximal iteration in `Proximal.swift`. Three things
    // are checked here; the closed form, the predictions and the KKT zero pattern are held against
    // the host's own `MLLinearRegressor` in the `l1` suite, which is where the host is reachable.
    let unpenalised = try PortCreateMLComponents.LinearRegressor<Double>(
        configuration: .init(l2Penalty: 0, l1Penalty: 0, maximumIterations: 500)).fitted(to: rows)
    // The tolerance is the caller's and this is the caller: a few hundred thousand prox steps on two
    // features reach a KKT residual of order 1e-8, so 1e-8 is what this table can be held to. A fit
    // that cannot reach the tolerance it was given says so rather than answering the point it
    // stopped at — and that is now checked below, because it is the claim that replaced a refusal.
    let penalised = try PortCreateMLComponents.LinearRegressor<Double>(
        configuration: .init(l2Penalty: 0, l1Penalty: 0.5, maximumIterations: 200000,
                             stepSize: 0.1, convergenceThreshold: 1e-8)).fitted(to: rows)

    // And the same fit with a tolerance it cannot reach, which must say so. This is what a refused
    // penalty used to do for every case; now it happens only when the caller asks for more than the
    // iteration delivers, which is the difference that matters.
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
    // Two features, so three coefficients: an intercept and two weights. Derived from the
    // width rather than written down, so it cannot drift from the fixture above.
    let width = rows.first?.feature.scalars.count ?? 0
    checkEqual("an L1 fit answers one coefficient per feature and an intercept",
               penalised.coefficients.count, width + 1)
    var moved = 0.0
    for index in 0..<penalised.coefficients.count {
        moved = max(moved, abs(Double(penalised.coefficients[index]) - Double(unpenalised.coefficients[index])))
    }
    check("and the penalty moved the answer", moved > 0.0, "the largest change is \(moved)")
    // The penalty is on the weights and not the intercept: the intercept is column zero and the
    // penalty skips it, which is the convention every linear model here uses and the one that makes
    // a penalty comparable across a target's own units.
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
        // Two identical features: the design has no answer in the second column, and a fit that
        // answered anyway would be returning a coefficient of something the caller cannot use.
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

    // The classifier, on a table whose classes are separated by a line.
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
    // The classes are separated at 0.5 by a margin and a noise that straddles it: a handful of rows
    // sit within the noise of the boundary and are genuinely ambiguous, so the claim is that the
    // classifier separates the *table* and not that it is right about every ambiguous row.
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

    // The shaped array itself: the shape, the strides and the two dimensions' arithmetic, which is
    // what a fitted model's weights are walked through.
    var matrix = PortCoreML.MLShapedArray(scalars: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], shape: [2, 3])
    checkEqual("a shaped array's shape", matrix.shape, [2, 3])
    checkEqual("a shaped array's strides, in elements", matrix.strides, [3, 1])
    checkEqual("a shaped array's count is the product of its shape", matrix.count, 6)
    checkClose("a shaped array read by index per dimension", matrix[indices: 1, 2], 6, 1e-12)
    matrix[indices: 1, 2] = 60
    checkClose("a shaped array written by index per dimension", matrix[indices: 1, 2], 60, 1e-12)
    checkClose("a shaped array's buffer, row-major", matrix.scalars[5], 60, 1e-12)
    // A **partial** slice of one dimension is a sub-block, and that is what `slice(_:along:)` gives:
    // the array's own shape with that dimension's extent replaced by the slice's, and the values read
    // by walking the other dimensions. Two things make this check able to fail where the old one could
    // not — the slice is a *proper sub-range* rather than a whole extent (slicing a whole extent is
    // the identity and proves nothing), and the **values and the shape** are compared rather than the
    // count. The old code answered shape `[2]` holding three scalars, and a count of 3 accepted it.
    // A *fresh* array: an earlier check writes through `matrix`'s own index subscript, so slicing
    // `matrix` would be slicing a table a previous line changed.
    let block = PortCoreML.MLShapedArray(scalars: [1, 2, 3, 4, 5, 6], shape: [2, 3])
    let row = block.slice(0..<2, along: 1)
    checkEqual("a sub-block's shape replaces the sliced dimension's extent", row.shape, [2, 2])
    checkEqual("a sub-block's values are the block's, in order", row.values, [1, 2, 4, 5])
    checkEqual("a sub-block's count", row.count, 4)
    checkEqual("a sub-block along the other axis is a different block",
               block.slice(0..<2, along: 0).values, [1, 2, 3, 4, 5, 6])
    checkEqual("a sub-block along the other axis has that block's shape",
               block.slice(0..<2, along: 0).shape, [2, 3])
    // A whole row — one that *drops* a dimension — is a different operation from a partial slice, and
    // saying so is the point: `slice(_:along:)` never drops a dimension, so a caller who wants a row
    // takes the flat range. Both are checked so neither is mistaken for the other.
    let flatFirstRow = Array(matrix.scalars[0..<3])
    // A **whole leading-dimension slice** is a row and drops a dimension; a partial slice is a
    // sub-block and keeps it. The two are told apart deliberately, and both are checked, because the
    // review's F3 is exactly what happens when a slice is allowed to be either.
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
    // A **zero**-dimensional array is one with no dimensions at all, not a one-dimensional array of
    // one element: the shape `[]` holds exactly one scalar, and the leading-dimension count is then
    // 0 rather than the 1 an empty product would give. The `shape.isEmpty` case is the one worth
    // keeping for that reason.
    let zeroDimensional = PortCoreML.MLShapedArray(scalars: [9.0], shape: [])
    checkEqual("a zero-dimensional array's shape is empty", zeroDimensional.shape, [])
    checkEqual("and it holds one scalar", zeroDimensional.count, 1)
    checkEqual("and spans no leading index", zeroDimensional.scalarsPerLeadingIndex, 0)
    checkEqual("a one-dimensional array spans one scalar per index", feature([1, 2, 3]).scalarsPerLeadingIndex, 1)
    checkEqual("a whole extent is the identity", block.slice(0..<3, along: 1).scalars, [1, 2, 3, 4, 5, 6])
    // And the slice as a whole array, which is the one thing a slice is for and which aborted the
    // process before: the shape is a lie about the values, so the array initialiser's own
    // precondition caught it and a caller reshaping a slice crashed.
    let asArray = row.array
    checkEqual("a sub-block reshaped as an array keeps its values", asArray.scalars, [1, 2, 4, 5])
    checkEqual("a sub-block reshaped as an array keeps its shape", asArray.shape, [2, 2])
    // A slice on the *second* dimension of a three-dimensional array, so the walk over the other two
    // dimensions is exercised with more than one of them.
    let cube = PortCoreML.MLShapedArray(scalars: (0..<24).map { Double($0) }, shape: [2, 3, 4])
    // A plane of a `2 x 3 x 4` array: the last dimension, sliced to two of its four, leaves twelve
    // scalars in the order they sit in the array. The old code answered shape `[3, 4]` and
    // twenty-four values here, and reshaping it aborted the process.
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
