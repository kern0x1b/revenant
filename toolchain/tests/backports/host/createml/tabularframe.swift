import Foundation
setvbuf(stdout, nil, _IONBF, 0)
@testable import PortTabularData
import TabularData

func makeKeptSlice() -> PortTabularData.DiscontiguousColumnSlice<Int> {
    let base = PortTabularData.Column<Int>(name: "n", [5, 1, 4, 20, 3])
    return base.filter { (cell: Int?) -> Bool in
        guard let value = cell else { return false }
        return value > 3
    }
}
if CommandLine.arguments.contains("--slice-trap") {
    let base = PortTabularData.Column<Int>(name: "c", [1, 2, 3])
    let view = base[1..<3]
    print("PROBE reading view[0], which is outside 1..<3")
    let cell = view[0]
    print("PROBE reached the end - so view[0] did NOT trap, and the host traps on it: \(String(describing: cell))")
    exit(0)
}
if CommandLine.arguments.contains("--slice-inrange") {
    let base = PortTabularData.Column<Int>(name: "c", [1, 2, 3])
    let view = base[1..<3]
    print("PROBE startIndex=\(view.startIndex) endIndex=\(view.endIndex) count=\(view.count)")
    print("PROBE view[startIndex]=\(String(describing: view[view.startIndex]))")
    print("PROBE view[startIndex+1]=\(String(describing: view[view.startIndex + 1]))")
    exit(0)
}
if CommandLine.arguments.contains("--anycolumn-probe") {
    var pf = PortTabularData.DataFrame()
    pf.append(column: PortTabularData.Column<String>(name: "city", ["berlin", "paris", "madrid"]))
    pf.append(column: PortTabularData.Column<Int?>(name: "n", [1, nil, 3]))
    var pOrd = PortTabularData.DataFrame()
    pOrd.append(column: PortTabularData.Column<Int>(name: "a", contents: [1, nil, 3]))
    let pStrings = pf[dynamicMember: "city"]
    let pOptionals = pf[dynamicMember: "n"]
    let pOrdCol = pOrd[dynamicMember: "a"]
    print("1  count                       = \(pStrings.count)")
    print("2  name                        = \(pStrings.name)")
    print("3  wrappedElementType (present)= \(String(describing: pStrings.wrappedElementType))")
    let probeCity0 = pStrings[0]
    let probeCity2 = pStrings[2]
    let probeOpt0 = pOptionals[0]
    let probeOrd1 = pOrdCol[1]
    print("4  subscript(position: 0)      = \(String(describing: probeCity0))")
    print("5  subscript(position: 2)      = \(String(describing: probeCity2))")
    print("6  missingCount, no nils       = \(pStrings.missingCount)")
    print("7  missingCount, optional form = \(pOptionals.missingCount)")
    print("8  missingCount, ordinary form = \(pOrdCol.missingCount)")
    print("9  wrappedElementType (option) = \(String(describing: pOptionals.wrappedElementType))")
    print("10 subscript of the optional   = \(String(describing: probeOpt0))")
    print("11 the present form's own subscript as Any? = \(probeCity0 as Any? == nil)")
    print("12 the ordinary form's cell    = \(String(describing: probeOrd1))  nil?=\(probeOrd1 as Any? == nil)")
    let probePresent0 = pOrdCol[0]
    print("12-MISSING type=\(type(of: probeOrd1 as Any)) style=\(Mirror(reflecting: probeOrd1 as Any).displayStyle) nil?=\(probeOrd1 == nil)")
    print("12-PRESENT type=\(type(of: probePresent0 as Any)) style=\(Mirror(reflecting: probePresent0 as Any).displayStyle) nil?=\(probePresent0 == nil)")
    exit(0)
}
if CommandLine.arguments.contains("--slice-probe") {
    let kept = makeKeptSlice()
    print("PROBE indices=\(kept.indices) count=\(kept.count) startIndex=\(kept.startIndex) endIndex=\(kept.endIndex)")
    print("PROBE kept[0]=\(String(describing: kept[0]))")
    print("PROBE kept[3]=\(String(describing: kept[3]))")
    print("PROBE kept.values=\(kept.values)")
    print("PROBE Array(kept)=\(Array(kept).map { String(describing: $0) })")
    print("PROBE about to read kept[1], which the host refuses")
    print("PROBE kept[1]=\(String(describing: kept[1]))")
    print("PROBE reached the end - so kept[1] did NOT trap, which the host says it does")
    exit(0)
}
if CommandLine.arguments.contains("--slice-probe-before") {
    let kept = makeKeptSlice()
    print("PROBE about to ask index(before: startIndex), which the host refuses")
    print("PROBE index(before: startIndex)=\(String(describing: kept.index(before: kept.startIndex)))")
    print("PROBE reached the end - so it did NOT trap, and the host traps")
    exit(0)
}
if CommandLine.arguments.contains("--slice-probe-reversed") {
    let kept = makeKeptSlice()
    print("PROBE about to walk backwards with reversed()")
    print("PROBE reversed()=\(kept.reversed().map { String(describing: $0) })")
    print("PROBE reached the end - so it did NOT trap; a backward walk must not spin")
    exit(0)
}

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
    check(what, a == b, "a=\(a) b=\(b)")
}

func checkEqualAgainstHost<T: Equatable>(_ what: String, host: T, port: T) {
    check(what, host == port, "host=\(host) port=\(port)")
}

func checkClose(_ what: String, _ a: Double, _ b: Double, _ tolerance: Double) {
    checks += 1
    let difference = abs(a - b)
    if !(difference <= tolerance) {
        failures += 1
        print("FAIL \(what): the port answers \(a), the arithmetic says \(b), a difference of \(difference)")
    }
}

var frame = PortTabularData.DataFrame()
frame.append(column: PortTabularData.Column<Int>(name: "id", [1, 2, 3, 4, 5, 6]))
frame.append(column: PortTabularData.Column<String>(name: "city",
                                                      ["berlin", "paris", "berlin", "madrid", "paris", "berlin"]))
frame.append(column: PortTabularData.Column<Double>(name: "price", [100, 140, 95, 175, 130, 110]))

checkEqual("the shape's rows", frame.shape.rows, 6)
checkEqual("the shape's columns", frame.shape.columns, 3)
checkEqual("the row count", frame.count, 6)
checkEqual("the column names, in the order they were added", frame.columnNames, ["id", "city", "price"])
check("a frame whose columns agree on a height is valid", frame.isValid)
check("a frame is not empty", !frame.isEmpty)

let price = PortTabularData.ColumnID<Double>("price", Double.self)
let city = PortTabularData.ColumnID<String>("city", String.self)
checkEqual("a typed column by ColumnID", frame[price].values, [100, 140, 95, 175, 130, 110])
checkEqual("a typed column by name and type", frame["price", Double.self]?.values ?? [], [100, 140, 95, 175, 130, 110])
checkEqual("a category column by ColumnID", frame[city].values.count, 6)

check("a column read as the wrong type is nil", frame["city", Double.self] == nil)
check("containsColumn with the wrong type is false", !frame.containsColumn("city", Double.self))
check("containsColumn with its own type is true", frame.containsColumn("price", Double.self))

check("a column that is not there is nil", frame["nope"] == nil)
check("the position of a column that is not there is nil", frame.indexOfColumn("nope") == nil)
checkEqual("the dynamic member lookup of a column that is not there has no values", frame.nope.count, 0)
checkEqual("the dynamic member lookup of a column that is there is the column", frame.price.count, 6)
checkEqual("the position of a column by name", frame.indexOfColumn("city"), 1)

checkEqual("a row's count", frame.rowSequence.count, 6)
let hostOrd = TabularData.Column<Int>(name: "a", contents: [1, nil, 3])
let portOrd = PortTabularData.Column<Int>(name: "a", contents: [1, nil, 3])
let hostCell: Any? = hostOrd[1]
let portCell: Any? = portOrd[1]
check("a missing cell is nil as an Any?, as the host answers", hostCell == nil)
check("a missing cell is nil as an Any? on the port too", portCell == nil)
check("a present cell is not nil on either side", (hostOrd[0] as Any?) != nil && (portOrd[0] as Any?) != nil)
check("a missing cell and a present cell are the same type, as they are on the host",
      String(describing: type(of: portOrd[1] as Any)) == String(describing: type(of: portOrd[0] as Any)))

let pRow = frame.rowSequence[0]

let pUnit = PortTabularData.AnyColumn(PortTabularData.Column<String?>(name: "u", ["a", nil]))
check("a nil in the optional form is a value, not a missing cell, as Apple says",
      pUnit.missingCount == 0,
      "the port answers \(pUnit.missingCount)")

var hHostFrame = TabularData.DataFrame()
hHostFrame.append(column: TabularData.Column<String>(name: "city", contents: ["berlin", "paris", "madrid"]))
hHostFrame.append(column: TabularData.Column<Int?>(name: "n", contents: [1, nil, 3]))
let hStrings = hHostFrame["city"]
let hOptionals = hHostFrame["n"]
let pStrings = PortTabularData.AnyColumn(PortTabularData.Column<String>(name: "city", ["berlin", "paris", "madrid"]))
let pOptionals = PortTabularData.AnyColumn(PortTabularData.Column<Int?>(name: "n", [1, nil, 3]))
print("DIRECT host missingCount=\(hOptionals.missingCount) host wrapped=\(String(describing: hOptionals.wrappedElementType))")
print("DIRECT port missingCount=\(pOptionals.missingCount) port wrapped=\(String(describing: pOptionals.wrappedElementType))")
print("DIRECT host isNil(at:1)=\(hOptionals.isNil(at: 1)) port isNil(at:1)=\(pOptionals.isNil(at: 1))")
let directHost0 = hStrings[0]
let directPort0 = pStrings[0]
print("DIRECT host [0]=\(String(describing: directHost0)) port [0]=\(String(describing: directPort0))")
print("PROBE-BEFORE missing=\(pOptionals.missingCount) wrapped=\(String(describing: pOptionals.wrappedElementType))")

checkEqualAgainstHost("count: the host's and the port's agree", host: hStrings.count, port: pStrings.count)
checkEqualAgainstHost("name: the host's and the port's agree", host: hStrings.name, port: pStrings.name)
checkEqualAgainstHost("wrappedElementType: the host's and the port's agree",
           host: String(describing: hStrings.wrappedElementType), port: String(describing: pStrings.wrappedElementType))
let hostCell0 = hStrings[0]
let portCell0 = pStrings[0]
let hostCell2 = hStrings[2]
let portCell2 = pStrings[2]
checkEqualAgainstHost("subscript: position 0 reads the same through both",
                      host: String(describing: hostCell0), port: String(describing: portCell0))
checkEqualAgainstHost("subscript: the last position reads the same through both",
                      host: String(describing: hostCell2), port: String(describing: portCell2))
checkEqualAgainstHost("missingCount: the host's and the port's agree on no nils", host: hStrings.missingCount, port: pStrings.missingCount)
checkEqualAgainstHost("missingCount: the host's and the port's agree on one nil",
           host: hOptionals.missingCount, port: pOptionals.missingCount)
    checkEqualAgainstHost("missingCount: the host says 0 for the optional form, so the port must too", host: hOptionals.missingCount, port: 0)
checkEqualAgainstHost("isNil(at:): the host's and the port's agree on a present cell",
           host: hOptionals.isNil(at: 0), port: pOptionals.isNil(at: 0))
checkEqualAgainstHost("isNil(at:): the host's and the port's agree on a missing cell",
           host: hOptionals.isNil(at: 1), port: pOptionals.isNil(at: 1))
checkEqual("isNil(at:) past the end: the host says missing", hOptionals.isNil(at: 99), pOptionals.isNil(at: 99))
checkEqualAgainstHost("wrappedElementType of a column of optionals: the host's and the port's agree",
           host: String(describing: hOptionals.wrappedElementType), port: String(describing: pOptionals.wrappedElementType))
print("PROBE-AFTER  missing=\(pOptionals.missingCount) wrapped=\(String(describing: pOptionals.wrappedElementType))")

let pU = PortTabularData.Column<Int?>(name: "n", [1, nil, 3])
let pS = PortTabularData.Column<String?>(name: "u", ["a", nil])
let bU = PortTabularData.AnyColumn(pU)
let bS = PortTabularData.AnyColumn(pS)
print("PROBE Int?    wrapped=\(String(describing: bU.wrappedElementType)) missing=\(bU.missingCount) erased=\(bU.erasedValues.map { String(describing: $0) })")
print("PROBE String? wrapped=\(String(describing: bS.wrappedElementType)) missing=\(bS.missingCount) erased=\(bS.erasedValues.map { String(describing: $0) })")
print("PROBE diff-column wrapped=\(String(describing: pOptionals.wrappedElementType)) missing=\(pOptionals.missingCount) erased=\(pOptionals.erasedValues.map { String(describing: $0) })")
print("PROBE types: diff=\(String(describing: type(of: pOptionals))) pU=\(String(describing: type(of: pU))) pS=\(String(describing: type(of: pS)))")

let pIn = PortTabularData.Column<String>(name: "city",  ["berlin", "paris"])
let pBox = PortTabularData.AnyColumn(pIn)
checkEqual("the box reports the type the column was made with",
           String(describing: pBox.wrappedElementType), "String")
checkEqual("assumingType hands back the column's own values",
           pBox.assumingType(String.self)?.values ?? [], ["berlin", "paris"])
check("assumingType refuses a type the box does not hold",
      pBox.assumingType(Int.self) == nil,
      "the port answers \(String(describing: pBox.assumingType(Int.self)))")
    checkEqual("a box over a column of optionals reports the type it was made with",
           String(describing: PortTabularData.AnyColumn(PortTabularData.Column<Int?>(name: "n", [1, nil])).wrappedElementType),
           "Optional<Int>")
    checkEqual("a missing cell is missing, not a value, in the ordinary form",
           PortTabularData.AnyColumn(PortTabularData.Column<Int>(name: "n", contents: [1, nil, 3])).missingCount, 1)
check("a row's value carries no second optional", String(describing: pRow["city"]!) == "berlin",
      "the port answers \(String(describing: pRow["city"]!))")
checkEqual("a row by name", "\(frame.rowSequence[0]["city"]!)", "berlin")
checkEqual("a row by ColumnID", frame.rowSequence[0][price]!, 100.0)
checkEqual("a row by name and type", frame.rowSequence[3]["price", Double.self]!, 175.0)
check("a row out of range answers nil", frame.rowSequence[99]["city"] == nil)
checkEqual("a row as a column of one row per column", frame.rowSequence[0].asColumn.count,
           frame.shape.columns)

checkEqual("selecting one column", frame.selecting(columnNames: "price").columnNames, ["price"])
checkEqual("selecting two columns, in the order named",
           frame.selecting(columnNames: "city", "id").columnNames, ["city", "id"])
checkEqual("dropping a column", frame.dropping("city").columnNames, ["id", "price"])
checkEqual("the prefix's row count", frame.prefix(2).shape.rows, 2)
checkEqual("the suffix's row count", frame.suffix(2).shape.rows, 2)
checkEqual("the prefix's values", frame.prefix(3)[price].values, [100, 140, 95])
checkEqual("the suffix's values", frame.suffix(3)[price].values, [175, 130, 110])
checkEqual("a slice's own frame, copied out", frame.prefix(3).frame[price].values, [100, 140, 95])
checkEqual("a slice's column names", frame.prefix(2).columnNames, ["id", "city", "price"])

checkEqual("a filter on the row", frame.filter { ($0[price] ?? 0) > 100 }[price].values, [140, 175, 130, 110])
checkEqual("a filter on a column by name",
           frame.filter(on: "price", Double.self) { ($0 ?? 0) > 100 }[price].values, [140, 175, 130, 110])
checkEqual("a filter on a ColumnID",
           frame.filter(on: price) { ($0 ?? 0) > 100 }[price].values, [140, 175, 130, 110])
checkEqual("a filter on a category", frame.filter(on: city) { $0 == "berlin" }[price].values,
           [100, 95, 110])
checkEqual("a filter that keeps everything", frame.filter { _ in true }[price].values.count, 6)
checkEqual("a filter that keeps nothing", frame.filter { _ in false }[price].values.count, 0)

checkEqual("rows taken by index", frame.rows([5, 0, 5, 2])[price].values, [110, 100, 110, 95])
checkEqual("a discontiguous slice's count", frame.rows([0, 2, 4])[price].count, 3)

frame.append(column: PortTabularData.Column<Int>(name: "id", [9, 9, 9, 9, 9, 9]))
checkEqual("adding a column of a name that is there replaces it", frame[PortTabularData.ColumnID<Int>("id", Int.self)].values,
           [9, 9, 9, 9, 9, 9])
checkEqual("it did not add a column", frame.shape.columns, 3)

var ragged = PortTabularData.DataFrame()
ragged.append(column: PortTabularData.Column<Int>(name: "a", [1, 2, 3]))
ragged.append(column: PortTabularData.Column<Int>(name: "b", [1, 2]))
check("a frame of columns of different heights is invalid", !ragged.isValid)
check("it says which heights",
      ragged.error?.description.contains("2, 3") == true,
      "the port answers \(ragged.error?.description ?? "no error")")
checkEqual("it did not pad the short column", ragged["b"]!.count, 2)
ragged.append(column: PortTabularData.Column<Int>(name: "b", [1, 2, 3]))
check("making the heights agree makes it valid", ragged.isValid)
ragged.removeColumn("a")
checkEqual("removing a column leaves the rest", ragged.columnNames, ["b"])

let column = PortTabularData.Column<Int>(name: "n", [5, 1, 4, 2, 3])
checkEqual("a column's count", column.count, 5)
check("a column is not empty", !column.isEmpty)
checkEqual("a column's start and end index", column.startIndex..<column.endIndex, 0..<5)
checkEqual("a column's index(after:)", column.index(after: 2), 3)
checkEqual("a column's index(before:)", column.index(before: 2), 1)
checkEqual("a column subscripted by position", column[3], 2)
var writable = column
writable[3] = 20
checkEqual("a column written through its position subscript", writable.values, [5, 1, 4, 20, 3])
checkEqual("a column mapped", writable.map { (cell: Int?) -> Int? in cell.map { $0 * 2 } }.values, [10, 2, 8, 40, 6])
checkEqual("a column mapped keeps its length, as Apple's does", writable.map { (cell: Int?) -> Int? in cell.map { $0 * 2 } }.count, 5)
checkEqual("a map whose transform answers nil is nils in place, as Apple's are",
           writable.map { _ -> Int? in nil }.values, [nil, nil, nil, nil, nil])
checkEqual("a column mapped keeps its name", writable.map { (cell: Int?) -> Int? in cell.map { $0 * 2 } }.name, "n")
checkEqual("a column compact-mapped is compacted, as Apple's is",
           writable.compactMap { (cell: Int?) -> Int? in guard let v = cell else { return nil }; return v > 3 ? v : nil }, [5, 4, 20])
let keptPositions = writable.filter { (cell: Int?) -> Bool in guard let v = cell else { return false }; return v > 3 }
checkEqual("a column filtered keeps its positions, as Apple's does",
           keptPositions.indices, [0, 2, 3])
checkEqual("a kept position reads the base's cell at that position", keptPositions[0], 5)
checkEqual("the last kept position reads the base's last kept cell", keptPositions[3], 20)
checkEqual("a discontiguous slice walks its kept positions, not a run",
           keptPositions.map { String(describing: $0) },
           ["Optional(5)", "Optional(4)", "Optional(20)"])
checkEqual("a discontiguous slice walks backwards over its kept positions",
           keptPositions.reversed().map { String(describing: $0) },
           ["Optional(20)", "Optional(4)", "Optional(5)"])
checkEqual("a column filtered reads back through the slice",
           keptPositions.values, [5, 4, 20])
checkEqual("a column's slice", writable[1..<4].values, [1, 4, 20])
checkEqual("a slice's range", writable[1..<4].range, 1..<4)
checkEqual("a slice's name is its column's", writable[1..<4].name, "n")
checkEqual("a slice's startIndex is the range's lower bound, as the host's is for the same range",
           writable[1..<4].startIndex, 1)
checkEqual("a slice's endIndex is the range's upper bound, as the host's is for the same range",
           writable[1..<4].endIndex, 4)
checkEqual("a slice's count is the range's count", writable[1..<4].count, 3)
checkEqual("an in-range read of a slice is the base's cell at that position",
           writable[1..<4][1], writable[1..<4].base[1])
let innerSlice = writable[1..<4][1..<3]
checkEqual("a sub-slice's startIndex is the range's lower bound, as the host's is", innerSlice.startIndex, 1)
checkEqual("a sub-slice's endIndex is the range's upper bound, as the host's is", innerSlice.endIndex, 3)
checkEqual("a sub-slice's count is the range's count, as the host's is", innerSlice.count, 2)
checkEqual("a slice of a slice", innerSlice.values, [1, 4])
checkEqual("a column of a repeating value", PortTabularData.Column<Int>(repeating: 7, count: 4).values,
           [7, 7, 7, 7])
checkEqual("a column built from a sequence", PortTabularData.Column<Int>([1, 2, 3], name: "s").values, [1, 2, 3])
checkEqual("a column's name survives a map", writable.map { $0 }.name, "n")

let erased = PortTabularData.AnyColumn(PortTabularData.Column<Double>(name: "d", [1.5, 2.5]))
checkEqual("an erased column's count", erased.count, 2)
checkEqual("an erased column's values as its own type", erased.presentValues.compactMap { $0 as? Double } ?? [], [1.5, 2.5])
check("an erased column read as another type is nil", erased.assumingType(String.self) == nil)
checkEqual("an erased column reports the type it was made with",
           String(describing: erased.wrappedElementType), "Double")
let mixed = PortTabularData.Column<Any>(name: "m", [1, "two"]).eraseToAnyColumn()
checkEqual("a column of mixed values reports the type it was made with, not the first kind it found",
           String(describing: mixed.wrappedElementType), "Any")
var rowOrdinary = PortTabularData.DataFrame()
rowOrdinary.append(column: PortTabularData.Column<Int>(name: "a", contents: [1, nil, 3]))
var rowOptional = PortTabularData.DataFrame()
rowOptional.append(column: PortTabularData.Column<Int?>(name: "a", contents: [1, nil, 3]))
let rowOrd1 = rowOrdinary.rowSequence[1]["a"]
let rowOpt1 = rowOptional.rowSequence[1]["a"]
check("a row cell that is missing is nil in the ordinary form, as Apple answers",
      rowOrd1 == nil, "the port answers \(String(describing: rowOrd1))")
var cowA = PortTabularData.Column<Int>(name: "c", [1, 2, 3])
var cowB = PortTabularData.Column<Int>(name: "c", [1, 2, 3])
checkEqual("two columns built from equal values start equal", cowA.values, cowB.values)
var cowCopy = cowA
cowCopy[0] = 99
checkEqual("a mutation of a copy does not reach the original", cowA[0], 1)
checkEqual("and the mutation reached the copy", cowCopy[0], 99)
cowA[1] = 77
checkEqual("mutating the original afterwards does not reach the copy", cowCopy[1], 2)

var cowGap1 = PortTabularData.Column<Int>(name: "g", contents: [1, nil, 3])
var cowGap2 = PortTabularData.Column<Int>(name: "g", contents: [1, nil, 3])
checkEqual("two columns with the same gap report the same missing count",
           cowGap1.eraseToAnyColumn().missingCount, cowGap2.eraseToAnyColumn().missingCount)
var cowGapCopy = cowGap1
cowGapCopy[0] = 42
checkEqual("a mutation through a copy of a column with a gap does not reach the original",
           cowGap1[0], 1)

check("a row cell that is a nil value is Optional(nil) in the optional form, as Apple answers",
      String(describing: rowOpt1) == "Optional(nil)",
      "the port answers \(String(describing: rowOpt1))")

check("eraseToAnyColumn is the public door, and it is Apple's name and result type",
      String(describing: PortTabularData.Column<Int>(name: "d", [1]).eraseToAnyColumn().count) == "1")

do {
    let column = PortTabularData.Column<Int>(name: "n", [5, 1, 4, 2, 3])
    checkEqual("a column iterates in order", column.presentValues, [5, 1, 4, 2, 3])
    checkEqual("a column's reversed view", column.presentValues.reversed().map { $0 }, [3, 2, 4, 1, 5])
    checkEqual("the standard library's own max over a column", column.presentValues.max(), 5)
    checkEqual("the standard library's own min over a column", column.presentValues.min(), 1)
    checkClose("the standard library's own sum over a column",
               Double(column.presentValues.reduce(0, +)), 15, 1e-12)
    checkEqual("a column's slice is a collection too", Array(column[2..<4]), [4, 2])
    checkEqual("a slice of a slice", Array(column[1..<4][1..<3]), [1, 4])
    checkEqual("a column's enumerated pairs", column.presentValues.enumerated().map { "\($0.0):\($0.1)" },
               ["0:5", "1:1", "2:4", "3:2", "4:3"])
    var written = column
    written[0] = 50
    checkEqual("a write through a copy of a column reaches the copy", written.values,
               [50, 1, 4, 2, 3])
    checkEqual("and the original does not see it, because a struct copy is a value", column.values,
               [5, 1, 4, 2, 3])
    var copied = Column<Int>(copying: column)
    copied[0] = 5
    checkEqual("a column built with init(copying:) is a copy of its own", column.values,
               [5, 1, 4, 2, 3])
    var throughSlice = Column<Int>(copying: column)
    var slice = throughSlice[1..<3]
    slice[slice.range.lowerBound] = 10
    checkEqual("a write through a slice reaches the column it is a view of", throughSlice.values,
               [5, 10, 4, 2, 3])

    var frame = PortTabularData.DataFrame()
    frame.append(column: PortTabularData.Column<Int>(name: "id", [1, 2, 3]))
    frame.append(column: PortTabularData.Column<String>(name: "city",  ["a", "b", "c"]))
    checkEqual("a frame's rows iterate", frame.rowSequence.map { $0["id"] as Any? as Any }
                   .compactMap { $0 as? Int }, [1, 2, 3])
    checkEqual("a frame's row count through the standard library", frame.rowSequence.count, 3)
    checkEqual("a frame's rows reversed", frame.rowSequence.reversed().map { $0["city"] as Any? as Any }
                   .compactMap { $0 as? String }, ["c", "b", "a"])
    checkEqual("a frame's rows filtered through the standard library",
               frame.rowSequence.filter { ($0["id"] as Any? as Any) as? Int ?? 0 > 1 }
                   .compactMap { $0["city"] as Any? as Any as? String }, ["b", "c"])
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
