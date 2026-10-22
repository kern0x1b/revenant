import Foundation

public struct PresentationIntent: Hashable, Codable, CustomDebugStringConvertible, Sendable {
    public var components: [IntentType]

    public init(types: [IntentType]) {
        self.components = types
    }

    private enum CodingKeys: String, CodingKey {
        case components
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let types = try container.decode([IntentType].self, forKey: .components)
        guard !types.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .components, in: container,
                                                   debugDescription: "a presentation intent needs at least one component")
        }
        self.components = types
    }

    public var count: Int {
        return components.count
    }

    public var debugDescription: String {
        return components.debugDescription
    }

    public enum Kind: Hashable, Codable, CustomDebugStringConvertible, Sendable {
        case paragraph
        case header(level: Int)
        case orderedList
        case unorderedList
        case listItem(ordinal: Int)
        case codeBlock(languageHint: String?)
        case blockQuote
        case thematicBreak
        case table(columns: [TableColumn])
        case tableHeaderRow
        case tableRow(rowIndex: Int)
        case tableCell(columnIndex: Int)

        public var debugDescription: String {
            switch self {
            case .paragraph: return "paragraph"
            case .header(let level): return "header \(level)"
            case .orderedList: return "orderedList"
            case .unorderedList: return "unorderedList"
            case .listItem(let ordinal): return "listItem \(ordinal)"
            case .codeBlock(let hint): return "codeBlock '\(hint ?? "<none>")'"
            case .blockQuote: return "blockQuote"
            case .thematicBreak: return "thematicBreak"
            case .table(let columns): return "table \(columns)"
            case .tableHeaderRow: return "tableHeaderRow"
            case .tableRow(let row): return "tableRow \(row)"
            case .tableCell(let column): return "tableCell \(column)"
            }
        }

        public init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let name = try container.decode(String.self)
            switch name {
            case "paragraph": self = .paragraph
            case "header": self = .header(level: try container.decode(Int.self))
            case "orderedList": self = .orderedList
            case "unorderedList": self = .unorderedList
            case "listItem": self = .listItem(ordinal: try container.decode(Int.self))
            case "codeBlock":
                let hint: String?
                if try container.decodeNil() {
                    hint = nil
                } else {
                    hint = try container.decode(String.self)
                }
                self = .codeBlock(languageHint: hint)
            case "blockQuote": self = .blockQuote
            case "thematicBreak": self = .thematicBreak
            case "table": self = .table(columns: try container.decode([TableColumn].self))
            case "tableHeaderRow": self = .tableHeaderRow
            case "tableRow": self = .tableRow(rowIndex: try container.decode(Int.self))
            case "tableCell": self = .tableCell(columnIndex: try container.decode(Int.self))
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown presentation intent kind \(name)")
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.unkeyedContainer()
            switch self {
            case .paragraph: try container.encode("paragraph")
            case .header(let level):
                try container.encode("header")
                try container.encode(level)
            case .orderedList: try container.encode("orderedList")
            case .unorderedList: try container.encode("unorderedList")
            case .listItem(let ordinal):
                try container.encode("listItem")
                try container.encode(ordinal)
            case .codeBlock(let hint):
                try container.encode("codeBlock")
                if let hint {
                    try container.encode(hint)
                } else {
                    try container.encodeNil()
                }
            case .blockQuote: try container.encode("blockQuote")
            case .thematicBreak: try container.encode("thematicBreak")
            case .table(let columns):
                try container.encode("table")
                try container.encode(columns)
            case .tableHeaderRow: try container.encode("tableHeaderRow")
            case .tableRow(let row):
                try container.encode("tableRow")
                try container.encode(row)
            case .tableCell(let column):
                try container.encode("tableCell")
                try container.encode(column)
            }
        }

        fileprivate var tag: Tag {
            switch self {
            case .paragraph: return .paragraph
            case .header: return .header
            case .orderedList: return .orderedList
            case .unorderedList: return .unorderedList
            case .listItem: return .listItem
            case .codeBlock: return .codeBlock
            case .blockQuote: return .blockQuote
            case .thematicBreak: return .thematicBreak
            case .table: return .table
            case .tableHeaderRow: return .tableHeaderRow
            case .tableRow: return .tableRow
            case .tableCell: return .tableCell
            }
        }
    }

    public struct TableColumn: Hashable, Codable, Sendable {
        public enum Alignment: Int, Hashable, Codable, Sendable {
            case left
            case center
            case right
        }

        public var alignment: Alignment

        public init(alignment: Alignment) {
            self.alignment = alignment
        }
    }

    public struct IntentType: Hashable, Codable, CustomDebugStringConvertible, Sendable {
        public var kind: Kind
        public var identity: Int

        public var debugDescription: String {
            return "\(kind.debugDescription) (id \(identity))"
        }
    }

    public init(_ kind: Kind, identity: Int, parent: PresentationIntent? = nil) {
        self.components = [IntentType(kind: kind, identity: identity)] + (parent?.components ?? [])
    }

    public var isValid: Bool {
        guard let innermost = components.first, let outermost = components.last else {
            return false
        }
        if !Tag.holdsContent(innermost.kind.tag) || !Tag.mayBeOutermost(outermost.kind.tag) {
            return false
        }
        for index in 0..<(components.count - 1) {
            if !Tag.allows(components[index].kind.tag, inside: components[index + 1].kind.tag) {
                return false
            }
        }
        return true
    }

    public var indentationLevel: Int {
        return components.reduce(0) { level, component in
            switch component.kind {
            case .listItem, .blockQuote: return level + 1
            default: return level
            }
        }
    }

    public static func == (a: PresentationIntent, b: PresentationIntent) -> Bool {
        return a.components == b.components
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(components)
    }
}

fileprivate enum Tag: Hashable {
    case paragraph, header, orderedList, unorderedList, listItem, codeBlock, blockQuote, thematicBreak
    case table, tableHeaderRow, tableRow, tableCell

    static func holdsContent(_ tag: Tag) -> Bool {
        switch tag {
        case .orderedList, .unorderedList, .table, .tableHeaderRow, .tableRow: return false
        default: return true
        }
    }

    static func mayBeOutermost(_ tag: Tag) -> Bool {
        switch tag {
        case .listItem, .tableHeaderRow, .tableRow, .tableCell: return false
        default: return true
        }
    }

    static func allows(_ child: Tag, inside parent: Tag) -> Bool {
        switch child {
        case .paragraph, .header, .codeBlock, .thematicBreak, .blockQuote:
            return parent == .blockQuote || parent == .header || parent == .paragraph || parent == .listItem
        case .orderedList, .unorderedList:
            return parent == .blockQuote || parent == .paragraph || parent == .header
        case .table:
            return parent == .blockQuote
        case .listItem:
            return parent == .orderedList || parent == .unorderedList
        case .tableHeaderRow, .tableRow:
            return parent == .table
        case .tableCell:
            return parent == .tableHeaderRow || parent == .tableRow
        }
    }
}

extension PresentationIntent: _ObjectiveCBridgeable {
    public typealias _ObjectiveCType = __NSPresentationIntent

    public func _bridgeToObjectiveC() -> __NSPresentationIntent {
        var nested: __NSPresentationIntent? = nil
        for component in components.reversed() {
            nested = component.objectiveC(nestedInside: nested)
        }
        guard let innermost = nested else {
            fatalError("a PresentationIntent without components has no NSPresentationIntent")
        }
        return innermost
    }

    public static func _forceBridgeFromObjectiveC(_ source: __NSPresentationIntent, result: inout PresentationIntent?) {
        result = PresentationIntent(objectiveC: source)
    }

    public static func _conditionallyBridgeFromObjectiveC(_ source: __NSPresentationIntent, result: inout PresentationIntent?) -> Bool {
        result = PresentationIntent(objectiveC: source)
        return true
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ source: __NSPresentationIntent?) -> PresentationIntent {
        guard let source else {
            return PresentationIntent(types: [])
        }
        return PresentationIntent(objectiveC: source)
    }

    fileprivate init(objectiveC innermost: __NSPresentationIntent) {
        var types: [IntentType] = []
        var node: __NSPresentationIntent? = innermost
        while let current = node {
            types.append(IntentType(kind: Kind(objectiveC: current), identity: current.integer(forKey: "identity")))
            node = current.parent
        }
        self.init(types: types)
    }
}

extension PresentationIntent.IntentType {
    fileprivate func objectiveC(nestedInside parent: __NSPresentationIntent?) -> __NSPresentationIntent {
        switch kind {
        case .paragraph:
            return __NSPresentationIntent.paragraphIntent(withIdentity: identity, nestedInside: parent)
        case .header(let level):
            return __NSPresentationIntent.headerIntent(withIdentity: identity, level: level, nestedInside: parent)
        case .orderedList:
            return __NSPresentationIntent.orderedListIntent(withIdentity: identity, nestedInside: parent)
        case .unorderedList:
            return __NSPresentationIntent.unorderedListIntent(withIdentity: identity, nestedInside: parent)
        case .listItem(let ordinal):
            return __NSPresentationIntent.listItemIntent(withIdentity: identity, ordinal: ordinal, nestedInside: parent)
        case .codeBlock(let hint):
            return __NSPresentationIntent.codeBlockIntent(withIdentity: identity, languageHint: hint, nestedInside: parent)
        case .blockQuote:
            return __NSPresentationIntent.blockQuoteIntent(withIdentity: identity, nestedInside: parent)
        case .thematicBreak:
            return __NSPresentationIntent.thematicBreak(withIdentity: identity, nestedInside: parent)
        case .table(let columns):
            let alignments = columns.map { NSNumber(value: $0.alignment.rawValue) }
            return __NSPresentationIntent.tableIntent(withIdentity: identity, columnCount: columns.count, alignments: alignments, nestedInside: parent)
        case .tableHeaderRow:
            return __NSPresentationIntent.tableHeaderRowIntent(withIdentity: identity, nestedInside: parent)
        case .tableRow(let row):
            return __NSPresentationIntent.tableRowIntent(withIdentity: identity, row: row, nestedInside: parent)
        case .tableCell(let column):
            return __NSPresentationIntent.tableCellIntent(withIdentity: identity, column: column, nestedInside: parent)
        }
    }
}

extension PresentationIntent.Kind {
    fileprivate init(objectiveC node: __NSPresentationIntent) {
        switch node.intentKind.rawValue {
        case 0: self = .paragraph
        case 1: self = .header(level: node.integer(forKey: "headerLevel"))
        case 2: self = .orderedList
        case 3: self = .unorderedList
        case 4: self = .listItem(ordinal: node.integer(forKey: "ordinal"))
        case 5: self = .codeBlock(languageHint: node.value(forKey: "languageHint") as? String)
        case 6: self = .blockQuote
        case 7: self = .thematicBreak
        case 8:
            let alignments = node.value(forKey: "columnAlignments") as? [NSNumber] ?? []
            self = .table(columns: alignments.map { PresentationIntent.TableColumn(alignment: PresentationIntent.TableColumn.Alignment(rawValue: $0.intValue) ?? .left) })
        case 9: self = .tableHeaderRow
        case 10: self = .tableRow(rowIndex: node.integer(forKey: "row"))
        default: self = .tableCell(columnIndex: node.integer(forKey: "column"))
        }
    }
}

extension __NSPresentationIntent {
    fileprivate func integer(forKey key: String) -> Int {
        return (value(forKey: key) as? NSNumber)?.intValue ?? 0
    }
}
