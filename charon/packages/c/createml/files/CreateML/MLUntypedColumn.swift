import Foundation

public enum MLColumnError: Error, CustomStringConvertible, Equatable {
    case wrongType(requested: MLDataValue.ValueType, found: MLDataValue.ValueType)
    case notNumeric(String)
    case empty
    case mixedTypes(MLDataValue.ValueType, MLDataValue.ValueType)

    public var description: String {
        switch self {
        case .wrongType(let requested, let found):
            return "The column holds \(found.description) values, not \(requested.description)."
        case .notNumeric(let name):
            return "The column \"\(name)\" holds strings, and a number was asked for."
        case .empty:
            return "The column is empty."
        case .mixedTypes(let first, let second):
            return "The column holds both \(first.description) and \(second.description) values."
        }
    }
}

public struct MLUntypedColumn: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public internal(set) var name: String
    public private(set) var values: [MLDataValue]
    public private(set) var error: MLColumnError?

    public private(set) var type: MLDataValue.ValueType

    public init() {
        name = ""
        values = []
        type = .invalid
    }

    public init(_ values: [MLDataValue], name: String = "") {
        self.name = name
        self.values = values
        self.type = .invalid
        settle()
    }

    public init(name: String, _ values: [MLDataValue]) {
        self.name = name
        self.values = values
        self.type = .invalid
        settle()
    }

    public init<S: Sequence>(_ source: S) where S.Element == MLDataValue {
        self.init(Array(source))
    }

    public init<S: Sequence>(_ source: S) where S.Element: MLDataValueConvertible {
        var out = [MLDataValue]()
        out.reserveCapacity(source.underestimatedCount)
        for element in source { out.append(element.dataValue) }
        self.init(out)
    }

    public init(_ range: Range<Int>) {
        self.init(range.map { MLDataValue.int(Int64($0)) })
    }

    public init(_ range: ClosedRange<Int>) {
        self.init(range.map { MLDataValue.int(Int64($0)) })
    }

    public init(repeating repeatedValue: MLDataValue, count: Int) {
        self.init([MLDataValue](repeating: repeatedValue, count: count))
    }

    public init<T: MLDataValueConvertible>(repeating repeatedValue: T, count: Int) {
        self.init([MLDataValue](repeating: repeatedValue.dataValue, count: count))
    }

    public init(ints column: MLUntypedColumn) { self.init(column, convertingTo: .int) }
    public init(doubles column: MLUntypedColumn) { self.init(column, convertingTo: .double) }
    public init(strings column: MLUntypedColumn) { self.init(column, convertingTo: .string) }
    public init(sequences column: MLUntypedColumn) { self.init(column, convertingTo: .sequence) }
    public init(dictionaries column: MLUntypedColumn) { self.init(column, convertingTo: .dictionary) }
    public init(multiArrays column: MLUntypedColumn) { self.init(column, convertingTo: .multiArray) }

    private init(_ column: MLUntypedColumn, convertingTo wanted: MLDataValue.ValueType) {
        self.name = column.name
        var out = [MLDataValue](repeating: .invalid, count: column.count)
        for (index, value) in column.values.enumerated() {
            switch wanted {
            case .int: out[index] = value.intValue.map(MLDataValue.int) ?? .invalid
            case .double: out[index] = value.doubleValue.map(MLDataValue.double) ?? .invalid
            case .string: out[index] = value.stringValue.map(MLDataValue.string) ?? .invalid
            default:
                out[index] = value.type == wanted ? value : .invalid
            }
        }
        self.values = out
        self.type = .invalid
        settle()
    }

    private mutating func settle() {
        var found: MLDataValue.ValueType?
        for value in values {
            guard value.isValid else { continue }
            if let found = found, found != value.type {
                error = .mixedTypes(found, value.type)
                type = .invalid
                return
            }
            found = value.type
        }
        error = nil
        type = found ?? .invalid
    }

    public var count: Int { values.count }
    public var isEmpty: Bool { values.isEmpty }

    public var isValid: Bool { error == nil }

    public subscript(index: Int) -> MLDataValue { values[index] }

    public subscript(slice: Range<Int>) -> MLUntypedColumn {
        MLUntypedColumn(Array(values[slice]), name: name)
    }

    public subscript(mask: MLUntypedColumn) -> MLUntypedColumn {
        MLUntypedColumn(zip(values, mask.values).compactMap { row, keep in
            keep.intValue.map { _ in row }
        }, name: name)
    }

    public subscript(mask: MLDataColumn<Bool>) -> MLUntypedColumn {
        MLUntypedColumn(zip(values, mask.values).compactMap { row, keep in
            keep ? row : nil
        }, name: name)
    }

    public var ints: MLDataColumn<Int>? { column(type: Int.self) }
    public var doubles: MLDataColumn<Double>? { column(type: Double.self) }
    public var strings: MLDataColumn<String>? { column(type: String.self) }
    public var sequences: MLDataColumn<MLDataValue.SequenceType>? {
        MLDataColumn(values.map { value -> MLDataValue.SequenceType in
            if case .sequence(let elements) = value { return MLDataValue.SequenceType(elements) }
            return MLDataValue.SequenceType()
        }, name: name)
    }

    public var dictionaries: MLDataColumn<MLDataValue.DictionaryType>? {
        MLDataColumn(values.map { value -> MLDataValue.DictionaryType in
            if case .dictionary(let storage) = value { return MLDataValue.DictionaryType(storage) }
            return MLDataValue.DictionaryType()
        }, name: name)
    }

    public var multiArrays: MLDataColumn<MLDataValue.MultiArrayType>? {
        MLDataColumn(values.map { value -> MLDataValue.MultiArrayType in
            if case .multiArray(let array) = value { return array }
            return MLDataValue.MultiArrayType([Double]())
        }, name: name)
    }

    public func column<T: MLDataValueConvertible>(type: T.Type) -> MLDataColumn<T>? {
        if self.type != .invalid, self.type != T.dataValueType { return nil }
        var out = [T]()
        out.reserveCapacity(values.count)
        for value in values {
            out.append(T(from: value) ?? T())
        }
        return MLDataColumn(out, name: name)
    }

    public func map<T: MLDataValueConvertible>(_ transform: (MLDataValue) -> T) -> MLDataColumn<T> {
        MLDataColumn<T>(values.map(transform), name: name)
    }

    public func map<T: MLDataValueConvertible>(_ transform: (MLDataValue) -> T?) -> MLDataColumn<T> {
        MLDataColumn<T>(values.map { transform($0) ?? T() }, name: name)
    }

    public func map<T: MLDataValueConvertible>(to type: T.Type) -> MLDataColumn<T> {
        map { value in T(from: value) ?? T() }
    }

    public func mapMissing<T: MLDataValueConvertible>(_ transform: (MLDataValue) -> T?) -> MLDataColumn<T> {
        map { value in value.isValid ? (transform(value) ?? T()) : T() }
    }

    public mutating func append(contentsOf other: MLUntypedColumn) {
        values.append(contentsOf: other.values)
        settle()
    }

    public func copy() -> MLUntypedColumn { self }

    public func dropMissing() -> MLUntypedColumn {
        MLUntypedColumn(values.filter { $0.isValid }, name: name)
    }

    public func fillMissing(with value: MLDataValue) -> MLUntypedColumn {
        MLUntypedColumn(values.map { $0.isValid ? $0 : value }, name: name)
    }

    public func dropDuplicates() -> MLUntypedColumn {
        var seen = Set<MLDataValue>()
        return MLUntypedColumn(values.filter { seen.insert($0).inserted }, name: name)
    }

    public func sort(byIncreasingOrder: Bool = true) -> MLUntypedColumn {
        let sorted: [MLDataValue]
        switch type {
        case .int, .double, .string:
            sorted = values.sorted { byIncreasingOrder ? compare($0, $1) < 0 : compare($0, $1) > 0 }
        default:
            return self
        }
        return MLUntypedColumn(sorted, name: name)
    }

    private func compare(_ lhs: MLDataValue, _ rhs: MLDataValue) -> Int {
        if let a = lhs.intValue, let b = rhs.intValue { return a < b ? -1 : (a > b ? 1 : 0) }
        if let a = lhs.doubleValue, let b = rhs.doubleValue { return a < b ? -1 : (a > b ? 1 : 0) }
        if let a = lhs.stringValue, let b = rhs.stringValue { return a < b ? -1 : (a > b ? 1 : 0) }
        return 0
    }

    public func prefix(_ maxLength: Int = 10) -> MLUntypedColumn {
        MLUntypedColumn(Array(values[0..<Swift.min(maxLength, values.count)]), name: name)
    }

    public func suffix(_ maxLength: Int = 10) -> MLUntypedColumn {
        MLUntypedColumn(Array(values[Swift.max(0, values.count - maxLength)...]), name: name)
    }

    public func materialize() throws -> MLUntypedColumn { self }

    public var description: String {
        let shown = values.prefix(10).map { $0.description }.joined(separator: ", ")
        return values.count > 10 ? "\(shown), ... (\(values.count) values)" : shown
    }

    public var debugDescription: String {
        let kind = self.type
        return "\(kind)[\(count)]: \(description)"
    }
    public var customMirror: String { debugDescription }
    public var playgroundDescription: Any { debugDescription }
}

extension MLUntypedColumn {
    public static func == (lhs: MLUntypedColumn, rhs: MLUntypedColumn) -> Bool {
        lhs.values == rhs.values
    }
}

extension MLUntypedColumn {
    public static func < (lhs: MLUntypedColumn, rhs: MLDataValue) -> Bool { compare(lhs, rhs) < 0 }
    public static func <= (lhs: MLUntypedColumn, rhs: MLDataValue) -> Bool { compare(lhs, rhs) <= 0 }
    public static func > (lhs: MLUntypedColumn, rhs: MLDataValue) -> Bool { compare(lhs, rhs) > 0 }
    public static func >= (lhs: MLUntypedColumn, rhs: MLDataValue) -> Bool { compare(lhs, rhs) >= 0 }

    public static func < (lhs: MLUntypedColumn, rhs: Int64) -> Bool { lhs < MLDataValue.int(rhs) }
    public static func <= (lhs: MLUntypedColumn, rhs: Int64) -> Bool { lhs <= MLDataValue.int(rhs) }
    public static func > (lhs: MLUntypedColumn, rhs: Int64) -> Bool { lhs > MLDataValue.int(rhs) }
    public static func >= (lhs: MLUntypedColumn, rhs: Int64) -> Bool { lhs >= MLDataValue.int(rhs) }

    public static func < (lhs: MLUntypedColumn, rhs: Int) -> Bool { lhs < MLDataValue.int(Int64(rhs)) }
    public static func <= (lhs: MLUntypedColumn, rhs: Int) -> Bool { lhs <= MLDataValue.int(Int64(rhs)) }
    public static func > (lhs: MLUntypedColumn, rhs: Int) -> Bool { lhs > MLDataValue.int(Int64(rhs)) }
    public static func >= (lhs: MLUntypedColumn, rhs: Int) -> Bool { lhs >= MLDataValue.int(Int64(rhs)) }

    public static func < (lhs: MLUntypedColumn, rhs: Double) -> Bool { lhs < MLDataValue.double(rhs) }
    public static func <= (lhs: MLUntypedColumn, rhs: Double) -> Bool { lhs <= MLDataValue.double(rhs) }
    public static func > (lhs: MLUntypedColumn, rhs: Double) -> Bool { lhs > MLDataValue.double(rhs) }
    public static func >= (lhs: MLUntypedColumn, rhs: Double) -> Bool { lhs >= MLDataValue.double(rhs) }

    public static func < (lhs: MLUntypedColumn, rhs: String) -> Bool { lhs < MLDataValue.string(rhs) }
    public static func <= (lhs: MLUntypedColumn, rhs: String) -> Bool { lhs <= MLDataValue.string(rhs) }
    public static func > (lhs: MLUntypedColumn, rhs: String) -> Bool { lhs > MLDataValue.string(rhs) }
    public static func >= (lhs: MLUntypedColumn, rhs: String) -> Bool { lhs >= MLDataValue.string(rhs) }

    public static func < (lhs: MLUntypedColumn, rhs: MLUntypedColumn) -> Bool {
        for (a, b) in zip(lhs.values, rhs.values) where a != b {
            return MLUntypedColumn([a]) < MLDataValue.compareValues(a, b)
        }
        return lhs.count < rhs.count
    }

    static func compare(_ lhs: MLUntypedColumn, _ rhs: MLDataValue) -> Int {
        for value in lhs.values {
            return MLDataValue.compareValues(value, rhs)
        }
        return 0
    }

    public static func != (lhs: MLUntypedColumn, rhs: MLUntypedColumn) -> Bool { !(lhs == rhs) }

    public static func + (lhs: MLUntypedColumn, rhs: Double) -> MLUntypedColumn {
        arithmetic(lhs, rhs.dataValue, +)
    }
    public static func - (lhs: MLUntypedColumn, rhs: Double) -> MLUntypedColumn {
        arithmetic(lhs, rhs.dataValue, -)
    }
    public static func * (lhs: MLUntypedColumn, rhs: Double) -> MLUntypedColumn {
        arithmetic(lhs, rhs.dataValue, *)
    }
    public static func / (lhs: MLUntypedColumn, rhs: Double) -> MLUntypedColumn {
        arithmetic(lhs, rhs.dataValue, /)
    }
    public static func + (lhs: MLUntypedColumn, rhs: Int) -> MLUntypedColumn {
        arithmetic(lhs, .int(Int64(rhs)), +)
    }
    public static func - (lhs: MLUntypedColumn, rhs: Int) -> MLUntypedColumn {
        arithmetic(lhs, .int(Int64(rhs)), -)
    }
    public static func * (lhs: MLUntypedColumn, rhs: Int) -> MLUntypedColumn {
        arithmetic(lhs, .int(Int64(rhs)), *)
    }
    public static func / (lhs: MLUntypedColumn, rhs: Int) -> MLUntypedColumn {
        arithmetic(lhs, .int(Int64(rhs)), /)
    }

    private static func arithmetic(_ lhs: MLUntypedColumn, _ rhs: MLDataValue,
                                   _ operation: (Double, Double) -> Double) -> MLUntypedColumn {
        MLUntypedColumn(lhs.values.map { value in
            guard let a = value.doubleValue, let b = rhs.doubleValue else { return .invalid }
            return .double(operation(a, b))
        }, name: lhs.name)
    }
}

public struct MLDataColumn<Element>: CustomStringConvertible, CustomDebugStringConvertible {
    public private(set) var name: String
    public private(set) var values: [Element]
    public private(set) var error: MLColumnError?

    public init() {
        name = ""
        values = []
    }

    public init(_ values: [Element], name: String = "") {
        self.name = name
        self.values = values
    }

    public init<S: Sequence>(_ source: S) where Element == S.Element {
        self.init(Array(source))
    }

    public init(repeating repeatedValue: Element, count: Int) {
        self.init([Element](repeating: repeatedValue, count: count))
    }

    public init(_ column: MLDataColumn<Element>) {
        self.init(column.values, name: column.name)
    }


    public var count: Int { values.count }
    public var isEmpty: Bool { values.isEmpty }
    public var isValid: Bool { error == nil }

    public subscript(index: Int) -> Element { values[index] }

    public subscript(slice: Range<Int>) -> MLDataColumn<Element> {
        MLDataColumn(Array(values[slice]), name: name)
    }

    public subscript<R: RangeExpression>(slice: R) -> MLDataColumn<Element> where R.Bound == Int {
        MLDataColumn(Array(values[slice]), name: name)
    }

    public subscript(mask: MLUntypedColumn) -> MLDataColumn<Element> {
        MLDataColumn(zip(values, mask.values).compactMap { value, keep in
            keep.intValue.map { _ in value }
        }, name: name)
    }

    public subscript(mask: MLDataColumn<Bool>) -> MLDataColumn<Element> {
        MLDataColumn(zip(values, mask.values).compactMap { value, keep in
            keep ? value : nil
        }, name: name)
    }

    public func element(at index: Int) -> Element? {
        index >= 0 && index < values.count ? values[index] : nil
    }

    public func map<T>(_ transform: (Element) -> T) -> MLDataColumn<T> {
        MLDataColumn<T>(values.map(transform), name: name)
    }

    public mutating func append(contentsOf other: MLDataColumn<Element>) {
        values.append(contentsOf: other.values)
    }

    public func copy() -> MLDataColumn<Element> { self }

    public func dropMissing() -> MLDataColumn<Element> { self }

    public func materialize() throws -> MLDataColumn<Element> { self }

    public func dropDuplicates() -> MLDataColumn<Element> where Element: Hashable {
        var seen = Set<Element>()
        return MLDataColumn(values.filter { seen.insert($0).inserted }, name: name)
    }

    public func fillMissing(with value: Element) -> MLDataColumn<Element> { self }

    public func sort(byIncreasingOrder: Bool = true) -> MLDataColumn<Element> where Element: Comparable {
        MLDataColumn(values.sorted { byIncreasingOrder ? $0 < $1 : $1 < $0 }, name: name)
    }

    public func prefix(_ maxLength: Int = 10) -> MLDataColumn<Element> {
        MLDataColumn(Array(values[0..<Swift.min(maxLength, values.count)]), name: name)
    }

    public func suffix(_ maxLength: Int = 10) -> MLDataColumn<Element> {
        MLDataColumn(Array(values[Swift.max(0, values.count - maxLength)...]), name: name)
    }

    public var description: String {
        let shown = values.prefix(10).map { String(describing: $0) }.joined(separator: ", ")
        return values.count > 10 ? "\(shown), ... (\(values.count) values)" : shown
    }

    public var debugDescription: String { "\(name.isEmpty ? "MLDataColumn" : name)[\(count)]: \(description)" }
    public var customMirror: String { debugDescription }
    public var playgroundDescription: Any { debugDescription }
}

extension MLDataColumn: Equatable where Element: Equatable {
    public static func == (lhs: MLDataColumn, rhs: MLDataColumn) -> Bool {
        lhs.values == rhs.values
    }
}

extension MLDataColumn where Element: MLDataValueConvertible {
    public init<T: MLDataValueConvertible>(column: MLDataColumn<T>) {
        self.name = column.name
        self.error = column.error
        var out = [Element]()
        out.reserveCapacity(column.count)
        for value in column.values {
            if let converted = Element(from: value.dataValue) {
                out.append(converted)
            } else {
                error = .wrongType(requested: Element.dataValueType, found: value.dataValue.type)
            }
        }
        self.values = out
    }

    public init(_ untyped: MLUntypedColumn) {
        self.name = untyped.name
        self.error = untyped.error
        var out = [Element]()
        out.reserveCapacity(untyped.count)
        for value in untyped.values {
            if let converted = Element(from: value) {
                out.append(converted)
            } else {
                error = .wrongType(requested: Element.dataValueType, found: value.type)
            }
        }
        self.values = out
    }

    public init(repeating repeatedValue: MLDataValue, count: Int) {
        var out = [Element]()
        out.reserveCapacity(count)
        for _ in 0..<count {
            out.append(Element(from: repeatedValue) ?? Element())
        }
        self.init(out)
    }

    public func map<T: MLDataValueConvertible>(_ transform: (Element) -> T) -> MLDataColumn<T> {
        MLDataColumn<T>(values.map(transform), name: name)
    }

    public func map<T: MLDataValueConvertible>(_ transform: (Element) -> T?) -> MLDataColumn<T> {
        MLDataColumn<T>(values.map { transform($0) ?? T() }, name: name)
    }

    public func mapMissing<T: MLDataValueConvertible>(_ transform: (Element?) -> T?) -> MLDataColumn<T> {
        MLDataColumn<T>(values.map { transform($0) ?? T() }, name: name)
    }

    public func map<T: MLDataValueConvertible>(to type: T.Type) -> MLDataColumn<T> {
        map { value in T(from: value.dataValue) ?? T() }
    }

    public var untyped: MLUntypedColumn {
        MLUntypedColumn(values.map { $0.dataValue }, name: name)
    }
}

extension MLDataColumn where Element: MLDataValueConvertible {
    public func sum() -> Double? {
        guard !values.isEmpty else { return nil }
        var total = 0.0
        for value in values {
            guard let double = value.dataValue.doubleValue else { return nil }
            total += double
        }
        return total
    }

    public func mean() -> Double? {
        guard let total = sum(), !values.isEmpty else { return nil }
        return total / Double(values.count)
    }

    public func min() -> Double? {
        var best: Double?
        for value in values {
            guard let double = value.dataValue.doubleValue else { return nil }
            if best == nil || double < best! { best = double }
        }
        return best
    }

    public func max() -> Double? {
        var best: Double?
        for value in values {
            guard let double = value.dataValue.doubleValue else { return nil }
            if best == nil || double > best! { best = double }
        }
        return best
    }

    public func stdev() -> Double? {
        guard !values.isEmpty, let mean = mean() else { return nil }
        var total = 0.0
        for value in values {
            guard let double = value.dataValue.doubleValue else { return nil }
            total += (double - mean) * (double - mean)
        }
        return (total / Double(values.count)).squareRoot()
    }

    public func std() -> Double? { stdev() }
}

extension MLDataColumn where Element: Comparable {
    public func min() -> Element? { values.min() }
    public func max() -> Element? { values.max() }
}

public struct MLDataColumnSlice<Element>: RandomAccessCollection {
    public let name: String
    public let elements: [Element]
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = Slice<MLDataColumnSlice<Element>>
    public typealias Iterator = IndexingIterator<MLDataColumnSlice<Element>>

    public init(name: String, elements: [Element]) {
        self.name = name
        self.elements = elements
    }

    public var startIndex: Int { 0 }
    public var endIndex: Int { elements.count }
    public func index(after i: Int) -> Int { i + 1 }
    public subscript(index: Int) -> Element { elements[index] }

    public var column: MLDataColumn<Element> { MLDataColumn(elements, name: name) }
}
