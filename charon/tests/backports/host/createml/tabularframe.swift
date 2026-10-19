// tabularframe.swift — the port's `DataFrame` and Apple's, in one process.
//
// The file is a differential, not a test: Apple's `TabularData` is imported beside the port's
// `PortTabularData`, and the checks that name a host are the ones that compare. A check that
// reads only the port is still worth having — it pins the port's own answers so a host
// disagreement can be attributed — but the two are held together so that a change has to
// move both to be accepted.
//
// This is **not** a differential against the host's `TabularData`. It could not be one yet: Apple's
// columns are collections and the port's are not, because a user-defined collection conformance does
// not compile with this toolchain at all (measured on the port's compiler and the host's, with a
// fifteen-line non-generic conformance as the witness — see `facts/TabularData/Columns.md`), and the
// two APIs therefore differ at the type level in a way a single comparison cannot span. So this test
// holds the port's frame to the *rules* the framework's own documentation states, and the host
// comparison of the values stays a separate piece of work rather than a pretend.
//
// Every number here is the port's own, and each check says which rule it is holding the frame to.
import Foundation
// Unbuffered, so a print that precedes a `precondition` or a bounds trap is still there. Swift's
// `print` buffers on a pipe and a trap kills the process before the flush, so without this a suite
// that traps immediately after a diagnostic print shows nothing at all - and "printed nothing" was
// read as "the trap is before the print", which was wrong.
setvbuf(stdout, nil, _IONBF, 0)
// Both frames, in one process: the port's under its own module name, and Apple's as the SDK
// declares it. The port's sources are compiled as `PortTabularData` by run.sh, and every reference
// here is `PortTabularData.`-qualified, so the two `DataFrame`s and the two `Column`s coexist
// without either shadowing the other. Holding both is what makes this a differential rather than a
// test of the port against itself, and it is the wiring every family in this series needs.
// `@testable` for the members that are internal on purpose: `AnyColumn`'s typed initialisers,
// `presentValues` and `erasedValues` are not Apple's, so they are internal, and the suite reads them
// rather than reading around them. Everything else in this file is public on both sides.
@testable import PortTabularData
import TabularData

// The distinguishing test for a discontiguous slice, behind a flag so the suite's own run is untouched.
// Whether `kept[1]` traps or `Array(kept)` traps says whether the index space or the walk is the
// problem, and they are different fixes. Run it as:
//
//     KEEP=1 ./run.sh && "$TMPDIR"/createml-differential.*/tabularframe --slice-probe
//
// The prints are unbuffered, so whichever read traps still leaves the reads before it on the output.
// The slice cases that are supposed to trap each end the process, so each is its own invocation:
//
//     "$TMPDIR"/createml-differential.*/tabularframe --slice-probe
//     "$TMPDIR"/createml-differential.*/tabularframe --slice-probe-before
//     "$TMPDIR"/createml-differential.*/tabularframe --slice-probe-reversed
//
// The prints are unbuffered, so whichever read traps still leaves the reads before it on the output.
// The host's own answers, over a base of `[5, 1, 4, 20, 3]` filtered on `> 3`:
//
//     kept[0] = 5    kept[3] = 20    kept[1] -> Fatal error, not a valid slice index
//     kept.index(before: kept.startIndex) -> Fatal error: Can't move index before startIndex
//
// The third case is the consequence: a `reversed()` walk has to reach that same boundary, so it cannot
// be answered without reaching the trap - and a sentinel that leaves the walk in place would instead
// spin, which is the failure this replaces.
func makeKeptSlice() -> PortTabularData.DiscontiguousColumnSlice<Int> {
    let base = PortTabularData.Column<Int>(name: "n", [5, 1, 4, 20, 3])
    return base.filter { (cell: Int?) -> Bool in
        guard let value = cell else { return false }
        return value > 3
    }
}
// The port's half of the AnyColumn accessor differential, printed beside the host's, so the two are
// read together rather than inferred from which checks fail. `--anycolumn-probe` is its own
// invocation because nothing here traps, and a check is still the assertion.
// The out-of-range trap, in a child process, compared with the host's exit status. A trap ends the
// process that would check it, so the check is two exit statuses and nothing else: the host's control
// (its own process, one statement) exits 133 on `view[0]` over `d[1..<3]`, and this one must too.
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
    // Each read goes into a `let` first, so no subscript brackets sit inside a string interpolation:
    // inside `\( ... )` both brackets have to be escaped, and a rewrite that misses the second one ends
    // the interpolation early. The names carry the answers and the prints carry the labels.
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
    // #12, measured on both sides the same way. The host's own answers, over the ordinary form of
    // `[1, nil, 3]`:
    //
    //   as Any? == nil        true
    //   type(of: as Any)      Optional<Any>
    //   displayStyle          .optional
    //   described             nil
    //
    // and the host's *present* cell at position 0 answers `type` Optional<Any> and `displayStyle`
    // .optional too - so neither of those two is a discriminator. The subscript's own `Any?` is the
    // optional on both sides of a present and a missing cell, and only `== nil` tells them apart.
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

/// Two things, compared, with **neither of them named by this helper**.
///
/// The previous wording - "the port answers \(a)" - was the reason four commits of reports were wrong:
/// it attributed the *first* argument to the port, and the differential passes the **host** first, so
/// every one of its failure messages reported the host's answer with the port's name on it. Four turns
/// were spent reading those messages as statements about the port.
///
/// So the message names both sides by position and claims nothing. Where the two sides *are* a host and
/// a port, the call says so itself with `host:` and `port:` labels - see `checkEqualAgainstHost`.
func checkEqual<T: Equatable>(_ what: String, _ a: T, _ b: T) {
    check(what, a == b, "a=\(a) b=\(b)")
}

/// The same comparison, for the differential, where the two sides *are* a host and a port and saying so
/// is the point of the call.
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

// A frame built the way a caller builds one: a column at a time.
var frame = PortTabularData.DataFrame()
frame.append(column: PortTabularData.Column<Int>(name: "id", [1, 2, 3, 4, 5, 6]))
frame.append(column: PortTabularData.Column<String>(name: "city",
                                                      ["berlin", "paris", "berlin", "madrid", "paris", "berlin"]))
frame.append(column: PortTabularData.Column<Double>(name: "price", [100, 140, 95, 175, 130, 110]))

// The shape: both numbers of it, because a caller checking a frame wants to know that its columns
// agree on a height *and* how many there are.
checkEqual("the shape's rows", frame.shape.rows, 6)
checkEqual("the shape's columns", frame.shape.columns, 3)
checkEqual("the row count", frame.count, 6)
checkEqual("the column names, in the order they were added", frame.columnNames, ["id", "city", "price"])
check("a frame whose columns agree on a height is valid", frame.isValid)
check("a frame is not empty", !frame.isEmpty)

// A typed column, by its identifier and by name with its type: the two ways a caller asks.
let price = PortTabularData.ColumnID<Double>("price", Double.self)
let city = PortTabularData.ColumnID<String>("city", String.self)
checkEqual("a typed column by ColumnID", frame[price].values, [100, 140, 95, 175, 130, 110])
checkEqual("a typed column by name and type", frame["price", Double.self]?.values ?? [], [100, 140, 95, 175, 130, 110])
checkEqual("a category column by ColumnID", frame[city].values.count, 6)

// A column read as a type it is not: nil, and not a column of zeroes. A category column given away
// as numbers is the failure this avoids.
check("a column read as the wrong type is nil", frame["city", Double.self] == nil)
check("containsColumn with the wrong type is false", !frame.containsColumn("city", Double.self))
check("containsColumn with its own type is true", frame.containsColumn("price", Double.self))

// A column that is not there: nil through the subscript, and the dynamic member lookup answers an
// empty column rather than one with invented values in it.
check("a column that is not there is nil", frame["nope"] == nil)
check("the position of a column that is not there is nil", frame.indexOfColumn("nope") == nil)
checkEqual("the dynamic member lookup of a column that is not there has no values", frame.nope.count, 0)
checkEqual("the dynamic member lookup of a column that is there is the column", frame.price.count, 6)
checkEqual("the position of a column by name", frame.indexOfColumn("city"), 1)

// A row, read three ways.
checkEqual("a row's count", frame.rowSequence.count, 6)
// A missing cell as an `Any?`, on both sides. A description string cannot answer the question that
// matters - whether a caller's `if let` takes the right branch - because two values can describe the
// same and compare differently. Both sides answer `true` and `Optional<Any>`, so the erasure is not
// where a missing cell is lost, and the check is here to keep it that way.
let hostOrd = TabularData.Column<Int>(name: "a", contents: [1, nil, 3])
let portOrd = PortTabularData.Column<Int>(name: "a", contents: [1, nil, 3])
let hostCell: Any? = hostOrd[1]
let portCell: Any? = portOrd[1]
check("a missing cell is nil as an Any?, as the host answers", hostCell == nil)
check("a missing cell is nil as an Any? on the port too", portCell == nil)
check("a present cell is not nil on either side", (hostOrd[0] as Any?) != nil && (portOrd[0] as Any?) != nil)
// `type(of:)` and `Mirror` are **not** a discriminator for a missing cell, on either side. Measured on
// Apple's own over the ordinary form of `[1, nil, 3]`:
//
//   missing cell:  type(of: as Any) = Optional<Any>   displayStyle = .optional   == nil  true
//   present cell:  type(of: as Any) = Optional<Any>   displayStyle = .optional   == nil  false
//
// The subscript's own `Any?` is the optional, on both sides of a present and a missing cell, so both
// report the same type and the same display style. Only `== nil` tells them apart - which is the
// comparison the suite has been carrying, and the reason a hypothesis about a boxed `.none` inside
// `Any` was a hypothesis rather than an observation: there is no such boxing to see.
check("a missing cell and a present cell are the same type, as they are on the host",
      String(describing: type(of: portOrd[1] as Any)) == String(describing: type(of: portOrd[0] as Any)))

// A row's value must not be wrapped a second time. A frame's own column describes as
// `Optional("berlin")` after the box, and a row that reads through it describes as
// `Optional(Optional("berlin"))` - so the erasure is putting the `Any?` *into* an `Any` somewhere
// between the column and the row. This check names the requirement; it is red, and the search for
// the place is the commit message of the commit that adds it.
let pRow = frame.rowSequence[0]
// **The value-level comparison is the next thing, and it is not written.** Holding both frames in one
// process is the wiring; comparing them cell by cell is the differential, and the two are different
// amounts of work. What is measured about Apple's API, so the next attempt does not rediscover it:
// `TabularData.Column(name:contents:)` is what Apple's takes where the port's takes `(name:_:)`, and
// with both modules imported an unqualified `DataFrame` or `Column` no longer resolves - every
// reference has to be module-qualified, which the 25 existing `PortTabularData.` references are and
// the new ones were not. The two `AnyColumn`s also disagree on access, which is exactly where a
// comparison would notice, so the accessors are pinned first and compared second.

// One case first, before the eleven: a nil has to survive into the box's storage. Everything the
// accessor comparison later reports about `missingCount` and `isNil(at:)` follows from this, and this
// is the input the port's own suite never had.
let pUnit = PortTabularData.AnyColumn(PortTabularData.Column<String?>(name: "u", ["a", nil]))
// A `nil` in the *optional* form is a value that is nil, not a missing cell. Apple's answer for
// `Column<Int?>` of `[1, nil, 3]` is 0, measured; the ordinary form is the one where a nil is a
// missing cell, and that is the case below.
check("a nil in the optional form is a value, not a missing cell, as Apple says",
      pUnit.missingCount == 0,
      "the port answers \(pUnit.missingCount)")

// **The ordinary form has no spelling on the port, and the two Row cases cannot be written until it
// does.** Apple's `Column<Int>(contents: [1, nil, 3])` holds a missing value and reports
// `wrappedElementType == Int`; the port's `Column<Element>` stores `[Element]`, so:
//
//     error: 'nil' is not compatible with expected element type 'Array<Int>.ArrayLiteralElement' (aka 'Int')
//
// That is a compile error, not a failing check, and it is why there are two cases here rather than
// four. The change is larger than `AnyColumn`'s storage line and `Row`: a column itself has to be
// able to hold a missing value while reporting its element type as the value's own type, which means
// `Column` and `ColumnStorage` are what move, and `AnyColumn` then stops having to strip anything.

// The two AnyColumns side by side, one case per accessor, against Apple's TabularData.
//
// The port's `AnyColumn` is a box over a typed column and Apple's is Apple's own; the five accessors
// below are the ones a caller reaches for, and each is compared rather than asserted, because a port
// that is only ever checked against itself cannot notice being wrong in the way the host is also
// wrong. `assumingType` is deliberately *not* in this list: Apple's returns a non-optional `Column<T>`
// and traps on a wrong `T`, and the port's returns nil, which is a departure already argued and not
// a disagreement to be averaged away.
// Apple's `AnyColumn` has no accessible initialiser - it is reached through a frame, which is the
// only way a caller gets one, and that is the path the comparison should take.
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
// Apple's own answer, measured: a frame-stored `Column<Int?>` of `[1, nil, 3]` reports 0. The
    // check's name used to say the host says one; the host says 0.
    checkEqualAgainstHost("missingCount: the host says 0 for the optional form, so the port must too", host: hOptionals.missingCount, port: 0)
checkEqualAgainstHost("isNil(at:): the host's and the port's agree on a present cell",
           host: hOptionals.isNil(at: 0), port: pOptionals.isNil(at: 0))
checkEqualAgainstHost("isNil(at:): the host's and the port's agree on a missing cell",
           host: hOptionals.isNil(at: 1), port: pOptionals.isNil(at: 1))
checkEqual("isNil(at:) past the end: the host says missing", hOptionals.isNil(at: 99), pOptionals.isNil(at: 99))
checkEqualAgainstHost("wrappedElementType of a column of optionals: the host's and the port's agree",
           host: String(describing: hOptionals.wrappedElementType), port: String(describing: pOptionals.wrappedElementType))
print("PROBE-AFTER  missing=\(pOptionals.missingCount) wrapped=\(String(describing: pOptionals.wrappedElementType))")

// The probe runs here rather than at the top of the file because it reads `pOptionals`, and
// this file is top-level code: a forward read of a top-level `let` is not a compile error and
// is a segfault at run time. That is what the first run of this probe did.
// PROBE: why String? survives and Int? does not.
let pU = PortTabularData.Column<Int?>(name: "n", [1, nil, 3])
let pS = PortTabularData.Column<String?>(name: "u", ["a", nil])
let bU = PortTabularData.AnyColumn(pU)
let bS = PortTabularData.AnyColumn(pS)
print("PROBE Int?    wrapped=\(String(describing: bU.wrappedElementType)) missing=\(bU.missingCount) erased=\(bU.erasedValues.map { String(describing: $0) })")
print("PROBE String? wrapped=\(String(describing: bS.wrappedElementType)) missing=\(bS.missingCount) erased=\(bS.erasedValues.map { String(describing: $0) })")
print("PROBE diff-column wrapped=\(String(describing: pOptionals.wrappedElementType)) missing=\(pOptionals.missingCount) erased=\(pOptionals.erasedValues.map { String(describing: $0) })")
print("PROBE types: diff=\(String(describing: type(of: pOptionals))) pU=\(String(describing: type(of: pU))) pS=\(String(describing: type(of: pS)))")

// The box: the type it was made with, the type it hands back, and the refusal for a type it does
// not hold. The last of the three is the one a value comparison cannot catch, and the one the
// wrong-T mutant is written against.
let pIn = PortTabularData.Column<String>(name: "city",  ["berlin", "paris"])
let pBox = PortTabularData.AnyColumn(pIn)
checkEqual("the box reports the type the column was made with",
           String(describing: pBox.wrappedElementType), "String")
checkEqual("assumingType hands back the column's own values",
           pBox.assumingType(String.self)?.values ?? [], ["berlin", "paris"])
check("assumingType refuses a type the box does not hold",
      pBox.assumingType(Int.self) == nil,
      "the port answers \(String(describing: pBox.assumingType(Int.self)))")
// Apple does not unwrap: `Column<Int?>` reports `Optional<Int>`, measured. This check expected
    // "Int", which was the port's own answer before `_wrappedType` was removed.
    checkEqual("a box over a column of optionals reports the type it was made with",
           String(describing: PortTabularData.AnyColumn(PortTabularData.Column<Int?>(name: "n", [1, nil])).wrappedElementType),
           "Optional<Int>")
// The ordinary form, measured on Apple's own: `Column<Int>(name: "a", contents: [1, nil, 3])`
    // reports 1, and that is the form where a nil is a missing cell.
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

// The projections: the column names, the row counts, and the values that come back.
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

// A filter, three ways: on the row, on a column by name, and on a `ColumnID`.
checkEqual("a filter on the row", frame.filter { ($0[price] ?? 0) > 100 }[price].values, [140, 175, 130, 110])
checkEqual("a filter on a column by name",
           frame.filter(on: "price", Double.self) { ($0 ?? 0) > 100 }[price].values, [140, 175, 130, 110])
checkEqual("a filter on a ColumnID",
           frame.filter(on: price) { ($0 ?? 0) > 100 }[price].values, [140, 175, 130, 110])
checkEqual("a filter on a category", frame.filter(on: city) { $0 == "berlin" }[price].values,
           [100, 95, 110])
checkEqual("a filter that keeps everything", frame.filter { _ in true }[price].values.count, 6)
checkEqual("a filter that keeps nothing", frame.filter { _ in false }[price].values.count, 0)

// Rows taken by index: a projection, so the order asked for is the order given and a repeat is kept.
checkEqual("rows taken by index", frame.rows([5, 0, 5, 2])[price].values, [110, 100, 110, 95])
checkEqual("a discontiguous slice's count", frame.rows([0, 2, 4])[price].count, 3)

// Adding a column of a name that is there replaces it — a frame is keyed by name, because two
// columns of one name is a frame with a column no caller can choose.
frame.append(column: PortTabularData.Column<Int>(name: "id", [9, 9, 9, 9, 9, 9]))
checkEqual("adding a column of a name that is there replaces it", frame[PortTabularData.ColumnID<Int>("id", Int.self)].values,
           [9, 9, 9, 9, 9, 9])
checkEqual("it did not add a column", frame.shape.columns, 3)

// A frame whose columns disagree on a height: invalid, with the heights named, and not padded.
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

// A column on its own, and its slice: the collection-shaped members, spelled as members.
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
// Apple's `map` answers a `Column` of the *same length* with a nil cell mapped to nil in place, and a
// transform that answers nil puts a nil in place too. Measured on Apple's own: `Column<Int>` of 5 for
// a 5-cell column, and five nils for a transform that always answers nil.
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
// The index space is the *base's positions*: `kept[0]` and `kept[3]` read the base's 0 and 3, and
// `kept[1]` is not a position at all - the host traps on it, and `--slice-probe` is that trap in a
// child process, because a trap ends the process that would check it.
checkEqual("a kept position reads the base's cell at that position", keptPositions[0], 5)
checkEqual("the last kept position reads the base's last kept cell", keptPositions[3], 20)
checkEqual("a discontiguous slice walks its kept positions, not a run",
           keptPositions.map { String(describing: $0) },
           ["Optional(5)", "Optional(4)", "Optional(20)"])
// The backward walk, and the host's own answer for it, measured on Apple's own with the backward walk
// **first** so nothing before it could end the process:
//
//     host reversed() = ["Optional(20)", "Optional(4)", "Optional(5)"]
//     host reached the end of the backward walk without trapping
//
// So a sparse slice walks backwards, and only the boundary is a trap: `index(before: startIndex)` is
// refused, and a walk that ends at the last kept position is not. The port answers the same three
// values in the same order, which is what the earlier control was missing - it had died on the
// boundary before reaching this.
checkEqual("a discontiguous slice walks backwards over its kept positions",
           keptPositions.reversed().map { String(describing: $0) },
           ["Optional(20)", "Optional(4)", "Optional(5)"])
checkEqual("a column filtered reads back through the slice",
           keptPositions.values, [5, 4, 20])
checkEqual("a column's slice", writable[1..<4].values, [1, 4, 20])
checkEqual("a slice's range", writable[1..<4].range, 1..<4)
checkEqual("a slice's name is its column's", writable[1..<4].name, "n")
// The index space, against the host's, from the control on Apple's own over
// `d = Column<Int>(name: "c", contents: [1, 2, 3])` and `view = d[1..<3]`:
//
//   startIndex = 1   endIndex = 3   count = 2
//   view[1] = Optional(2)     the base's cell 1
//   view[2] = Optional(3)     the base's cell 2
checkEqual("a slice's startIndex is the range's lower bound, as the host's is for the same range",
           writable[1..<4].startIndex, 1)
checkEqual("a slice's endIndex is the range's upper bound, as the host's is for the same range",
           writable[1..<4].endIndex, 4)
checkEqual("a slice's count is the range's count", writable[1..<4].count, 3)
checkEqual("an in-range read of a slice is the base's cell at that position",
           writable[1..<4][1], writable[1..<4].base[1])
// A sub-slice's range is a range of the **base**, not an offset from the outer slice. Measured on
// Apple's own over `writable = Column<Int>(name: "n", contents: [5, 1, 4, 20, 3])`:
//
//     let inner = writable[1..<4][1..<3]
//     startIndex = 1   endIndex = 3   count = 2
//     elements = [Optional(1), Optional(4)]
//
// The offset reading - cells 2 and 3 - would be `[4, 20]`, and it is what the port did before the index
// space was made base-addressed. All four answers are checked, because "the elements happen to match"
// and "the range is the same range" are different properties, and only the second makes the first true
// for the right reason.
let innerSlice = writable[1..<4][1..<3]
checkEqual("a sub-slice's startIndex is the range's lower bound, as the host's is", innerSlice.startIndex, 1)
checkEqual("a sub-slice's endIndex is the range's upper bound, as the host's is", innerSlice.endIndex, 3)
checkEqual("a sub-slice's count is the range's count, as the host's is", innerSlice.count, 2)
checkEqual("a slice of a slice", innerSlice.values, [1, 4])
checkEqual("a column of a repeating value", PortTabularData.Column<Int>(repeating: 7, count: 4).values,
           [7, 7, 7, 7])
checkEqual("a column built from a sequence", PortTabularData.Column<Int>([1, 2, 3], name: "s").values, [1, 2, 3])
checkEqual("a column's name survives a map", writable.map { $0 }.name, "n")

// An erased column, and the type it says it has.
let erased = PortTabularData.AnyColumn(PortTabularData.Column<Double>(name: "d", [1.5, 2.5]))
checkEqual("an erased column's count", erased.count, 2)
checkEqual("an erased column's values as its own type", erased.presentValues.compactMap { $0 as? Double } ?? [], [1.5, 2.5])
check("an erased column read as another type is nil", erased.assumingType(String.self) == nil)
// The erased column's own type. A metatype is compared by its printed name here rather than by
// `==`, because `Any.Type` has no equality this compiler will compare a metatype through, and the
// printed name is what a caller reads in a log anyway.
// The metatype of a value read out of `[Any]` prints as `Optional(Swift.Double)` and the metatype
// expression `Optional<Double>.self` prints as `Optional<Double>`: two spellings of the same type,
// so the check names the spelling the metatype actually has rather than the one written by hand.
// The erased column's type is the type it was **made with**, which is Apple's answer and the only one
// the port now gives: `wrappedElementType` is recorded at construction, so a column of `Double` reports
// `Double` and a column of mixed values reports the type it was built as rather than guessing from the
// values it happens to hold. The inferred `elementType` is gone - it was a second answer to the same
// question and it answered it differently.
checkEqual("an erased column reports the type it was made with",
           String(describing: erased.wrappedElementType), "Double")
let mixed = PortTabularData.Column<Any>(name: "m", [1, "two"]).eraseToAnyColumn()
checkEqual("a column of mixed values reports the type it was made with, not the first kind it found",
           String(describing: mixed.wrappedElementType), "Any")
// The two Row cases, read through a `Row` and not through a column, because that is the only place
// where a missing cell and a value that is nil come apart. Apple's own, over two frames of the same
// data in the two forms:
//
//     var f1 = DataFrame(); f1.append(column: Column<Int>(name: "a", contents: [1, nil, 3]))
//     var f2 = DataFrame(); f2.append(column: Column<Int?>(name: "a", contents: [1, nil, 3]))
//     String(describing: f1.rows[1]["a"])   ->  nil
//     String(describing: f2.rows[1]["a"])   ->  Optional(nil)
//
// The port, same two frames, same reads. The ordinary form's `nil` is a cell with no value; the
// optional form's `Optional(nil)` is a cell whose value is nil, and a check that reads a column cannot
// see the difference because a column answers `missingCount` and `wrappedElementType` and both forms are
// answerable there.
var rowOrdinary = PortTabularData.DataFrame()
rowOrdinary.append(column: PortTabularData.Column<Int>(name: "a", contents: [1, nil, 3]))
var rowOptional = PortTabularData.DataFrame()
rowOptional.append(column: PortTabularData.Column<Int?>(name: "a", contents: [1, nil, 3]))
let rowOrd1 = rowOrdinary.rowSequence[1]["a"]
let rowOpt1 = rowOptional.rowSequence[1]["a"]
check("a row cell that is missing is nil in the ordinary form, as Apple answers",
      rowOrd1 == nil, "the port answers \(String(describing: rowOrd1))")
// Copy-on-write across two columns built from equal values, which is the property the storage change to
// `[Element?]` could have broken and which nothing else in the suite covers: a mutation of one must not
// reach the other, and a mutation through a *slice* of one must not either.
var cowA = PortTabularData.Column<Int>(name: "c", [1, 2, 3])
var cowB = PortTabularData.Column<Int>(name: "c", [1, 2, 3])
checkEqual("two columns built from equal values start equal", cowA.values, cowB.values)
var cowCopy = cowA                                   // a struct, so this is a second value over the same box
cowCopy[0] = 99
checkEqual("a mutation of a copy does not reach the original", cowA[0], 1)
checkEqual("and the mutation reached the copy", cowCopy[0], 99)
cowA[1] = 77
checkEqual("mutating the original afterwards does not reach the copy", cowCopy[1], 2)

// And the missing-cell case, because a column that can hold a nil is a different sharing question: two
// columns whose cells are equal *as optionals* share, and one whose gap is in a different place does not.
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

// The conformances themselves, which are the thing the port's own test was wrongly told it could
// not have: a caller iterating a column and a frame's rows, with the standard library's own
// algorithms over them rather than the port's.
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
    // A **struct copy of a column is a value**, not a view. Measured on Apple's own, over
    // `Column<Int>(name: "c", contents: [1, 2, 3])`:
    //
    //     var written = c; written[0] = 50
    //     c[0..2]  ->  [Optional(1), Optional(2), Optional(3)]      unchanged
    //
    // These two checks used to assert the opposite - that the original *sees* the write through the
    // copy - and they were asserting a divergence: `Column` is a struct over a shared box, and a struct
    // without a uniqueness check is not a value. The check is `isKnownUniquelyReferenced`, and the box
    // is replaced on the write that needed it.
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
    // A write through a *slice* reaches the column, because a slice is a **view** of its base and the
    // two are one box on purpose. That is the other half of the story from the struct copy above, and it
    // is why there are two writers: `Column.subscript` takes the box, `ColumnSlice.subscript` writes the
    // one every holder shares.
    //
    // **The host's answer for this is not established.** The control that measured the struct copy ended
    // the process - exit 133 - on the slice read, so the host's behaviour here is unmeasured. This
    // check keeps the port's deliberate design (a slice is a view) and is *not* evidence about the
    // host; the second host control is the thing to run before this is claimed to agree.
    var throughSlice = Column<Int>(copying: column)
    var slice = throughSlice[1..<3]
    // `range.lowerBound`, not `0`: the slice's index space is the base's positions, so `slice[0]` is a
    // read outside the range and the host traps on it. Writing the base's cell 1 means asking for cell 1.
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
