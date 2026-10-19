// MLDataTable+CSV.swift — reading a table from a CSV, and writing one back.
//
// The reader implements the options the framework's `MLDataTable.ParsingOptions` and the surface's
// `CSVReadingOptions` name, because a reader that silently ignored them would answer a different
// question from the one the caller asked: a file with a comment character in it is a different file
// depending on whether the comment is honoured.
//
// The type inference is the framework's: a column whose every non-missing cell is an integer is an
// integer column, a column whose every cell parses as a double is a double column, and a column with
// anything else in it is a string column. A column is never a mixture, and a cell that does not
// parse is missing rather than a string in a numeric column — which is what makes `dropMissing()`
// mean what it says.

import Foundation

/// How a CSV is read.
public struct MLDataTableParsingOptions {
    /// Whether the first row names the columns. A file without a header is read with the columns
    /// named by their position, as the framework names them.
    public var containsHeader: Bool
    public var delimiter: Character
    public var comment: Character?
    /// The escape inside a quoted field: a doubled quote, by CSV's own rule.
    public var doubleQuote: Bool
    public var quote: Character?
    public var skipInitialSpaces: Bool
    /// The strings that stand for a missing value. The empty string is among them, and not by
    /// accident: a file that leaves a cell empty means it, and reading it as `""` would make an empty
    /// category out of a gap.
    public var missingValues: Set<String>
    public var lineTerminator: String
    public var selectColumns: [String]?
    public var maxRows: Int?
    public var skipRows: Int

    public init(containsHeader: Bool = true,
                delimiter: Character = ",",
                comment: Character? = nil,
                escape: Character? = nil,
                doubleQuote: Bool = true,
                quote: Character? = "\"",
                skipInitialSpaces: Bool = false,
                // No empty string, and the omission is measured rather than a slip: the host's own
                // reader on a file whose second cell is empty gives that column the two *strings*
                // `""` and `"x"` and `dropMissing()` keeps both rows. An empty cell in a CSV is a
                // value the writer wrote, and the reader that invents a gap there is the reader
                // that loses it.
                missingValues: Set<String> = ["NA", "N/A", "null", "NaN", "nan", "-"],
                lineTerminator: String = "\n",
                selectColumns: [String]? = nil,
                maxRows: Int? = nil,
                skipRows: Int = 0) {
        self.containsHeader = containsHeader
        self.delimiter = delimiter
        self.comment = comment
        self.doubleQuote = doubleQuote
        self.quote = quote
        self.skipInitialSpaces = skipInitialSpaces
        self.missingValues = missingValues
        self.lineTerminator = lineTerminator
        self.selectColumns = selectColumns
        self.maxRows = maxRows
        self.skipRows = skipRows
        // The escape is the character a quoted field's own quote is written behind; with `nil` there
        // is no escape and a doubled quote is what a doubled quote is. Kept as a stored value so the
        // reader reads one flag rather than two spellings of the same question.
        self.escape = escape
    }

    public var escape: Character?
}

extension MLDataTable {
    /// A table read from a CSV at a URL.
    ///
    /// Every option the parser's own names say is honoured, and the ones that change which cells
    /// exist are the ones that are checked: the delimiter, the comment character, the header, the
    /// skipped rows, the row limit and the missing values. A file whose rows disagree about how many
    /// fields they have is refused with the row number rather than padded, because a padded row is a
    /// row of values nobody wrote.
    public init(contentsOf url: URL, options: MLDataTableParsingOptions = MLDataTableParsingOptions()) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        try self.init(csv: text, options: options)
    }

    /// A table read from CSV text.
    public init(csv text: String, options: MLDataTableParsingOptions = MLDataTableParsingOptions()) throws {
        var lines = MLDataTable.splitLines(text, terminator: options.lineTerminator)
        if let comment = options.comment {
            lines = lines.filter { !$0.hasPrefix(String(comment)) }
        }
        if options.skipRows > 0 {
            lines = Array(lines.dropFirst(Swift.min(options.skipRows, lines.count)))
        }
        guard !lines.isEmpty else {
            self.init()
            return
        }

        let first = try MLDataTable.splitFields(lines[0], options: options)
        let names: [String]
        var body: ArraySlice<String>
        if options.containsHeader {
            names = options.selectColumns ?? first
            body = lines[1...]
        } else {
            // A file with no header is read with the columns named by their position, because a
            // caller who wants names has to be able to say which is which.
            names = options.selectColumns ?? (0..<first.count).map { "column\($0)" }
            body = lines[...]
        }
        // A file with a header may be read in part: `selectColumns` names the columns the caller
        // wants, and the rest of the file is not read into a table. Without a header the same list
        // names columns the file has not got, and is refused rather than read as empty columns.
        var kept = names
        if let selected = options.selectColumns {
            guard options.containsHeader else {
                throw MLDataTableError.noSuchColumn(selected.joined(separator: ", "))
            }
            kept = selected
        }
        var values = [String: [String?]]()
        for name in kept { values[name] = [] }
        var read = 0
        for line in body {
            if line.isEmpty && body.count > 1 { continue }
            if let limit = options.maxRows, read >= limit { break }
            let fields = try MLDataTable.splitFields(line, options: options)
            // A row of a different width than the header is a file error, not a row to pad: padding
            // it would put values in cells the file did not have.
            guard fields.count == first.count else {
                throw MLDataTableError.badCSVRow(read + 1, line)
            }
            for (position, name) in kept.enumerated() where position < fields.count {
                values[name]?.append(options.missingValues.contains(fields[position]) ? nil : fields[position])
            }
            read += 1
        }
        self.init()
        for name in kept {
            guard let cells = values[name] else { continue }
            addColumn(MLUntypedColumn(MLDataTable.typedColumn(cells), name: name), named: name)
        }
    }

    /// The framework's own reading options, in the type the surface names.
    public typealias ParsingOptions = MLDataTableParsingOptions

    /// A line's fields, with the quoting and escaping the options name.
    private static func splitFields(_ line: String, options: MLDataTableParsingOptions) throws -> [String] {
        var fields = [String]()
        var field = ""
        var quoted = false
        var characters = Array(line)
        var index = 0
        if options.skipInitialSpaces {
            while index < characters.count, characters[index] == " " { index += 1 }
        }
        while index < characters.count {
            let character = characters[index]
            if let quote = options.quote, character == quote {
                // The doubled quote is one quote, and only inside a quoted field — the same rule the
                // line splitter applies, for the same reason.
                if quoted, index + 1 < characters.count, characters[index + 1] == quote, options.doubleQuote {
                    // A doubled quote inside a quoted field is one quote, which is CSV's own rule and
                    // not an escape character: the field says what it says.
                    field.append(quote)
                    index += 2
                    continue
                }
                if let escape = options.escape, quoted, index + 1 < characters.count, characters[index + 1] == escape {
                    index += 1
                    let next = index + 1 < characters.count ? String(characters[index + 1]) : ""
                    field.append(next)
                    index += 2
                    continue
                }
                quoted.toggle()
                index += 1
                continue
            }
            if !quoted, character == options.delimiter {
                fields.append(field)
                field = ""
                index += 1
                if options.skipInitialSpaces {
                    while index < characters.count, characters[index] == " " { index += 1 }
                }
                continue
            }
            field.append(character)
            index += 1
        }
        if quoted {
            throw MLDataTableError.badCSVRow(0, line)
        }
        fields.append(field)
        return fields
    }

    private static func splitLines(_ text: String, terminator: String) -> [String] {
        var lines = [String]()
        var current = ""
        var inQuotes = false
        let characters = Array(text)
        let terminatorCharacters = Set(terminator)
        var index = 0
        while index < characters.count {
            // A field may hold the terminator inside quotes, so this split reads the quoting too: a
            // naive split on newlines cuts a quoted field in half and then reports a row of the
            // wrong width, which is a file error that is not in the file.
            // A doubled quote is one quote, and only *inside* a quoted field: outside one, two
            // quotes are an empty quoted field followed by the start of another, and consuming them
            // as one leaves the reader inside a string for the rest of the file. The host's reader
            // found this one — a field whose text ends in a doubled quote swallowed every line
            // after it.
            if inQuotes, characters[index] == "\"", index + 1 < characters.count,
               characters[index + 1] == "\"" {
                current.append("\"\"")
                index += 2
                continue
            }
            if characters[index] == "\"" {
                inQuotes.toggle()
                current.append(characters[index])
                index += 1
                continue
            }
            if !inQuotes, terminatorCharacters.contains(characters[index]) {
                lines.append(current)
                current = ""
                index += 1
                continue
            }
            current.append(characters[index])
            index += 1
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    /// A column of strings read as the kind its cells all agree on, and a string column when they do
    /// not. A cell that does not parse is missing, not a string, so a numeric column never holds a
    /// word and `dropMissing()` means what it says.
    private static func typedColumn(_ cells: [String?]) -> [MLDataValue] {
        let present = cells.compactMap { $0 }
        guard !present.isEmpty else { return cells.map { $0 == nil ? .invalid : .string($0!) } }
        if present.allSatisfy({ Int64($0) != nil }) {
            return cells.map { cell in
                guard let cell = cell, let value = Int64(cell) else { return .invalid }
                return .int(value)
            }
        }
        if present.allSatisfy({ Double($0) != nil }) {
            return cells.map { cell in
                guard let cell = cell, let value = Double(cell) else { return .invalid }
                return .double(value)
            }
        }
        return cells.map { cell in
            guard let cell = cell else { return .invalid }
            return .string(cell)
        }
    }

    /// The table written as CSV text, with a header row of the column names.
    public func csvText() -> String {
        var lines = [columnNames.joined(separator: ",")]
        for row in 0..<count {
            let fields = columnNames.map { name -> String in
                switch columns[name]?[row] {
                case .some(.invalid), .none: return ""
                case .some(.int(let value)): return "\(value)"
                case .some(.double(let value)): return "\(value)"
                case .some(.string(let value)): return value.contains(",") ? "\"\(value)\"" : value
                case .some(.sequence(let values)): return values.map(\.description).joined(separator: " ")
                case .some(.dictionary(let storage)):
                    return storage.keys.sorted().map { "\($0)=\(storage[$0]!.description)" }.joined(separator: " ")
                case .some(.multiArray(let array)): return array.description
                }
            }
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The table written as a CSV at a URL, with the writing options the surface names.
    public func writeCSV(to url: URL) throws {
        try csvText().write(to: url, atomically: true, encoding: .utf8)
    }

    /// The table written as a CSV at a path.
    public func writeCSV(toFile path: String) throws {
        try writeCSV(to: URL(fileURLWithPath: path))
    }

    /// The table written as JSON: an array of objects, one per row, keyed by column name.
    ///
    /// Row-major, because a table read back has to have its rows in the order they were written and
    /// a column-major document would not keep that without a separate index.
    public func jsonText() -> String {
        var out = "["
        for (rowIndex, row) in rows.enumerated() {
            if rowIndex > 0 { out += "," }
            out += "{"
            var first = true
            for name in columnNames {
                if !first { out += "," }
                first = false
                let value = row[name] ?? .invalid
                out += "\"\(escape(name))\":\(value.jsonLiteral)"
            }
            out += "}"
        }
        return out + "]"
    }

    /// The table read from JSON: an array of objects, one per row.
    public init(json text: String) throws {
        self.init()
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            throw MLDataTableError.unreadableFile("<json>")
        }
        guard let objects = root as? [[String: Any]] else {
            throw MLDataTableError.unreadableFile("<json>")
        }
        var names = [String]()
        for object in objects {
            for name in object.keys.sorted() where !names.contains(name) { names.append(name) }
        }
        for name in names {
            let values = objects.map { object -> MLDataValue in
                guard let value = object[name] else { return .invalid }
                if let double = value as? Double { return .double(double) }
                if let int = value as? Int { return .int(Int64(int)) }
                if let bool = value as? Bool { return .int(bool ? 1 : 0) }
                if let string = value as? String { return .string(string) }
                if value is NSNull { return .invalid }
                return .string("\(value)")
            }
            addColumn(MLUntypedColumn(values, name: name), named: name)
        }
    }

    /// The table read from a JSON file.
    public init(json url: URL) throws {
        try self.init(json: try String(contentsOf: url, encoding: .utf8))
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

extension MLDataValue {
    /// A value as the JSON text for it, and the spelling each kind has there: an integer and a
    /// double both go out as JSON numbers, and a value that is not a number goes out as a string or
    /// as null, which is the only choice JSON leaves.
    var jsonLiteral: String {
        switch self {
        case .invalid: return "null"
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .string(let value):
            return "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
        case .sequence(let values): return "[" + values.map(\.jsonLiteral).joined(separator: ",") + "]"
        case .dictionary(let storage):
            return "{" + storage.keys.sorted().map { key in
                "\"\(key)\":\(storage[key]!.jsonLiteral)"
            }.joined(separator: ",") + "}"
        case .multiArray(let array): return "[" + array.data.map { "\($0)" }.joined(separator: ",") + "]"
        }
    }
}
