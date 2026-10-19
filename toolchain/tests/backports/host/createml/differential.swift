import Foundation
import PortCreateML
import PortCreateMLComponents
import CreateML

var checks = 0
var failures = 0

struct Read {
    var columnNames: [String] = []
    var kinds: [String: String] = [:]
    var integers: [String: [Int]] = [:]
    var doubles: [String: [Double]] = [:]
    var strings: [String: [String]] = [:]
}

extension Read {
    init(port table: PortCreateML.MLDataTable) {
        columnNames = table.columnNames
        for name in columnNames {
            let type = table.columnTypes[name]?.description ?? "none"
            kinds[name] = type
            if let column = table[name]?.ints { integers[name] = column.values.map { $0 } }
            if let column = table[name]?.doubles { doubles[name] = column.values.map { $0 } }
            if let column = table[name]?.strings { strings[name] = column.values.map { $0 } }
        }
    }

    init(host table: CreateML.MLDataTable) {
        columnNames = Array(table.columnNames)
        for name in columnNames {
            kinds[name] = table.columnTypes[name]?.description ?? "none"
            integers[name] = hostIntegers(table, name)
            doubles[name] = hostDoubles(table, name)
            strings[name] = hostStrings(table, name)
        }
    }
}

private let missing = "\u{0}missing"

func portDoubles(_ table: PortCreateML.MLDataTable, _ name: String) -> [Double] {
    guard let column = table[name]?.doubles else { return [] }
    var out = [Double]()
    for index in 0..<column.count { out.append(column[index] ?? .nan) }
    return out
}

func hostDoubles(_ table: CreateML.MLDataTable, _ name: String) -> [Double] {
    guard let column = table[name].doubles else { return [] }
    var out = [Double]()
    for index in 0..<column.count { out.append(column[index] ?? .nan) }
    return out
}

func portIntegers(_ table: PortCreateML.MLDataTable, _ name: String) -> [Int] {
    guard let column = table[name]?.ints else { return [] }
    var out = [Int]()
    for index in 0..<column.count { out.append(column[index] ?? Int.min) }
    return out
}

func hostIntegers(_ table: CreateML.MLDataTable, _ name: String) -> [Int] {
    guard let column = table[name].ints else { return [] }
    var out = [Int]()
    for index in 0..<column.count { out.append(column[index] ?? Int.min) }
    return out
}

func portStrings(_ table: PortCreateML.MLDataTable, _ name: String) -> [String] {
    guard let column = table[name]?.strings else { return [] }
    var out = [String]()
    for index in 0..<column.count { out.append(column[index] ?? missing) }
    return out
}

func hostStrings(_ table: CreateML.MLDataTable, _ name: String) -> [String] {
    guard let column = table[name].strings else { return [] }
    var out = [String]()
    for index in 0..<column.count { out.append(column[index] ?? missing) }
    return out
}

struct Summary { var value: Double; var valid: Bool }

func portSummary(_ table: PortCreateML.MLDataTable, _ name: String,
                 _ read: (PortCreateML.MLDataColumn<Double>) -> Double?) -> Summary {
    guard let column = table[name]?.doubles else { return Summary(value: .nan, valid: false) }
    guard let value = read(column) else { return Summary(value: .nan, valid: false) }
    return Summary(value: value, valid: true)
}

func hostSummary(_ table: CreateML.MLDataTable, _ name: String,
                 _ read: (CreateML.MLDataColumn<Double>) -> Double?) -> Summary {
    guard let column = table[name].doubles else { return Summary(value: .nan, valid: false) }
    let value = read(column)
    return Summary(value: value ?? .nan, valid: value != nil)
}

func portJoinedDoubles(_ table: PortCreateML.MLDataTable, _ name: String) -> [Double] {
    portDoubles(table, name)
}

func hostJoinedDoubles(_ table: CreateML.MLDataTable, _ name: String) -> [Double] {
    hostDoubles(table, name)
}

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

let csv = """
id,city,size,rooms,price
1,berlin,10.5,2,100.0
2,paris,12.0,3,140.0
3,berlin,9.5,2,95.0
4,paris,13.5,4,175.0
5,berlin,11.0,3,130.0
6,madrid,10.0,2,110.0
7,madrid,14.0,4,190.0
8,paris,9.0,1,80.0
"""

let csvURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("createml-differential-\(getpid()).csv")
try? csv.write(to: csvURL, atomically: true, encoding: .utf8)

do {
    let port = try PortCreateML.MLDataTable(contentsOf: csvURL)
    let host = try CreateML.MLDataTable(contentsOf: csvURL)

    checkEqual("the table's row count", port.size.rows, host.size.rows)
    checkEqual("the table's column count", port.size.columns, host.size.columns)

    let sequence = PortCreateML.MLDataValue.sequence([.int(1), .string("two"), .double(3)])
    check("a sequence value's debugDescription is a string",
          String(reflecting: sequence).contains("Sequence") && String(reflecting: sequence).contains("two"),
          "the port answers \(String(reflecting: sequence))")
    check("a sequence value's debugDescription is not its own getter",
          !sequence.debugDescription.contains("debugDescription"),
          "the port answers \(sequence.debugDescription)")
    let dictionary = PortCreateML.MLDataValue.dictionary(["k": .int(7)])
    check("a dictionary value's debugDescription is a string too",
          String(reflecting: dictionary).contains("k: 7"),
          "the port answers \(String(reflecting: dictionary))")
    let multi = PortCreateML.MLDataValue.multiArray(.init([1, 2, 3], shape: [3]))
    check("a multi-array value's debugDescription is a string too",
          String(reflecting: multi).contains("MultiArray"),
          "the port answers \(String(reflecting: multi))")

    let portRead = Read(port: port), hostRead = Read(host: host)
    for name in host.columnNames {
        check("the type of the column \(name)", portRead.kinds[name] == hostRead.kinds[name],
              "the port answers \(portRead.kinds[name] ?? "none"), the host \(hostRead.kinds[name] ?? "none")")
    }

    checkEqual("the ids read as a column of Int", portIntegers(port, "id"), hostIntegers(host, "id"))
    checkEqual("the sizes read as a column of Double", portDoubles(port, "size"), hostDoubles(host, "size"))
    checkEqual("the cities read as strings", portStrings(port, "city"), hostStrings(host, "city"))
    checkEqual("every price, read", portDoubles(port, "price"), hostDoubles(host, "price"))

    check("the sum of the prices is computable on both sides",
          portSummary(port, "price", { $0.sum() }).valid && hostSummary(host, "price", { $0.sum() }).valid)
    checkClose("the sum of the prices", portSummary(port, "price", { $0.sum() }).value,
               hostSummary(host, "price", { $0.sum() }).value, 1e-9)
    checkClose("the mean of the prices", portSummary(port, "price", { $0.mean() }).value,
               hostSummary(host, "price", { $0.mean() }).value, 1e-9)
    checkClose("the stdev of the prices", portSummary(port, "price", { $0.stdev() }).value,
               hostSummary(host, "price", { $0.stdev() }).value, 1e-9)
    checkClose("the min of the prices", portDoubles(port, "price").min() ?? .nan,
               hostDoubles(host, "price").min() ?? .nan, 1e-9)
    checkClose("the max of the prices", portDoubles(port, "price").max() ?? .nan,
               hostDoubles(host, "price").max() ?? .nan, 1e-9)

    checkEqual("the prices in increasing order",
               portDoubles(port.sort(columnNamed: "price"), "price"),
               hostDoubles(host.sort(columnNamed: "price"), "price"))
    checkEqual("the rooms in decreasing order",
               portIntegers(port.sort(columnNamed: "rooms", byIncreasingOrder: false), "rooms"),
               hostIntegers(host.sort(columnNamed: "rooms", byIncreasingOrder: false), "rooms"))

    checkEqual("the number of distinct cities",
               portStrings(port, "city").reduce(into: [String]()) { seen, city in
                   if !seen.contains(city) { seen.append(city) }
               }.count,
               hostStrings(host, "city").reduce(into: [String]()) { seen, city in
                   if !seen.contains(city) { seen.append(city) }
               }.count)
    checkEqual("the number of rows with nothing missing", port.dropMissing().size.rows, host.dropMissing().size.rows)
    checkEqual("the number of distinct rows", port.dropDuplicates().size.rows, host.dropDuplicates().size.rows)

    let otherCSV = "id,region\n1,north\n4,south\n7,north\n"
    let otherURL = csvURL.deletingLastPathComponent().appendingPathComponent("createml-other-\(getpid()).csv")
    try? otherCSV.write(to: otherURL, atomically: true, encoding: .utf8)
    let portOther = try PortCreateML.MLDataTable(contentsOf: otherURL)
    let hostOther = try CreateML.MLDataTable(contentsOf: otherURL)

    for kind in [PortCreateML.JoinType.inner, .left, .right, .outer] {
        let hostKind: CreateML.MLDataTable.JoinType
        switch kind {
        case .inner: hostKind = .inner
        case .left: hostKind = .left
        case .right: hostKind = .right
        case .outer: hostKind = .outer
        }
        let portJoin = try port.join(with: portOther, on: "id", type: kind)
        let hostJoin = try host.join(with: hostOther, on: "id", type: hostKind)
        checkEqual("the row count of a \(kind.rawValue) join", portJoin.size.rows, hostJoin.size.rows)
        checkEqual("the id column of a \(kind.rawValue) join",
                   portIntegers(portJoin, "id"), hostIntegers(hostJoin, "id"))
        checkEqual("the region column of a \(kind.rawValue) join",
                   portStrings(portJoin, "region"), hostStrings(hostJoin, "region"))
    }

    let portGroup = try port.group(columnsNamed: ["city"], aggregators: [
        PortCreateML.MLDataTableAggregator(operations: .sum, of: "price"),
        PortCreateML.MLDataTableAggregator(operations: .mean, of: "price"),
        PortCreateML.MLDataTableAggregator(operations: .count, of: "id"),
    ])
    let hostGroup = try host.group(columnsNamed: "city", aggregators: [
        CreateML.MLDataTable.Aggregator(operations: .sum, of: "price"),
        CreateML.MLDataTable.Aggregator(operations: .mean, of: "price"),
        CreateML.MLDataTable.Aggregator(operations: .count, of: "id"),
    ])
    checkEqual("the number of groups by city", portGroup.size.rows, hostGroup.size.rows)
    let portCities = portStrings(portGroup, "city")
    let hostCities = hostStrings(hostGroup, "city")
    checkEqual("the group keys", portCities, hostCities)
    for column in ["priceSum", "priceMean", "Count"] {
        let mine = portDoubles(portGroup, column).filter { !$0.isNaN }
        let theirs = hostDoubles(hostGroup, column).filter { !$0.isNaN }
        checkEqual("the number of \(column) values by city", mine.count, theirs.count)
        for (a, b) in zip(mine, theirs) {
            checkClose("a \(column) by city", a, b, 1e-9)
        }
    }

    let portSplit = port.randomSplit(by: 0.75, seed: 42)
    let hostSplit = host.randomSplit(by: 0.75, seed: 42)
    check("a random split's halves are near the proportion",
          abs(Double(portSplit.0.size.rows) - 6.0) <= 2.0,
          "the port answers \(portSplit.0.size.rows) of 8 at three quarters")
    check("a random split's halves are near the proportion on the host too",
          abs(Double(hostSplit.0.size.rows) - 6.0) <= 2.0,
          "the host answers \(hostSplit.0.size.rows) of 8 at three quarters")
    checkEqual("a random split covers every row once",
               portSplit.0.size.rows + portSplit.1.size.rows, port.size.rows)
    check("a seeded split is the same split twice",
          port.randomSplit(by: 0.75, seed: 42).0.size.rows == portSplit.0.size.rows)
    var big = PortCreateML.MLDataTable()
    big.addColumn(PortCreateML.MLUntypedColumn((0..<2000).map { PortCreateML.MLDataValue.int(Int64($0)) },
                                               name: "id"), named: "id")
    let counts = [42, 7, 12345].map { seed -> Int in big.randomSplit(by: 0.5, seed: UInt64(seed)).0.size.rows }
    check("a per-row draw does not answer exactly n*p every time", Set(counts).count > 1,
          "the port answers \(counts) for three seeds at a half of two thousand")
    check("a per-row draw is near n*p", counts.allSatisfy { abs($0 - 1000) < 100 },
          "the port answers \(counts) for three seeds at a half of two thousand")

    let written = csvURL.deletingLastPathComponent().appendingPathComponent("createml-written-\(getpid()).csv")
    try port.writeCSV(to: written)
    let reread = try PortCreateML.MLDataTable(contentsOf: written)
    checkEqual("the prices of a written and re-read table",
               portDoubles(reread, "price"), portDoubles(port, "price"))

    let tricky = """
    # a comment line
    "name","note"
    "a","one, two"
    "b","a ""quoted"" word"
    "c",
    "d","four"
    """
    let trickyURL = csvURL.deletingLastPathComponent().appendingPathComponent("createml-tricky-\(getpid()).csv")
    try? tricky.write(to: trickyURL, atomically: true, encoding: .utf8)
    let portTricky = try PortCreateML.MLDataTable(contentsOf: trickyURL,
                                                 options: MLDataTableParsingOptionsAlias(comment: "#"))
    let hostTricky = try CreateML.MLDataTable(contentsOf: trickyURL,
                                             options: CreateML.MLDataTable.ParsingOptions(comment: "#"))
    checkEqual("the rows of a file with a comment and quotes", portTricky.size.rows, hostTricky.size.rows)
    let portNotes = portStrings(portTricky, "note")
    let hostNotes = hostStrings(hostTricky, "note")
    checkEqual("a quoted field holding the delimiter", portNotes.count > 1 ? portNotes[1] : "",
               hostNotes.count > 1 ? hostNotes[1] : "")
    checkEqual("a doubled quote inside a quoted field", portNotes.count > 2 ? portNotes[2] : "",
               hostNotes.count > 2 ? hostNotes[2] : "")
    checkEqual("an empty cell reads as the empty string", portNotes.count > 2 ? portNotes[2] : "\u{0}none",
               hostNotes.count > 2 ? hostNotes[2] : "\u{0}none")
    check("an empty cell is not a missing value",
          portTricky.dropMissing().size.rows == hostTricky.dropMissing().size.rows,
          "the port keeps \(portTricky.dropMissing().size.rows) rows, the host \(hostTricky.dropMissing().size.rows)")
    checkEqual("the rows of a file read with maxRows", try PortCreateML.MLDataTable(
        contentsOf: trickyURL,
        options: MLDataTableParsingOptionsAlias(comment: "#", maxRows: 2)).size.rows, 2)
} catch {
    print("FAIL the table comparison threw: \(error)")
    failures += 1
}

typealias MLDataTableParsingOptionsAlias = PortCreateML.MLDataTableParsingOptions

func stepTable(rows: Int, csv: inout String) {
    var generator = PortCreateMLComponents.SeededGenerator(seed: 7)
    csv = "x,junk,target\n"
    for index in 0..<rows {
        let x = Double(index) / Double(rows) + generator.nextGaussian(mean: 0, standardDeviation: 0.01)
        let junk = generator.nextUniform()
        csv += "\(x),\(junk),\(x > 0.5 ? 1000.0 : 0.0)\n"
    }
}

do {
    var text = ""
    stepTable(rows: 200, csv: &text)
    let url = csvURL.deletingLastPathComponent().appendingPathComponent("createml-step-\(getpid()).csv")
    try text.write(to: url, atomically: true, encoding: .utf8)

    let hostModel = try CreateML.MLDecisionTreeRegressor(
        trainingData: try CreateML.MLDataTable(contentsOf: url),
        targetColumn: "target",
        featureColumns: ["junk", "x"])
    var hostPredictionTable = CreateML.MLDataTable()
    hostPredictionTable.addColumn(try hostModel.predictions(from: try CreateML.MLDataTable(contentsOf: url)),
                                  named: "prediction")
    let hostPredictions = hostDoubles(hostPredictionTable, "prediction")

    let portModel = try PortCreateML.MLDecisionTreeRegressor(
        trainingData: try PortCreateML.MLDataTable(contentsOf: url),
        targetColumn: "target",
        featureColumns: ["junk", "x"])
    var portPredictionTable = PortCreateML.MLDataTable()
    portPredictionTable.addColumn(try portModel.predictions(from: try PortCreateML.MLDataTable(contentsOf: url)),
                                  named: "prediction")
    let portPredictions = portDoubles(portPredictionTable, "prediction")

    checkEqual("the number of predictions from a decision tree", portPredictions.count, hostPredictions.count)
    check("the port's decision tree finds the step",
          portModel.trainingMetrics.rootMeanSquaredError < 1.0 && portModel.trainingMetrics.isValid,
          "the port's own RMSE on a separable table is \(portModel.trainingMetrics.rootMeanSquaredError)")

    let portLow = portPredictions.prefix(80).map { $0 }
    let portHigh = portPredictions.suffix(80).map { $0 }
    check("the port predicts one value for the whole lower half",
          portLow.allSatisfy { $0 == portLow[0] }, "the port answers \(Set(portLow))")
    check("the port predicts one value for the whole upper half",
          portHigh.allSatisfy { $0 == portHigh[0] }, "the port answers \(Set(portHigh))")
    check("the port's two halves differ", (portHigh[0] - portLow[0]).magnitude > 100,
          "the port answers \(portLow[0]) and \(portHigh[0])")
    check("the host's error is its leaf regulariser, not a failure to fit",
          hostModel.trainingMetrics.rootMeanSquaredError < 10.0,
          "the host's RMSE is \(hostModel.trainingMetrics.rootMeanSquaredError)")

    var targets = [Double]()
    let targetColumn = try PortCreateML.MLDataTable(contentsOf: url)["target"]!.doubles!
    for index in 0..<targetColumn.count { targets.append(targetColumn[index]) }
    let recomputed = PortCreateML.MLRegressorMetrics(observations: targets, predictions: hostPredictions)
    checkClose("the RMSE of the host's predictions, computed by the port",
               recomputed.rootMeanSquaredError, hostModel.evaluation(on: try CreateML.MLDataTable(contentsOf: url)).rootMeanSquaredError, 1e-6)
    checkClose("the maximum error of the host's predictions, computed by the port",
               recomputed.maximumError, hostModel.evaluation(on: try CreateML.MLDataTable(contentsOf: url)).maximumError, 1e-6)
    check("the port's own metrics are valid on a table it can answer for", recomputed.isValid)

    let labelled = "x,target\n" + (0..<200).map { index -> String in
        let x = Double(index) / 200.0
        return "\(x),\(x > 0.5 ? "high" : "low")\n"
    }.joined()
    let labelledURL = csvURL.deletingLastPathComponent().appendingPathComponent("createml-labelled-\(getpid()).csv")
    try labelled.write(to: labelledURL, atomically: true, encoding: .utf8)

    let hostClassifier = try CreateML.MLDecisionTreeClassifier(
        trainingData: try CreateML.MLDataTable(contentsOf: labelledURL), targetColumn: "target",
        featureColumns: ["x"])
    let portClassifier = try PortCreateML.MLDecisionTreeClassifier(
        trainingData: try PortCreateML.MLDataTable(contentsOf: labelledURL), targetColumn: "target",
        featureColumns: ["x"])
    checkClose("the classification error of a decision-tree classifier",
               portClassifier.trainingMetrics.classificationError,
               hostClassifier.trainingMetrics.classificationError, 1e-9)
    check("a decision-tree classifier separates two classes",
          portClassifier.trainingMetrics.accuracy > 0.95 && portClassifier.trainingMetrics.isValid,
          "the port's accuracy is \(portClassifier.trainingMetrics.accuracy)")

    let portForestClassifier = try PortCreateML.MLRandomForestClassifier(
        trainingData: try PortCreateML.MLDataTable(contentsOf: labelledURL), targetColumn: "target",
        featureColumns: ["x"],
        parameters: PortCreateML.MLRandomForestClassifier.ModelParameters(maxIterations: 20, randomSeed: 7))
    checkClose("the classification error of a random-forest classifier",
               portForestClassifier.trainingMetrics.classificationError,
               hostClassifier.trainingMetrics.classificationError, 0.05)

    var refused = false
    do {
        try portModel.write(to: csvURL)
    } catch {
        refused = true
        check("the refusal is CreateML's own error", (error as? MLCreateErrorAlias) != nil,
              "the port answers \(error)")
    }
    check("write(to:) refuses on this build", refused)
} catch {
    print("FAIL the estimator comparison threw: \(error)")
    failures += 1
}

typealias MLCreateErrorAlias = PortCreateML.MLCreateError

do {
    let portA = PortCreateMLComponents.RowMatrix([2, 0, 0, 3], rows: 2, columns: 2)
    let portB = PortCreateMLComponents.RowMatrix([1, 2, 3, 4], rows: 2, columns: 2)
    let portProduct = portA.multiplied(by: portB)
    checkEqual("a 2x2 product, row 0", portProduct.contiguousRow(0), [2.0, 4.0])
    checkEqual("a 2x2 product, row 1", portProduct.contiguousRow(1), [9.0, 12.0])

    var system = PortCreateMLComponents.RowMatrix([3, 1, 1, 2], rows: 2, columns: 2)
    var right = [9.0, 8.0]
    checkEqual("a 2x2 LU solve reports no error",
               PortCreateMLComponents.RowMatrix.solve(&system, rightHandSides: &right), 0)
    checkClose("a 2x2 LU solve, x", right[0], 2, 1e-9)
    checkClose("a 2x2 LU solve, y", right[1], 3, 1e-9)

    var singular = PortCreateMLComponents.RowMatrix([1, 2, 2, 4], rows: 2, columns: 2)
    var ignored = [1.0, 1.0]
    let singularInfo = PortCreateMLComponents.RowMatrix.solve(&singular, rightHandSides: &ignored)
    check("a singular system is reported, not answered", singularInfo != 0,
          "LAPACK's own info came back as \(singularInfo)")

    var definite = PortCreateMLComponents.RowMatrix([2, 0, 0, 3], rows: 2, columns: 2)
    checkEqual("a Cholesky factor of a positive definite matrix reports no error",
               PortCreateMLComponents.RowMatrix.cholesky(&definite), 0)
    checkClose("a Cholesky factor's first diagonal", definite[0, 0], 2.0.squareRoot(), 1e-9)
    checkClose("a Cholesky factor's second diagonal", definite[1, 1], 3.0.squareRoot(), 1e-9)
    checkClose("a Cholesky factor leaves the upper triangle alone", definite[0, 1], 0, 1e-12)

    checkClose("a mean", PortCreateMLComponents.RowMatrix.mean([1, 2, 3, 4]), 2.5, 1e-12)
    checkClose("a variance", PortCreateMLComponents.RowMatrix.variance([1, 2, 3, 4]), 5.0 / 3.0, 1e-9)
    checkClose("a dot product", PortCreateMLComponents.RowMatrix.dot([1, 2, 3], [4, 5, 6]), 32, 1e-12)
    let probabilities = PortCreateMLComponents.RowMatrix.logistic([0.3, 1.2, -0.7])
    checkClose("a softmax sums to one", probabilities.reduce(0, +), 1, 1e-12)
    check("a softmax is ordered by its scores",
          probabilities[1] > probabilities[0] && probabilities[0] > probabilities[2],
          "the port answers \(probabilities)")

    let design = PortCreateMLComponents.RowMatrix([1, 1, 2, 1, 3, 1, 4, 1], rows: 4, columns: 2)
    let (solution, info) = PortCreateMLComponents.RowMatrix.ridgeLeastSquares(
        design: design, targets: [2, 4, 6, 8], penalty: 0)
    checkEqual("a two-column ridge fit reports no error", info, 0)
    checkClose("a two-column ridge fit's slope", solution.count > 0 ? solution[0] : 0, 2, 1e-9)
    checkClose("a two-column ridge fit's intercept", solution.count > 1 ? solution[1] : 1, 0, 1e-9)

    let (shrunk, shrunkInfo) = PortCreateMLComponents.RowMatrix.ridgeLeastSquares(
        design: design, targets: [2, 4, 6, 8], penalty: 30)
    checkEqual("a penalised ridge fit reports no error", shrunkInfo, 0)
    let normalXX = [[60.0, 10.0], [10.0, 34.0]]
    let normalXy = [60.0, 20.0]
    let determinant = normalXX[0][0] * normalXX[1][1] - normalXX[0][1] * normalXX[1][0]
    let expectedSlope = (normalXy[0] * normalXX[1][1] - normalXX[0][1] * normalXy[1]) / determinant
    let expectedIntercept = (normalXX[0][0] * normalXy[1] - normalXy[0] * normalXX[1][0]) / determinant
    checkClose("a penalised two-column ridge fit's slope", shrunk.count > 0 ? shrunk[0] : 0,
               expectedSlope, 1e-9)
    checkClose("a penalised two-column ridge fit's intercept", shrunk.count > 1 ? shrunk[1] : 0,
               expectedIntercept, 1e-9)

    let repeated = PortCreateMLComponents.RowMatrix([1, 1, 1, 1, 2, 2, 2, 2], rows: 4, columns: 2)
    let (refused, refusedInfo) = PortCreateMLComponents.RowMatrix.ridgeLeastSquares(
        design: repeated, targets: [1, 2, 3, 4], penalty: 0)
    check("a rank-deficient design is reported, not answered", refusedInfo != 0,
          "the fit reports \(refusedInfo) and answers \(refused)")

    var one = PortCreateMLComponents.SeededGenerator(seed: 12345)
    var two = PortCreateMLComponents.SeededGenerator(seed: 12345)
    var same = true
    for _ in 0..<1000 where one.next() != two.next() { same = false }
    check("two generators with one seed agree for a thousand draws", same)
    var three = PortCreateMLComponents.SeededGenerator(seed: 12346)
    var differs = false
    for _ in 0..<1000 where one.next() != three.next() { differs = true }
    check("two generators with different seeds differ", differs)
} catch {
    print("FAIL the kernel comparison threw: \(error)")
    failures += 1
}

try? FileManager.default.removeItem(at: csvURL)

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
