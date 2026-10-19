// CSVWriting.swift - writing a DataFrame as CSV bytes, and the options and error that writing names.
//
// Measured on the host's TabularData with the same frames (csvwriting.swift runs both). A header is written
// raw: its names are not quoted or escaped. A cell is quoted when its text holds the delimiter, a quote, a
// line feed or a carriage return, and a quote inside it is doubled. A missing cell, and a cell of a shorter
// column, is the nil encoding. A date is formatted in UTC: by the default ISO 8601 formatter, or by the
// `dateFormat` the options were made with, which is read in UTC as well.

import Foundation

/// How a DataFrame is written as CSV. The defaults are the framework's.
public struct CSVWritingOptions {
    public var includesHeader: Bool
    /// The format a date cell is written in, when the options were made with one. Setting it does not set
    /// `dateFormatter`, which is the formatter that is used.
    public var dateFormat: String?
    /// The text of a date cell.
    public var dateFormatter: (Date) -> String
    /// The text of a missing cell.
    public var nilEncoding: String
    public var trueEncoding: String
    public var falseEncoding: String
    /// The text that ends each row.
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
        // The newline the caller names is not kept by this initialiser: measured, the host's options made
        // here write a line feed whatever `newline` says, and the property set afterwards is honoured.
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
        // Neither initialiser keeps `newline`: measured, both store a line feed for whatever is passed.
        self.newline = "\n"
        self.delimiter = delimiter
    }

    /// A formatter in UTC, in the POSIX locale, so the same date is the same text wherever the program runs.
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

/// Why a DataFrame could not be written as CSV. The row counts from 0 over the data rows, and the column
/// is the name of the column the cell is in: both measured on the host (csvwriting.swift).
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
    /// The frame written as CSV bytes. A frame with no columns writes nothing, and a header is written
    /// before the rows when the options say so.
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

    /// The frame written to a file as CSV.
    public func writeCSV(to url: URL, options: CSVWritingOptions = CSVWritingOptions()) throws {
        try csvRepresentation(options: options).write(to: url)
    }

    /// One column's cells as text, each quoted where the delimiter needs it; nil for a missing cell.
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
        // A column of a kind the writer does not know is written by its own description, as the other kinds are.
        return (0..<column.count).map { row in column[row].map { quoted("\($0)", options: options) } }
    }

    /// The text quoted the way CSV quotes it, when it holds the delimiter, a quote, or a line break.
    private static func quoted(_ text: String, options: CSVWritingOptions) -> String {
        let needsQuotes = text.contains(options.delimiter) || text.contains("\"")
            || text.contains("\n") || text.contains("\r")
        guard needsQuotes else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
