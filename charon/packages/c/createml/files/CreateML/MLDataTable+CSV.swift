import Foundation

public struct MLDataTableParsingOptions {
    public var containsHeader: Bool
    public var delimiter: Character
    public var comment: Character?
    public var doubleQuote: Bool
    public var quote: Character?
    public var skipInitialSpaces: Bool
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
        self.escape = escape
    }

    public var escape: Character?
}

extension MLDataTable {
    public init(contentsOf url: URL, options: MLDataTableParsingOptions = MLDataTableParsingOptions()) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        try self.init(csv: text, options: options)
    }

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
            names = options.selectColumns ?? (0..<first.count).map { "column\($0)" }
            body = lines[...]
        }
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

    public typealias ParsingOptions = MLDataTableParsingOptions

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
                if quoted, index + 1 < characters.count, characters[index + 1] == quote, options.doubleQuote {
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

    public func writeCSV(to url: URL) throws {
        try csvText().write(to: url, atomically: true, encoding: .utf8)
    }

    public func writeCSV(toFile path: String) throws {
        try writeCSV(to: URL(fileURLWithPath: path))
    }

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

    public init(json url: URL) throws {
        try self.init(json: try String(contentsOf: url, encoding: .utf8))
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

extension MLDataValue {
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
