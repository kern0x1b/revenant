import Foundation

public struct CSVWritingOptions {
    public var includesHeader: Bool
    public var dateFormat: String?
    public var dateFormatter: (Date) -> String
    public var nilEncoding: String
    public var trueEncoding: String
    public var falseEncoding: String
    public var newline: String
    public var delimiter: Character

    public init() {
        self.init(includesHeader: true, nilEncoding: "", trueEncoding: "true", falseEncoding: "false",
                  newline: "\n", delimiter: ",")
    }

    public init(includesHeader: Bool,
                nilEncoding: String,
                trueEncoding: String,
                falseEncoding: String,
                newline: String,
                delimiter: Character) {
        self.init(includesHeader: includesHeader, dateFormat: nil, nilEncoding: nilEncoding,
                  trueEncoding: trueEncoding, falseEncoding: falseEncoding, newline: "\n", delimiter: delimiter)
    }

    public init(includesHeader: Bool,
                dateFormat: String?,
                nilEncoding: String,
                trueEncoding: String,
                falseEncoding: String,
                newline: String,
                delimiter: Character) {
        self.includesHeader = includesHeader
        self.dateFormat = dateFormat
        self.dateFormatter = dateFormat.map { format in
            { date in
                CSVWritingOptions.formatter(format).string(from: date)
            }
        } ?? { date in
            CSVWritingOptions.formatter("yyyy-MM-dd'T'HH:mm:ss'Z'").string(from: date)
        }
        self.nilEncoding = nilEncoding
        self.trueEncoding = trueEncoding
        self.falseEncoding = falseEncoding
        self.newline = "\n"
        self.delimiter = delimiter
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

public enum CSVWritingError: Error, CustomStringConvertible {
    case badEncoding(row: Int, column: String, cellContents: Data)

    public var row: Int {
        switch self {
        case .badEncoding(let row, _, _): return row
        }
    }

    public var column: String {
        switch self {
        case .badEncoding(_, let column, _): return column
        }
    }

    public var description: String {
        switch self {
        case .badEncoding(let row, let column, let cellContents):
            return "Bad UTF8 encoding at row \(row) column '\(column)': \(Array(cellContents))."
        }
    }
}

extension DataFrame {
    public func csvRepresentation(options: CSVWritingOptions = CSVWritingOptions()) throws -> Data {
        var lines = [String]()
        if options.includesHeader && !columns.isEmpty {
            lines.append(columns.map(\.name).joined(separator: String(options.delimiter)))
        }
        let cells = try columns.map { try DataFrame.cellTexts($0, options: options) }
        let height = cells.map(\.count).max() ?? 0
        for row in 0..<height {
            let fields = cells.map { column -> String in
                row < column.count ? column[row] ?? options.nilEncoding : options.nilEncoding
            }
            lines.append(fields.joined(separator: String(options.delimiter)))
        }
        var text = ""
        for line in lines {
            text += line + options.newline
        }
        return Data(text.utf8)
    }

    public func writeCSV(to url: URL, options: CSVWritingOptions = CSVWritingOptions()) throws {
        try csvRepresentation(options: options).write(to: url)
    }

    private static func cellTexts(_ column: AnyColumn, options: CSVWritingOptions) throws -> [String?] {
        func texts<T>(_ typed: Column<T>, _ text: (T) -> String) -> [String?] {
            (0..<typed.count).map { row in typed[row].map(text) }
        }
        if let typed = column.assumingType(String.self) {
            return texts(typed) { quoted($0, options: options) }
        }
        if let typed = column.assumingType(Int.self) {
            return texts(typed) { "\($0)" }
        }
        if let typed = column.assumingType(Double.self) {
            return texts(typed) { "\($0)" }
        }
        if let typed = column.assumingType(Float.self) {
            return texts(typed) { "\($0)" }
        }
        if let typed = column.assumingType(Bool.self) {
            return texts(typed) { $0 ? options.trueEncoding : options.falseEncoding }
        }
        if let typed = column.assumingType(Date.self) {
            return texts(typed) { quoted(options.dateFormatter($0), options: options) }
        }
        if let typed = column.assumingType(Data.self) {
            var cells = [String?]()
            for row in 0..<typed.count {
                guard let data = typed[row] else {
                    cells.append(nil)
                    continue
                }
                guard let text = String(data: data, encoding: .utf8) else {
                    throw CSVWritingError.badEncoding(row: row, column: column.name, cellContents: data)
                }
                cells.append(quoted(text, options: options))
            }
            return cells
        }
        return (0..<column.count).map { row in column[row].map { quoted("\($0)", options: options) } }
    }

    private static func quoted(_ text: String, options: CSVWritingOptions) -> String {
        let needsQuotes = text.contains(options.delimiter) || text.contains("\"")
            || text.contains("\n") || text.contains("\r")
        guard needsQuotes else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
