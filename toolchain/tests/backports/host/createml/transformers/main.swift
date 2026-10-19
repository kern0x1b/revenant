import Foundation
import PortCreateMLComponents

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
        print("FAIL \(what): the port answers \(a), the arithmetic says \(b), a difference of \(difference)")
    }
}

func checkEqual<T: Equatable>(_ what: String, _ a: T, _ b: T) {
    check(what, a == b, "the port answers \(a)")
}

func table(_ numeric: [(String, [Double?])], textual: [(String, [String])] = []) -> ColumnarTable {
    var built = ColumnarTable()
    for (name, values) in numeric { built.set(.doubles(values), named: name) }
    for (name, values) in textual { built.set(.strings(values.map { Optional($0) }), named: name) }
    return built
}

func column(_ table: ColumnarTable, _ name: String) -> [Double?] {
    table.column(name)?.numeric ?? []
}

do {
    let numbers = table([("x", [1, 2, 3, 4]), ("y", [10, 20, 30, 40])])

    let standard = try StandardScaler().fitted(on: numbers)
    let standardX = column(standard.transformed(numbers), "x")
    let spread = (5.0 / 3.0).squareRoot()
    checkClose("a standard scaler puts the mean at zero",
               (standardX[0]! + standardX[1]! + standardX[2]! + standardX[3]!) / 4, 0, 1e-12)
    checkClose("a standard scaler divides by the unbiased standard deviation",
               (standardX[3]! - standardX[0]!) / 3, 1 / spread, 1e-12)

    let minmax = try MinMaxScaler().fitted(on: numbers)
    let minmaxX = column(minmax.transformed(numbers), "x")
    checkClose("a min-max scaler puts the smallest value at the range's start", minmaxX[0]!, 0, 1e-12)
    checkClose("a min-max scaler puts the largest value at the range's end", minmaxX[3]!, 1, 1e-12)
    checkClose("a min-max scaler is linear in between", minmaxX[1]!, 1.0 / 3.0, 1e-12)
    let narrowed = try MinMaxScaler(range: -1...1).fitted(keepingRangeOn: numbers)
    let narrowedX = column(narrowed.transformed(numbers), "x")
    checkClose("a min-max scaler into another range", narrowedX[0]!, -1, 1e-12)
    checkClose("a min-max scaler into another range, at the end", narrowedX[3]!, 1, 1e-12)

    let maxabs = try MaxAbsScaler().fitted(on: numbers)
    let maxabsY = column(maxabs.transformed(numbers), "y")
    checkClose("a max-abs scaler divides by the largest magnitude", maxabsY[3]!, 1, 1e-12)
    checkClose("a max-abs scaler keeps the sign", maxabsY[0]!, 0.25, 1e-12)

    let skewed = table([("x", [1, 2, 3, 4, 100])])
    let robust = try RobustScaler().fitted(on: skewed)
    let robustX = column(robust.transformed(skewed), "x")
    let standardSkewed = try StandardScaler().fitted(on: skewed)
    let standardSkewedX = column(standardSkewed.transformed(skewed), "x")
    checkClose("a robust scaler centres on the median", robustX[2]!, 0, 1e-12)
    let robustSpread = abs(robustX[1]! - robustX[0]!)
    let standardSpread = abs(standardSkewedX[1]! - standardSkewedX[0]!)
    check("a robust scaler keeps the ordinary values apart where a standard one does not",
          robustSpread > 2 * standardSpread,
          "the robust spread is " + String(robustSpread) + " and the standard one is "
          + String(standardSpread))
    checkEqual("the median of an even count is the mean of the two middle values",
               RobustScaler.median([1, 2, 3, 4]), 2.5)
    checkEqual("the median of an odd count is the middle value", RobustScaler.median([3, 1, 2]), 2)

    let constant = table([("x", [7, 7, 7, 7]), ("y", [1, 2, 3, 4])])
    let constantStandard = column(try StandardScaler().fitted(on: constant).transformed(constant), "x")
    checkEqual("a constant column is centred on zero, not divided by a zero",
               constantStandard, [0, 0, 0, 0])

    func fitRobust(_ values: [Double], _ range: ClosedRange<Double> = 0.25...0.75) -> RobustScaler {
        let single = table([("x", values)])
        return try! RobustScaler(quantileRange: range).fitted(on: single)
    }
    func scaled(_ scaler: RobustScaler, _ values: [Double]) -> [Double?] {
        let single = table([("x", values)])
        return column(scaler.transformed(single), "x")
    }
    let hostScaleWidths: [(ClosedRange<Double>, Double)] = [(0.25...0.75, 0.5), (0.1...0.9, 0.8),
                                                            (0.0...1.0, 1.0), (0.0...0.25, 0.25),
                                                            (0.4...0.6, 0.2)]
    for (range, hostWidth) in hostScaleWidths {
        checkClose("the host's scale for quantileRange \(range) is its width, \(hostWidth)",
                   fitRobust([1, 2, 3, 4, 100], range).statistics[0, 1], hostWidth, 1e-12)
    }
    checkClose("a constant column's scale is the width too, where a statistic would be 0",
               fitRobust([7, 7, 7, 7]).statistics[0, 1], 0.5, 1e-12)

    checkClose("the host's median for [1, 2, 3, 4, 100] is 3.0",
               fitRobust([1, 2, 3, 4, 100]).statistics[0, 0], 3.0, 1e-12)
    checkClose("the host's median for [1, 2, 3, 4] is the mean of the middles, 2.5",
               fitRobust([1, 2, 3, 4]).statistics[0, 0], 2.5, 1e-12)
    checkClose("the host's median for [1.5, 2.5, 3.5, 4.5] is 3.0",
               fitRobust([1.5, 2.5, 3.5, 4.5]).statistics[0, 0], 3.0, 1e-12)
    var skewedHost: [Double] = []
    for i in 0..<200 { skewedHost.append(Double(i) * 0.37 + 1.0) }
    skewedHost[199] = 10_000.5
    checkClose("the host's median for 200 skewed non-integers is 37.815",
               fitRobust(skewedHost).statistics[0, 0], 37.815, 1e-9)

    let hostFive = [1.0, 2.0, 3.0, 4.0, 100.0]
    let appliedFive = scaled(fitRobust(hostFive), hostFive)
    check("the host's applied column for [1, 2, 3, 4, 100] at 0.25...0.75 is the host's own [-4, -2, 0, 2, 194]",
          appliedFive.count == 5 && zip(appliedFive, [-4.0, -2.0, 0.0, 2.0, 194.0]).allSatisfy { $0 == $1 },
          "the port answers \(appliedFive)")
    let appliedNarrow = scaled(fitRobust([1, 2, 3, 4, 100], 0.1...0.9), hostFive)
    check("the host's applied(100) at quantileRange 0.1...0.9 is 121.25, not 194",
          appliedNarrow[4] == 121.25, "the port answers \(String(describing: appliedNarrow[4]))")
    let appliedZeroWidth = scaled(fitRobust([1, 2, 3, 4, 100], 0.5...0.5), hostFive)
    check("a zero width leaves the deviation unscaled: the host's applied(4) is 1.0",
          appliedZeroWidth[3] == 1.0, "the port answers \(String(describing: appliedZeroWidth[3]))")

    let appliedNaN = scaled(fitRobust([1, 2, Double.nan, 4]), [1.0, 9.0])
    check("a non-finite median is not subtracted: the host's applied(1) is 1 / 0.5 = 2",
          appliedNaN[0] == 2.0, "the port answers \(String(describing: appliedNaN[0]))")
    check("and applied(9) is 9 / 0.5 = 18, not NaN",
          appliedNaN[1] == 18.0, "the port answers \(String(describing: appliedNaN[1]))")
    let appliedInfiniteScale = scaled(fitRobust([1, 2, 3], 0.0...Double.infinity), [1.0, 3.0])
    check("an infinite scale leaves the deviation unscaled: the host's applied(3) is 3 - 2 = 1",
          appliedInfiniteScale[1] == 1.0, "the port answers \(String(describing: appliedInfiniteScale[1]))")
    let constantMinmax = column(try MinMaxScaler().fitted(on: constant).transformed(constant), "x")
    check("a constant column has no spread for a min-max scaler to divide by",
          constantMinmax == [0, 0, 0, 0] || constantMinmax == [7, 7, 7, 7],
          "the port answers \(constantMinmax)")
    let constantMaxabs = column(try MaxAbsScaler().fitted(on: constant).transformed(constant), "x")
    checkEqual("a constant column is scaled to the unit magnitude by the max-abs scaler",
               constantMaxabs, [1, 1, 1, 1])

    let categories = table([("x", [1.0, 2.0, 3.0, 4.0])],
                          textual: [("city", ["berlin", "paris", "berlin", "madrid"])])
    let oneHot = try OneHotEncoder().fitted(on: categories)
    checkEqual("a one-hot encoder's categories, in the order the fit found them",
               oneHot.categories(of: "city"), ["berlin", "paris", "madrid"])
    let hot = oneHot.transformed(categories)
    checkEqual("a one-hot encoder makes one column per category", hot.columnNames, ["x", "city_berlin", "city_paris", "city_madrid"])
    checkEqual("a one-hot encoder sets the column of its own category",
               column(hot, "city_berlin"), [1, 0, 1, 0])
    checkEqual("a one-hot encoder leaves the others at zero",
               column(hot, "city_madrid"), [0, 0, 0, 1])
    let unseen = table([("x", [1.0, 2.0, 3.0, 4.0])],
                       textual: [("city", ["berlin", "paris", "berlin", "lyon"])])
    let unseenHot = oneHot.transformed(unseen)
    checkEqual("a category the fit never saw is an all-zero row, not a new column",
               column(unseenHot, "city_berlin"), [1, 0, 1, 0])
    checkEqual("and no column is added for it", unseenHot.columnNames.count, hot.columnNames.count)

    let ordinal = try OrdinalEncoder().fitted(on: categories)
    checkEqual("an ordinal encoder's order, as the fit found it",
               ordinal.order(of: "city"), ["berlin", "paris", "madrid"])
    let ranked = column(ordinal.transformed(categories), "city")
    checkEqual("an ordinal encoder writes the rank", ranked, [0, 1, 0, 2])
    let unseenRanked = column(ordinal.transformed(unseen), "city")
    checkEqual("an unseen category is missing, not the first rank",
               unseenRanked, [0, 1, 0, nil])
    check("and the missing one is missing, not a zero",
          unseenRanked[3] == nil, "the port answers \(String(describing: unseenRanked[3]))")

    let holed = table([("x", [1, nil, 3, 4])])
    let imputer = try NumericImputer().fitted(on: holed)
    checkClose("an imputer fills with the mean of the values that are there",
               imputer.value(of: "x")!, (1 + 3 + 4) / 3, 1e-12)
    checkEqual("an imputer fills the gap and leaves the values that were there",
               column(imputer.transformed(holed), "x"), [1, (1 + 3 + 4) / 3, 3, 4])
    let nothing = table([("x", [nil, nil, nil])])
    let nothingImputer = try NumericImputer().fitted(on: nothing)
    checkEqual("a column with nothing in it is named as such", nothingImputer.imputedEverything, ["x"])
    checkEqual("and is filled with zero", column(nothingImputer.transformed(nothing), "x"), [0, 0, 0])
    checkClose("a gap is not counted as a zero in the mean", imputer.value(of: "x")!, 8.0 / 3.0, 1e-12)

    let linear = try LinearTransformer().fitted(on: numbers)
    let linearX = column(linear.transformed(numbers), "x")
    check("a linear transformer standardises what the standard scaler standardises",
          abs((linearX[0]! - standardX[0]!)) < 1e-12,
          "the linear one answers \\(linearX[0]!), the standard one \\(standardX[0]!)")
    checkClose("and its scale is the inverse of the spread", linear.scale(of: "x")!, 1 / spread, 1e-12)
    checkClose("and its offset is the negative mean over the spread",
               linear.offset(of: "x")!, -2.5 / spread, 1e-12)
    let linearHoled = column(try LinearTransformer().fitted(on: holed).transformed(holed), "x")
    check("a linear transformer leaves a missing value missing", linearHoled[1] == nil,
          "the port answers \(String(describing: linearHoled[1]))")
} catch {
    print("FAIL the transformer comparison threw: \(error)")
    failures += 1
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
