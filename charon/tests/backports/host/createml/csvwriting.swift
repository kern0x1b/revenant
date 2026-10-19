import Foundation
import PortTabularData
import TabularData

struct Col {
    let name: String
    let kind: String
    let values: [Any?]
}

struct Case {
    let label: String
    var cols: [Col]
    var header = true
    var nilEnc = ""
    var trueEnc = "true"
    var falseEnc = "false"
    var newline = "\n"
    var delimiter: Character = ","
    var dateFormat: String? = nil
    var setNewline: String? = nil
    var setDelimiter: Character? = nil
    var setNilEnc: String? = nil
    var setTrueEnc: String? = nil
    var setFalseEnc: String? = nil
    var setDateFormat: String? = nil
}

func utcFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = format
    return formatter
}

func appendTyped<T>(_ frame: inout TabularData.DataFrame, _ name: String, _ values: [Any?], _: T.Type) {
    frame.append(column: TabularData.Column<T>(name: name, contents: values.map { $0 as? T }))
}

func portAppendTyped<T>(_ frame: inout PortTabularData.DataFrame, _ name: String, _ values: [Any?], _: T.Type) {
    frame.append(column: PortTabularData.Column<T>(name: name, contents: values.map { $0 as? T }))
}

func appleFrame(_ cols: [Col]) -> TabularData.DataFrame {
    var frame = TabularData.DataFrame()
    for c in cols {
        switch c.kind {
        case "String": appendTyped(&frame, c.name, c.values, String.self)
        case "Int": appendTyped(&frame, c.name, c.values, Int.self)
        case "Double": appendTyped(&frame, c.name, c.values, Double.self)
        case "Float": appendTyped(&frame, c.name, c.values, Float.self)
        case "Bool": appendTyped(&frame, c.name, c.values, Bool.self)
        case "Date": appendTyped(&frame, c.name, c.values, Date.self)
        case "Data": appendTyped(&frame, c.name, c.values, Data.self)
        case "UUID": appendTyped(&frame, c.name, c.values, UUID.self)
        default: fatalError("unknown kind \(c.kind)")
        }
    }
    return frame
}

func portFrame(_ cols: [Col]) -> PortTabularData.DataFrame {
    var frame = PortTabularData.DataFrame()
    for c in cols {
        switch c.kind {
        case "String": portAppendTyped(&frame, c.name, c.values, String.self)
        case "Int": portAppendTyped(&frame, c.name, c.values, Int.self)
        case "Double": portAppendTyped(&frame, c.name, c.values, Double.self)
        case "Float": portAppendTyped(&frame, c.name, c.values, Float.self)
        case "Bool": portAppendTyped(&frame, c.name, c.values, Bool.self)
        case "Date": portAppendTyped(&frame, c.name, c.values, Date.self)
        case "Data": portAppendTyped(&frame, c.name, c.values, Data.self)
        case "UUID": portAppendTyped(&frame, c.name, c.values, UUID.self)
        default: fatalError("unknown kind \(c.kind)")
        }
    }
    return frame
}

func appleOptions(_ c: Case) -> TabularData.CSVWritingOptions {
    var options: TabularData.CSVWritingOptions
    if let format = c.dateFormat {
        options = TabularData.CSVWritingOptions(includesHeader: c.header, dateFormat: format, nilEncoding: c.nilEnc,
                                                trueEncoding: c.trueEnc, falseEncoding: c.falseEnc,
                                                newline: c.newline, delimiter: c.delimiter)
    } else {
        options = TabularData.CSVWritingOptions(includesHeader: c.header, nilEncoding: c.nilEnc,
                                                trueEncoding: c.trueEnc, falseEncoding: c.falseEnc,
                                                newline: c.newline, delimiter: c.delimiter)
    }
    if let newline = c.setNewline { options.newline = newline }
    if let delimiter = c.setDelimiter { options.delimiter = delimiter }
    if let nilText = c.setNilEnc { options.nilEncoding = nilText }
    if let t = c.setTrueEnc { options.trueEncoding = t }
    if let f = c.setFalseEnc { options.falseEncoding = f }
    if let format = c.setDateFormat {
        options.dateFormatter = { date in utcFormatter(format).string(from: date) }
    }
    return options
}

func portOptions(_ c: Case) -> PortTabularData.CSVWritingOptions {
    var options: PortTabularData.CSVWritingOptions
    if let format = c.dateFormat {
        options = PortTabularData.CSVWritingOptions(includesHeader: c.header, dateFormat: format, nilEncoding: c.nilEnc,
                                                    trueEncoding: c.trueEnc, falseEncoding: c.falseEnc,
                                                    newline: c.newline, delimiter: c.delimiter)
    } else {
        options = PortTabularData.CSVWritingOptions(includesHeader: c.header, nilEncoding: c.nilEnc,
                                                    trueEncoding: c.trueEnc, falseEncoding: c.falseEnc,
                                                    newline: c.newline, delimiter: c.delimiter)
    }
    if let newline = c.setNewline { options.newline = newline }
    if let delimiter = c.setDelimiter { options.delimiter = delimiter }
    if let nilText = c.setNilEnc { options.nilEncoding = nilText }
    if let t = c.setTrueEnc { options.trueEncoding = t }
    if let f = c.setFalseEnc { options.falseEncoding = f }
    if let format = c.setDateFormat {
        options.dateFormatter = { date in utcFormatter(format).string(from: date) }
    }
    return options
}

func appleAnswer(_ c: Case) -> String {
    do {
        let data = try appleFrame(c.cols).csvRepresentation(options: appleOptions(c))
        return "ok \(String(reflecting: String(decoding: data, as: UTF8.self))) bytes=\(Array(data).count)"
    } catch {
        if case .badEncoding(let row, let column, let cellContents)? = error as? TabularData.CSVWritingError {
            return "badEncoding row=\(row) column=\(String(describing: column)) cell=\(Array(cellContents)) text=\(error)"
        }
        return "other \(error)"
    }
}

func portAnswer(_ c: Case) -> String {
    do {
        let data = try portFrame(c.cols).csvRepresentation(options: portOptions(c))
        return "ok \(String(reflecting: String(decoding: data, as: UTF8.self))) bytes=\(Array(data).count)"
    } catch {
        if case .badEncoding(let row, let column, let cellContents)? = error as? PortTabularData.CSVWritingError {
            return "badEncoding row=\(row) column=\(String(describing: column)) cell=\(Array(cellContents)) text=\(error)"
        }
        return "other \(error)"
    }
}

var checks = 0
var failures = 0

func check(_ c: Case) {
    checks += 1
    let apple = appleAnswer(c)
    let port = portAnswer(c)
    if apple == port {
        print("ok    \(c.label): \(apple)")
    } else {
        failures += 1
        print("FAIL  \(c.label)")
        print("  apple: \(apple)")
        print("  port:  \(port)")
    }
}

let cases: [Case] = [
    Case(label: "strings quoted where the text needs it", cols: [
        Col(name: "s", kind: "String", values: ["plain", "a,b", "say \"hi\"", "line\nbreak", " pad ", "", "x", "cr\rhere", "tab\there"]),
    ]),
    Case(label: "nil strings and ints", cols: [
        Col(name: "s", kind: "String", values: ["a", nil, "b"]),
        Col(name: "n", kind: "Int", values: [1, nil, 3]),
    ]),
    Case(label: "doubles, floats and ints", cols: [
        Col(name: "d", kind: "Double", values: [1.0, 2.5, 1e22, -0.0, Double.nan, Double.infinity, 0.1]),
        Col(name: "f", kind: "Float", values: [Float(1.0), Float(2.5), Float(0.1)]),
        Col(name: "i", kind: "Int", values: [0, -7, Int.max]),
    ]),
    Case(label: "double formats", cols: [
        Col(name: "x", kind: "Double", values: [0.30000000000000004, 1e-7, 123456789.0]),
    ]),
    Case(label: "bools", cols: [Col(name: "b", kind: "Bool", values: [true, false])]),
    Case(label: "nil bool", cols: [Col(name: "b", kind: "Bool", values: [true, nil])]),
    Case(label: "dates, default formatter", cols: [
        Col(name: "t", kind: "Date", values: [Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 86400.5)]),
    ]),
    Case(label: "dates, date format init", cols: [
        Col(name: "t", kind: "Date", values: [Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 86400.5)]),
    ], dateFormat: "yyyy/MM/dd HH:mm"),
    Case(label: "dates, date format with a comma is quoted", cols: [
        Col(name: "t", kind: "Date", values: [Date(timeIntervalSince1970: 0)]),
    ], dateFormat: "yyyy, MM"),
    Case(label: "dates, formatter assigned as a property", cols: [
        Col(name: "t", kind: "Date", values: [Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 86400.5)]),
    ], setDateFormat: "yyyy/MM/dd HH:mm"),
    Case(label: "data, valid UTF-8 quoted", cols: [
        Col(name: "d", kind: "Data", values: [Data("ab".utf8), Data("c,d".utf8), nil]),
    ]),
    Case(label: "data, invalid UTF-8 names the row and column", cols: [
        Col(name: "ok", kind: "Int", values: [1, 2]),
        Col(name: "d", kind: "Data", values: [Data("ab".utf8), Data([0xFF])]),
    ]),
    Case(label: "element type the writer does not name", cols: [
        Col(name: "u", kind: "UUID", values: [UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, nil]),
    ]),
    Case(label: "no header", cols: [
        Col(name: "s", kind: "String", values: ["a", "b"]),
        Col(name: "n", kind: "Int", values: [1, 2]),
    ], header: false),
    Case(label: "custom nil, true, false, newline and delimiter", cols: [
        Col(name: "s", kind: "String", values: ["a", nil, "b;c"]),
        Col(name: "b", kind: "Bool", values: [true, false, nil]),
    ], header: true, nilEnc: "-", trueEnc: "T", falseEnc: "F", newline: "\r\n", delimiter: ";"),
    Case(label: "header names are written raw", cols: [
        Col(name: "a,b", kind: "Int", values: [1]),
        Col(name: "say \"x\"", kind: "Int", values: [2]),
        Col(name: "", kind: "Int", values: [3]),
    ]),
    Case(label: "empty frame", cols: []),
    Case(label: "header only", cols: [Col(name: "s", kind: "String", values: [])]),
    Case(label: "ragged columns write empty cells", cols: [
        Col(name: "a", kind: "Int", values: [1, 2]),
        Col(name: "b", kind: "Int", values: [1]),
    ]),
    Case(label: "newline given to the initialiser is not kept", cols: [
        Col(name: "a", kind: "Int", values: [1, 2]),
    ], newline: "\r\n"),
    Case(label: "newline given to the date format initialiser", cols: [
        Col(name: "a", kind: "Int", values: [1, 2]),
    ], newline: "\r\n", dateFormat: "yyyy"),
    Case(label: "newline assigned as a property", cols: [
        Col(name: "a", kind: "Int", values: [1, 2]),
    ], setNewline: "|"),
    Case(label: "delimiter assigned as a property", cols: [
        Col(name: "a", kind: "String", values: ["x;y", "z"]),
        Col(name: "b", kind: "Int", values: [1, 2]),
    ], setDelimiter: ";"),
    Case(label: "nil encoding assigned as a property", cols: [
        Col(name: "n", kind: "Int", values: [nil, 4]),
    ], setNilEnc: "NULL"),
    Case(label: "true and false encodings assigned as properties", cols: [
        Col(name: "b", kind: "Bool", values: [true, false]),
    ], setTrueEnc: "yes", setFalseEnc: "no"),
]

for c in cases {
    check(c)
}
checks += 1
let directory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
do {
    let appleURL = directory.appendingPathComponent("csvwriting-apple.csv")
    let portURL = directory.appendingPathComponent("csvwriting-port.csv")
    try appleFrame(cases[0].cols).writeCSV(to: appleURL, options: appleOptions(cases[0]))
    try portFrame(cases[0].cols).writeCSV(to: portURL, options: portOptions(cases[0]))
    let apple = try Data(contentsOf: appleURL)
    let port = try Data(contentsOf: portURL)
    if apple == port {
        print("ok    writeCSV(to:) writes the same file: \(apple.count) bytes")
    } else {
        failures += 1
        print("FAIL  writeCSV(to:)")
        print("  apple: \(String(decoding: apple, as: UTF8.self))")
        print("  port:  \(String(decoding: port, as: UTF8.self))")
    }
} catch {
    failures += 1
    print("FAIL  writeCSV(to:) threw \(error)")
}
print("\(checks) checks, \(failures) failures")
