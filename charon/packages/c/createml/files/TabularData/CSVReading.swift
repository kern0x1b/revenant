import Foundation

public enum CSVType: Hashable, Sendable {
    case boolean
    case data
    case date
    case double
    case float
    case integer
    case string
}

public struct CSVReadingOptions {
    public var hasHeaderRow: Bool
    public var nilEncodings: Set<String>
    public var trueEncodings: Set<String>
    public var falseEncodings: Set<String>
    public var floatingPointType: CSVType
    public var ignoresEmptyLines: Bool
    public var usesQuoting: Bool
    public var usesEscaping: Bool
    public var delimiter: Character
    public var escapeCharacter: Character
    public var dateParsers: [(String) -> Date?] = [parseISODateTime]

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

public enum CSVReadingError: Error, CustomStringConvertible, LocalizedError {
    case badEncoding(row: Int, column: Int, cellContents: Data)
    case unsupportedEncoding(String)
    case misplacedQuote(row: Int, column: Int)
    case wrongNumberOfColumns(row: Int, columns: Int, expected: Int)
    case failedToParse(row: Int, column: Int, type: CSVType, cellContents: Data)
    case missingColumn(columnName: String)
    case outOfBounds(requested: Int, actual: Int)

    public var row: Int {
        switch self {
        case .unsupportedEncoding, .missingColumn: return 0
        case .misplacedQuote(let row, _), .wrongNumberOfColumns(let row, _, _),
             .failedToParse(let row, _, _, _), .badEncoding(let row, _, _):
            return row
        case .outOfBounds(let requested, _): return requested
        }
    }

    public var column: Int? {
        switch self {
        case .misplacedQuote(_, let column), .failedToParse(_, let column, _, _), .badEncoding(_, let column, _):
            return column
        default: return nil
        }
    }

    public var description: String {
        switch self {
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

    private static func contents(_ data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            return "Cell contents bytes are \(Array(data))."
        }
        return "Cell contents are '\(text)'."
    }

    public var errorDescription: String? { description }
}

private struct CSVField {
    var bytes: [UInt8]
    var quoted: Bool
    var raw: [UInt8] = []

    var text: String? { String(bytes: bytes, encoding: .utf8) }
}

extension DataFrame {
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

    public init(contentsOfCSVFile url: URL,
                columns: [String]? = nil,
                rows: Range<Int>? = nil,
                types: [String: CSVType] = [:],
                options: CSVReadingOptions = CSVReadingOptions()) throws {
        try self.init(csvData: try Data(contentsOf: url), columns: columns, rows: rows, types: types, options: options)
    }

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

    private static func csvRecords(_ data: Data, options: CSVReadingOptions) throws -> [[CSVField]] {
        let headerRows = options.hasHeaderRow ? 1 : 0
        var bytes = [UInt8](data)
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
        var recordIsEmpty = true
        var quoteOpenedAt: (row: Int, column: Int)?
        var index = 0
        var fieldStart = 0

        func dataRow() -> Int { records.count - headerRows + 1 }
        func endField() {
            field.raw = Array(bytes[fieldStart..<index])
            fields.append(field)
            field = CSVField(bytes: [], quoted: false)
        }
        func endRecord() {
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
                guard let text = cell.text?.trimmingCharacters(in: .whitespaces) else { return nil }
                if options.trueEncodings.contains(text) { return true }
                if options.falseEncodings.contains(text) { return false }
                return nil
            })
        case .data:
            return AnyColumn(try parse { Data($0.bytes) })
        case .string:
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
            return AnyColumn(try parse { field -> Date? in
                guard let text = field.text else { return nil }
                for parser in options.dateParsers {
                    if let date = parser(text) { return date }
                }
                return nil
            })
        }
    }

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

private func parseInteger(_ text: String) -> Int? {
    if let value = Int(text) { return text.hasPrefix("-") && value == Int.min ? nil : value }
    return text == "+" || text == "-" ? 0 : nil
}

private func parseDouble(_ text: String) -> Double? {
    text.withCString { pointer -> Double? in
        var end: UnsafeMutablePointer<CChar>?
        let value = strtod(pointer, &end)
        guard let end = end, end.pointee == 0 else { return nil }
        return value
    }
}

private func parseFloat(_ text: String) -> Float? {
    text.withCString { pointer -> Float? in
        var end: UnsafeMutablePointer<CChar>?
        let value = strtof(pointer, &end)
        guard let end = end, end.pointee == 0 else { return nil }
        return value
    }
}
