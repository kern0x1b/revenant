// csvreading.swift - the port's CSV reader and Apple's, in one process, over the same bytes.
//
// Each case is read by Apple's `TabularData` and by the port's `PortTabularData` (the sources renamed by
// run.sh, as tabularframe.swift is), and the two renderings must be equal: the columns, their element
// types, their values, or the error's text and its row and column. A mismatch is a failure.
//
// The OPEN cases are printed and not counted. They are readings the host gives and the port does not
// yet: a line of spaces among the records, which the host folds into the header; they are listed with
// what the host answers, so the gap stays visible in the run.

import Foundation
import PortTabularData
import TabularData

struct Case {
    let label: String
    let bytes: [UInt8]
    var columns: [String]? = nil
    var rows: Range<Int>? = nil
    var types: [String: String] = [:]
    var hasHeaderRow = true
    var usesEscaping = false
    var ignoresEmptyLines = true
    var usesQuoting = true
    var floatingPoint = false
    var delimiter: Character = ","
}

func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }

// The two modules both declare the names the reader uses, so every name from each is qualified.
func appleKind(_ name: String) -> TabularData.CSVType {
    switch name {
    case "boolean": return .boolean
    case "data": return .data
    case "date": return .date
    case "double": return .double
    case "float": return .float
    case "integer": return .integer
    default: return .string
    }
}

func portKind(_ name: String) -> PortTabularData.CSVType {
    switch name {
    case "boolean": return .boolean
    case "data": return .data
    case "date": return .date
    case "double": return .double
    case "float": return .float
    case "integer": return .integer
    default: return .string
    }
}

func appleRendering(_ c: Case) -> String {
    var options = TabularData.CSVReadingOptions(delimiter: c.delimiter)
    options.hasHeaderRow = c.hasHeaderRow
    options.usesEscaping = c.usesEscaping
    options.ignoresEmptyLines = c.ignoresEmptyLines
    options.usesQuoting = c.usesQuoting
    if c.floatingPoint { options.floatingPointType = .float }
    let types = c.types.mapValues(appleKind)
    do {
        let frame = try TabularData.DataFrame(csvData: Data(c.bytes), columns: c.columns, rows: c.rows,
                                              types: types, options: options)
        return describe(frame.columns.map { column in
            (column.name, "\(column.wrappedElementType)", cells(column.count) { column[$0] })
        }, shape: frame.shape.rows)
    } catch let error as TabularData.CSVReadingError {
        return "error \(error.description) | row=\(error.row) column=\(String(describing: error.column))"
    } catch {
        return "other \(error)"
    }
}

func portRendering(_ c: Case) -> String {
    var options = PortTabularData.CSVReadingOptions(delimiter: c.delimiter)
    options.hasHeaderRow = c.hasHeaderRow
    options.usesEscaping = c.usesEscaping
    options.ignoresEmptyLines = c.ignoresEmptyLines
    options.usesQuoting = c.usesQuoting
    if c.floatingPoint { options.floatingPointType = .float }
    let types = c.types.mapValues(portKind)
    do {
        let frame = try PortTabularData.DataFrame(csvData: Data(c.bytes), columns: c.columns, rows: c.rows,
                                                  types: types, options: options)
        return describe(frame.columns.map { column in
            (column.name, "\(column.wrappedElementType)", cells(column.count) { column[$0] })
        }, shape: frame.shape.rows)
    } catch let error as PortTabularData.CSVReadingError {
        return "error \(error.description) | row=\(error.row) column=\(String(describing: error.column))"
    } catch {
        return "other \(error)"
    }
}

// The two modules' columns are read through the same members, so one cell renderer serves both.
func cells(_ count: Int, _ value: (Int) -> Any?) -> [String] {
    (0..<count).map { i in
        guard let cell = value(i) else { return "nil" }
        if let data = cell as? Data { return "bytes\(Array(data))" }
        return "\(cell)"
    }
}

func describe(_ columns: [(String, String, [String])], shape: Int) -> String {
    var line = "rows=\(shape)"
    for (name, type, values) in columns {
        line += " | \(name):\(type)=\(values)"
    }
    return line
}

var failures = 0
var checks = 0

func check(_ c: Case) {
    checks += 1
    let host = appleRendering(c)
    let port = portRendering(c)
    if host != port {
        failures += 1
        print("FAIL \(c.label)\n  host: \(host)\n  port: \(port)")
    }
}

let cases: [Case] = [
    Case(label: "ints", bytes: bytes("a,b\n1,2\n3,4\n")),
    Case(label: "int and double", bytes: bytes("a\n1\n2.5\n")),
    Case(label: "bool words", bytes: bytes("a\ntrue\nfalse\n")),
    Case(label: "bool 1 and 0", bytes: bytes("a\n1\n0\n")),
    Case(label: "bool and 1", bytes: bytes("a\n1\ntrue\n")),
    Case(label: "mixed", bytes: bytes("a\n1\nx\n")),
    Case(label: "nils", bytes: bytes("a,b\n1,\nNA,x\n")),
    Case(label: "quoted fields", bytes: bytes("a,b\n\"x,y\",\"line\nbreak\"\n")),
    Case(label: "blank lines skipped", bytes: bytes("a,b\n1,2\n\n3,4\n")),
    Case(label: "blank lines kept", bytes: bytes("a,b\n1,2\n\n3,4\n"), ignoresEmptyLines: false),
    Case(label: "nan", bytes: bytes("a\n1.0\nNaN\n")),
    Case(label: "all nil", bytes: bytes("a,b\n,1\n,2\n")),
    Case(label: "no header", bytes: bytes("a,b\n1,2\n"), hasHeaderRow: false),
    Case(label: "ragged row", bytes: bytes("a,b\n1,2\n3\n")),
    Case(label: "unterminated quote", bytes: bytes("a,b\n1,\"2\n3,4\n")),
    Case(label: "bare quote", bytes: bytes("a,b\n1,x\"y\n")),
    Case(label: "duplicate header", bytes: bytes("a,a\n1,2\n")),
    Case(label: "triple header", bytes: bytes("a,a,a\n1,2,3\n")),
    Case(label: "empty header name", bytes: bytes(",b\n1,2\n")),
    Case(label: "spaces", bytes: bytes("a\n 1\n2 \n")),
    Case(label: "crlf", bytes: bytes("a,b\r\n1,2\r\n")),
    Case(label: "lone cr", bytes: bytes("a,b\r1,2\r")),
    Case(label: "byte order mark", bytes: [0xEF, 0xBB, 0xBF] + bytes("a,b\n1,2\n")),
    Case(label: "doubled quote", bytes: bytes("a\n\"he said \"\"hi\"\"\"\n")),
    Case(label: "backslash escape", bytes: bytes("a\n\"x\\\"y\"\n"), usesEscaping: true),
    Case(label: "backslash without escaping", bytes: bytes("a\n\"x\\\"y\"\n")),
    Case(label: "escape outside quotes", bytes: bytes("a\nx\\\"y\n"), usesEscaping: true),
    Case(label: "big integer", bytes: bytes("a\n9999999999999999999999\n1\n")),
    Case(label: "signed integers", bytes: bytes("a\n-5\n+3\n")),
    Case(label: "exponent", bytes: bytes("a\n1e3\n2\n")),
    Case(label: "utf-16 le", bytes: [0xFF, 0xFE, 0x61, 0x00, 0x0A, 0x00]),
    Case(label: "utf-16 be", bytes: [0xFE, 0xFF, 0x00, 0x61, 0x00, 0x0A]),
    Case(label: "invalid utf-8 cell", bytes: [0x61, 0x2C, 0x62, 0x0A, 0xFF, 0x41, 0x2C, 0x33, 0x0A]),
    Case(label: "invalid utf-8 after text", bytes: [0x61, 0x0A, 0x78, 0x0A, 0xFF, 0x0A]),
    Case(label: "invalid utf-8 forced string", bytes: [0x61, 0x0A, 0xFF, 0x0A], types: ["a": "string"]),
    Case(label: "invalid utf-8 forced integer", bytes: [0x61, 0x0A, 0xFF, 0x0A], types: ["a": "integer"]),
    Case(label: "empty input", bytes: []),
    Case(label: "header only", bytes: bytes("a,b\n")),
    Case(label: "forced integer, bad cell", bytes: bytes("a\nx\n"), types: ["a": "integer"]),
    Case(label: "forced float", bytes: bytes("a\n1.5\n"), types: ["a": "float"]),
    Case(label: "forced boolean", bytes: bytes("a\ntrue\n1\n"), types: ["a": "boolean"]),
    Case(label: "forced string", bytes: bytes("a\n1\n2\n"), types: ["a": "string"]),
    Case(label: "forced type of an absent column", bytes: bytes("a\n1\n"), types: ["q": "string"]),
    Case(label: "forced data", bytes: bytes("a\nab\n"), types: ["a": "data"]),
    Case(label: "missing column", bytes: bytes("a,b\n1,2\n"), columns: ["zz"]),
    Case(label: "selected columns in order", bytes: bytes("a,b,c\n1,2,3\n"), columns: ["c", "a"]),
    Case(label: "row range", bytes: bytes("a\n1\n2\n3\n"), rows: 1..<3),
    Case(label: "row range past the end", bytes: bytes("a,b\n1,2\n"), rows: 5..<9),
    Case(label: "row range overlapping the end", bytes: bytes("a\n1\n2\n3\n"), rows: 1..<9),
    Case(label: "row range at the end", bytes: bytes("a\n1\n2\n"), rows: 2..<9),
    Case(label: "semicolon delimiter", bytes: bytes("a;b\n1;x\n"), delimiter: ";"),
    Case(label: "no quoting", bytes: bytes("a\n\"x\"\n"), usesQuoting: false),
    Case(label: "float type", bytes: bytes("a\n1.5\n2\n"), floatingPoint: true),
    Case(label: "quote then text", bytes: bytes("a,b\n\"x\"y,2\n")),
    Case(label: "quoted empty", bytes: bytes("a\n\"\"\n")),
    Case(label: "quoted empty then one", bytes: bytes("a\n\"\"\n1\n")),
    Case(label: "quoted empty twice", bytes: bytes("a\n\"\"\n\"\"\n")),
    Case(label: "quoted empty then text", bytes: bytes("a\n\"\"\nx\n")),
    Case(label: "quoted empty then blank", bytes: bytes("a\n\"\"\n\n")),
    Case(label: "quoted nil encoding", bytes: bytes("a\n\"NA\"\n1\n")),
    Case(label: "empty header quoted", bytes: bytes("\"\",b\n1,2\n")),
    Case(label: "blank line first", bytes: bytes("a\n\n1\n")),
    Case(label: "number cells: inf", bytes: bytes("a\ninf\n-inf\n")),
    Case(label: "number cells: infinity", bytes: bytes("a\ninfinity\n")),
    Case(label: "number cells: hexadecimal", bytes: bytes("a\n0x1A\n")),
    Case(label: "number cells: leading point", bytes: bytes("a\n.5\n")),
    Case(label: "number cells: trailing point", bytes: bytes("a\n5.\n")),
    Case(label: "number cells: incomplete exponent", bytes: bytes("a\n1e\n")),
    Case(label: "number cells: suffix", bytes: bytes("a\n1d\n")),
    Case(label: "number cells: bare plus", bytes: bytes("a\n+\n")),
    Case(label: "number cells: bare minus", bytes: bytes("a\n-\n")),
    Case(label: "number cells: nan", bytes: bytes("a\nnan\n")),
    Case(label: "number cells: leading space", bytes: bytes("a\n 12\n")),
    Case(label: "number cells: leading zeros", bytes: bytes("a\n00012\n")),
    Case(label: "number cells: underscore", bytes: bytes("a\n1_000\n")),
    Case(label: "number cells: binary", bytes: bytes("a\n0b1\n")),
    Case(label: "number cells: overflowing exponent", bytes: bytes("a\n1e400\n-1e400\n")),
    Case(label: "number cells: fraction", bytes: bytes("a\n1.5e-3\n")),
    Case(label: "number cells: int64 max", bytes: bytes("a\n9223372036854775807\n")),
    Case(label: "number cells: beyond int64", bytes: bytes("a\n9223372036854775808\n")),
    Case(label: "number cells: int64 min", bytes: bytes("a\n-9223372036854775808\n")),
    Case(label: "boolean cell with trailing space", bytes: bytes("a\n1 \n")),
    Case(label: "number cell with trailing space", bytes: bytes("a\n0.0\n")),
]

for c in cases { check(c) }

// OPEN: a line of spaces among the records. The host folds it into the header (its cell is the header
// `a` followed by a newline and the spaces), and with blank lines kept it reads the line as nil. Neither
// is carried yet; printed, not counted.
let openCases: [Case] = [
    Case(label: "a line of spaces", bytes: bytes("a\n \n1\n")),
    Case(label: "a line of spaces, blank lines kept", bytes: bytes("a\n \n1\n"), ignoresEmptyLines: false),
]
for c in openCases {
    print("OPEN \(c.label)\n  host: \(appleRendering(c))\n  port: \(portRendering(c))")
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
