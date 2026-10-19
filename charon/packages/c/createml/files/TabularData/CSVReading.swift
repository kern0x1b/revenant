// CSVReading.swift - reading a DataFrame from CSV bytes, and the options and errors that read names.
//
// The reader works on bytes, because the framework's does: a cell that is not UTF-8 is kept as its
// bytes, and a column with one such cell is a Data column. The rules here were measured on the host's
// TabularData with the same bytes, and the differential in tests/backports/host/createml/ checks them
// against it: a quoted cell is never a missing value, even when its text is one of the nil encodings;
// a number is read the way strtod reads it; a blank line is skipped; the row and column numbers of an
// error are 1-based for rows and 0-based for columns.

import Foundation

/// The kind a CSV column is read as, and the kind a named column is forced to.
public enum CSVType: Hashable, Sendable {
    case boolean
    case data
    case date
    case double
    case float
    case integer
    case string
}

/// How CSV bytes are read into a DataFrame. The defaults are the framework's.
public struct CSVReadingOptions {
    /// Whether the first record names the columns. Without one, columns are named `Column 0`, `Column 1`, and so on.
    public var hasHeaderRow: Bool
    /// The unquoted cells that read as a missing value. An empty cell is one of them.
    public var nilEncodings: Set<String>
    /// The cells that read as `true` when a column is a boolean column.
    public var trueEncodings: Set<String>
    /// The cells that read as `false` when a column is a boolean column.
    public var falseEncodings: Set<String>
    /// The kind a column of decimal numbers is read as: `.double`, or `.float`.
    public var floatingPointType: CSVType
    /// Whether a blank line is skipped rather than read as a record of one empty cell.
    public var ignoresEmptyLines: Bool
    /// Whether a field that begins with a quote is read as one quoted field.
    public var usesQuoting: Bool
    /// Whether a backslash escapes the character after it inside a quoted field.
    public var usesEscaping: Bool
    public var delimiter: Character
    public var escapeCharacter: Character
    /// The parsers a date cell is read by, in order: the first one that returns a date for the cell's text
    /// reads it. The framework starts with its ISO 8601 reader; `addDateParseStrategy(_:)` appends one.
    public var dateParsers: [(String) -> Date?] = [parseISODateTime]

    /// Adds a parse strategy to the date parsers, after the ones already there: a cell the parsers before it
    /// do not read is read by this one.
    public mutating func addDateParseStrategy<T: ParseStrategy>(_ strategy: T)
        where T.Input == String, T.Output == Date {
        dateParsers.append { try? strategy.parse($0) }
    }

    public init(hasHeaderRow: Bool = true,
                nilEncodings: Set<String> = ["", "#N/A", "#N/A N/A", "#NA", "N/A", "NA", "NULL", "n/a", "nil", "null"],
                trueEncodings: Set<String> = ["1", "TRUE", "True", "true"],
                falseEncodings: Set<String> = ["0", "FALSE", "False", "false"],
                floatingPointType: CSVType = .double,
                ignoresEmptyLines: Bool = true,
                usesQuoting: Bool = true,
                usesEscaping: Bool = false,
                delimiter: Character = ",",
                escapeCharacter: Character = "\\") {
        self.hasHeaderRow = hasHeaderRow
        self.nilEncodings = nilEncodings
        self.trueEncodings = trueEncodings
        self.falseEncodings = falseEncodings
        self.floatingPointType = floatingPointType
        self.ignoresEmptyLines = ignoresEmptyLines
        self.usesQuoting = usesQuoting
        self.usesEscaping = usesEscaping
        self.delimiter = delimiter
        self.escapeCharacter = escapeCharacter
    }
}

/// Why CSV bytes could not be read. Rows count from 1 over the records after the header; columns
/// count from 0.
public enum CSVReadingError: Error, CustomStringConvertible, LocalizedError {
    case badEncoding(row: Int, column: Int, cellContents: Data)
    case unsupportedEncoding(String)
    case misplacedQuote(row: Int, column: Int)
    case wrongNumberOfColumns(row: Int, columns: Int, expected: Int)
    case failedToParse(row: Int, column: Int, type: CSVType, cellContents: Data)
    case missingColumn(columnName: String)
    case outOfBounds(requested: Int, actual: Int)

    /// The row the error is in, or 0 when no row is. A request past the end names the row it asked for.
    public var row: Int {
        switch self {
        case .unsupportedEncoding, .missingColumn: return 0
        case .misplacedQuote(let row, _), .wrongNumberOfColumns(let row, _, _),
             .failedToParse(let row, _, _, _), .badEncoding(let row, _, _):
            return row
        case .outOfBounds(let requested, _): return requested
        }
    }

    /// The column the error is in, where one cell is at fault.
    public var column: Int? {
        switch self {
        case .misplacedQuote(_, let column), .failedToParse(_, let column, _, _), .badEncoding(_, let column, _):
            return column
        default: return nil
        }
    }

    public var description: String {
        switch self {
        // The framework's own spelling of the word, which is what a caller who compares messages sees.
        case .unsupportedEncoding(let encoding):
            return "Usupported encoding \(encoding). Only UTF8 encoding is supported."
        case .misplacedQuote(let row, let column):
            return "Misplaced quote at row \(row) column \(column)."
        case .wrongNumberOfColumns(let row, let columns, let expected):
            return "Wrong number of columns at row \(row). Expected \(expected) but found \(columns)."
        case .badEncoding(let row, let column, let cellContents):
            return "Bad UTF8 encoding at row \(row) column \(column): \(Array(cellContents))."
        case .failedToParse(let row, let column, let type, let cellContents):
            return "Failed to parse cell at row \(row) column \(column) as \(type). \(CSVReadingError.contents(cellContents))"
        case .missingColumn(let name):
            return "Missing required column \(name)."
        case .outOfBounds(let requested, let actual):
            return "The requested row \(requested) is beyond the number of rows in the file \(actual)."
        }
    }

    /// A cell's contents as the framework words them: its text when it is UTF-8, its bytes when it is not.
    private static func contents(_ data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            return "Cell contents bytes are \(Array(data))."
        }
        return "Cell contents are '\(text)'."
    }

    public var errorDescription: String? { description }
}

/// One field of a record as it was read: its bytes, and whether it was quoted, which is what keeps
/// a quoted nil-encoding from being a missing value.
private struct CSVField {
    var bytes: [UInt8]
    var quoted: Bool
    /// The field as it is in the file, with its quotes and the escapes it has: what an error reports as the
    /// cell's contents, measured on the host (a quoted date cell is reported with its quotes).
    var raw: [UInt8] = []

    /// The field's text, or nil when its bytes are not UTF-8.
    var text: String? { String(bytes: bytes, encoding: .utf8) }
}

extension DataFrame {
    /// A frame read from CSV bytes.
    ///
    /// `columns` keeps the named columns in the order they are named, `rows` the data rows in the range
    /// given, and `types` forces the kind of the columns it names; a column it does not name is inferred.
    public init(csvData data: Data,
                columns: [String]? = nil,
                rows: Range<Int>? = nil,
                types: [String: CSVType] = [:],
                options: CSVReadingOptions = CSVReadingOptions()) throws {
        let records = try DataFrame.csvRecords(data, options: options)
        self.init()
        guard !records.isEmpty else { return }

        let header: [String]
        var body: ArraySlice<[CSVField]>
        if options.hasHeaderRow {
            header = DataFrame.uniqueNames(records[0].map { $0.text ?? "" })
            body = records[1...]
        } else {
            header = (0..<records[0].count).map { "Column \($0)" }
            body = records[...]
        }
        var numbered = [(row: Int, fields: [CSVField])]()
        for (offset, record) in body.enumerated() {
            numbered.append((row: offset + 1, fields: record))
        }
        for entry in numbered where entry.fields.count != header.count {
            throw CSVReadingError.wrongNumberOfColumns(row: entry.row, columns: entry.fields.count, expected: header.count)
        }

        var selected = [Int]()
        for name in columns ?? header {
            guard let index = header.firstIndex(of: name) else {
                throw CSVReadingError.missingColumn(columnName: name)
            }
            selected.append(index)
        }

        // The rows are counted with the header in the file, as the framework's message counts them.
        var chosen = numbered
        if let rows = rows {
            let fileRows = numbered.count + (options.hasHeaderRow ? 1 : 0)
            if rows.lowerBound > numbered.count {
                throw CSVReadingError.outOfBounds(requested: rows.lowerBound + 1, actual: fileRows)
            }
            chosen = Array(numbered[rows.lowerBound..<Swift.min(rows.upperBound, numbered.count)])
        }

        for index in selected {
            let column = try DataFrame.column(name: header[index], at: index, rows: chosen,
                                              type: types[header[index]], options: options)
            append(column: column)
        }
    }

    /// A frame read from a CSV file.
    public init(contentsOfCSVFile url: URL,
                columns: [String]? = nil,
                rows: Range<Int>? = nil,
                types: [String: CSVType] = [:],
                options: CSVReadingOptions = CSVReadingOptions()) throws {
        try self.init(csvData: try Data(contentsOf: url), columns: columns, rows: rows, types: types, options: options)
    }

    /// The header names, with an empty name read as its column's position and a repeated name renamed
    /// `name.1`, `name.2`, and so on, as the framework does.
    private static func uniqueNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var result = [String]()
        for (index, name) in names.enumerated() {
            let base = name.isEmpty ? "Column \(index)" : name
            var candidate = base
            var suffix = 0
            while seen.contains(candidate) {
                suffix += 1
                candidate = "\(base).\(suffix)"
            }
            seen.insert(candidate)
            result.append(candidate)
        }
        return result
    }

    /// The records of the CSV, each a list of its fields. A record with nothing in it is no record when
    /// the options say to skip blank lines, and a record of spaces alone is one of those. An error names
    /// the data row it is in: the header is not one, and the rows count from 1.
    private static func csvRecords(_ data: Data, options: CSVReadingOptions) throws -> [[CSVField]] {
        let headerRows = options.hasHeaderRow ? 1 : 0
        var bytes = [UInt8](data)
        // The two UTF-16 byte orders are named by their byte-order mark, the way the framework names them.
        if bytes.starts(with: [0xFF, 0xFE]) {
            throw CSVReadingError.unsupportedEncoding("Unicode (UTF-16LE)")
        }
        if bytes.starts(with: [0xFE, 0xFF]) {
            throw CSVReadingError.unsupportedEncoding("Unicode (UTF-16BE)")
        }
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes.removeFirst(3)
        }

        let delimiter = Array(String(options.delimiter).utf8)
        let escape = Array(String(options.escapeCharacter).utf8)
        let quote = UInt8(ascii: "\"")
        let newline = UInt8(ascii: "\n")
        let carriageReturn = UInt8(ascii: "\r")
        let space = UInt8(ascii: " ")
        let tab = UInt8(ascii: "\t")

        var records = [[CSVField]]()
        var fields = [CSVField]()
        var field = CSVField(bytes: [], quoted: false)
        var quoted = false
        // A record is empty until a byte, a delimiter or a quote has been read in it.
        var recordIsEmpty = true
        var quoteOpenedAt: (row: Int, column: Int)?
        var index = 0
        // Where the field being read begins in the file: after the delimiter or line break before it.
        var fieldStart = 0

        // The data row of the record being read: the records read so far, less the header.
        func dataRow() -> Int { records.count - headerRows + 1 }
        func endField() {
            // Called at the delimiter or line break that ends the field, so `index` is where it ends.
            field.raw = Array(bytes[fieldStart..<index])
            fields.append(field)
            field = CSVField(bytes: [], quoted: false)
        }
        func endRecord() {
            // A record of spaces and tabs alone is blank too: measured, a line of one space is no row.
            let blank = recordIsEmpty
                || (fields.isEmpty && !field.quoted && field.bytes.allSatisfy { $0 == space || $0 == tab })
            if !(blank && options.ignoresEmptyLines) {
                endField()
                records.append(fields)
            }
            field = CSVField(bytes: [], quoted: false)
            fields = []
            recordIsEmpty = true
        }
        func matches(_ sequence: [UInt8], at position: Int) -> Bool {
            guard !sequence.isEmpty, position + sequence.count <= bytes.count else { return false }
            return bytes[position..<position + sequence.count].elementsEqual(sequence)
        }

        while index < bytes.count {
            let byte = bytes[index]
            if quoted {
                if options.usesEscaping, matches(escape, at: index), index + escape.count < bytes.count {
                    index += escape.count
                    field.bytes.append(bytes[index])
                    index += 1
                    continue
                }
                if byte == quote {
                    if index + 1 < bytes.count, bytes[index + 1] == quote {
                        field.bytes.append(quote)
                        index += 2
                        continue
                    }
                    quoted = false
                    quoteOpenedAt = nil
                    index += 1
                    continue
                }
                field.bytes.append(byte)
                index += 1
                continue
            }
            if options.usesEscaping, matches(escape, at: index), index + escape.count < bytes.count {
                // Measured: the escape reads the byte after it outside quotes as well as inside.
                index += escape.count
                field.bytes.append(bytes[index])
                recordIsEmpty = false
                index += 1
                continue
            }
            if matches(delimiter, at: index) {
                endField()
                recordIsEmpty = false
                index += delimiter.count
                fieldStart = index
                continue
            }
            if byte == newline {
                endRecord()
                index += 1
                fieldStart = index
                continue
            }
            if byte == carriageReturn {
                endRecord()
                index += (index + 1 < bytes.count && bytes[index + 1] == newline) ? 2 : 1
                fieldStart = index
                continue
            }
            if options.usesQuoting, byte == quote {
                if field.bytes.isEmpty {
                    quoted = true
                    field.quoted = true
                    quoteOpenedAt = (row: dataRow(), column: fields.count)
                    recordIsEmpty = false
                    index += 1
                    continue
                }
                throw CSVReadingError.misplacedQuote(row: dataRow(), column: fields.count)
            }
            field.bytes.append(byte)
            recordIsEmpty = false
            index += 1
        }
        if let opened = quoteOpenedAt {
            throw CSVReadingError.misplacedQuote(row: opened.row, column: opened.column)
        }
        if !recordIsEmpty {
            endRecord()
        }
        return records
    }

    /// One column read from its fields: forced to the kind it is named, or inferred. A column with a
    /// cell that is not UTF-8 is a Data column; otherwise it is the first kind every present cell reads
    /// as, in the order integer, floating point, boolean, string. A column with no present cell is a
    /// string column.
    private static func column(name: String, at index: Int, rows: [(row: Int, fields: [CSVField])],
                               type: CSVType?, options: CSVReadingOptions) throws -> AnyColumn {
        let cells = rows.map { entry -> CSVField? in
            let field = entry.fields[index]
            if !field.quoted, let text = field.text, options.nilEncodings.contains(text) { return nil }
            return field
        }
        let present = cells.compactMap { $0 }
        let kind = type ?? inferred(present, options: options)

        func parse<T>(_ convert: (CSVField) -> T?) throws -> Column<T> {
            var values = [T?]()
            for (position, cell) in cells.enumerated() {
                guard let cell = cell else {
                    values.append(nil)
                    continue
                }
                guard let value = convert(cell) else {
                    throw CSVReadingError.failedToParse(row: rows[position].row, column: index, type: kind,
                                                        cellContents: Data(cell.raw))
                }
                values.append(value)
            }
            return Column<T>(name: name, contents: values)
        }
        switch kind {
        case .integer:
            return AnyColumn(try parse { $0.text.flatMap(parseInteger) })
        case .double:
            return AnyColumn(try parse { $0.text.flatMap(parseDouble) })
        case .float:
            return AnyColumn(try parse { $0.text.flatMap(parseFloat) })
        case .boolean:
            return AnyColumn(try parse { cell -> Bool? in
                // A boolean cell is read without its surrounding spaces, which the number and text
                // readings keep: measured, "1 " in a column of its own is true.
                guard let text = cell.text?.trimmingCharacters(in: .whitespaces) else { return nil }
                if options.trueEncodings.contains(text) { return true }
                if options.falseEncodings.contains(text) { return false }
                return nil
            })
        case .data:
            return AnyColumn(try parse { Data($0.bytes) })
        case .string:
            // A string column cannot hold bytes that are not UTF-8, and the framework says so rather than
            // substituting replacement characters.
            var values = [String?]()
            for (position, cell) in cells.enumerated() {
                guard let cell = cell else {
                    values.append(nil)
                    continue
                }
                guard let text = cell.text else {
                    throw CSVReadingError.badEncoding(row: rows[position].row, column: index,
                                                      cellContents: Data(cell.bytes))
                }
                values.append(text)
            }
            return AnyColumn(Column<String>(name: name, contents: values))
        case .date:
            // A cell is read by the first parser that returns a date for its text; a cell whose bytes are
            // not UTF-8 is read by none.
            return AnyColumn(try parse { field -> Date? in
                guard let text = field.text else { return nil }
                for parser in options.dateParsers {
                    if let date = parser(text) { return date }
                }
                return nil
            })
        }
    }

    /// The kind every present cell reads as, in the order the framework tries them.
    private static func inferred(_ present: [CSVField], options: CSVReadingOptions) -> CSVType {
        guard !present.isEmpty else { return .string }
        if present.contains(where: { $0.text == nil }) { return .data }
        let texts = present.compactMap { $0.text }
        if texts.allSatisfy({ parseInteger($0) != nil }) { return .integer }
        if texts.allSatisfy({ parseDouble($0) != nil }) { return options.floatingPointType }
        let trimmed = texts.map { $0.trimmingCharacters(in: .whitespaces) }
        if trimmed.allSatisfy({ options.trueEncodings.contains($0) || options.falseEncodings.contains($0) }) {
            return .boolean
        }
        if texts.allSatisfy({ text in options.dateParsers.contains { $0(text) != nil } }) {
            return .date
        }
        return .string
    }
}

/// An integer as the framework reads one: an optional sign and digits, and a bare sign is zero.
// A bare sign reads as zero: measured on the host, "+" and "-" are integer cells of value 0.
private func parseInteger(_ text: String) -> Int? {
    // The most negative integer is not an integer cell: measured, "-9223372036854775808" reads as a double.
    if let value = Int(text) { return text.hasPrefix("-") && value == Int.min ? nil : value }
    return text == "+" || text == "-" ? 0 : nil
}

/// A double as strtod reads it: a leading space is skipped, nothing may follow the number, and an
/// empty cell is zero. Measured on the host, `""` quoted reads as 0.0 in a numeric column.
private func parseDouble(_ text: String) -> Double? {
    text.withCString { pointer -> Double? in
        var end: UnsafeMutablePointer<CChar>?
        let value = strtod(pointer, &end)
        guard let end = end, end.pointee == 0 else { return nil }
        return value
    }
}

/// A float as strtof reads one, under the same rule as `parseDouble`.
private func parseFloat(_ text: String) -> Float? {
    text.withCString { pointer -> Float? in
        var end: UnsafeMutablePointer<CChar>?
        let value = strtof(pointer, &end)
        guard let end = end, end.pointee == 0 else { return nil }
        return value
    }
}
