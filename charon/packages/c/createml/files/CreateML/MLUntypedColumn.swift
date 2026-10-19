// MLUntypedColumn.swift — a column of a training table, typed and untyped.
//
// `MLUntypedColumn` is the column the table holds: a name and a vector of `MLDataValue`. `MLDataColumn`
// is the same column with its element type written down, so a caller reading a prediction column
// gets `Int` out of it rather than an enum case to unwrap.
//
// The signatures here are the framework's own, read from the SDK 26.2 interface and not guessed: the
// accessors answer *typed* columns and are optional (`ints` is `MLDataColumn<Int>?`, not `[Int?]`),
// a column of a range is a column of the *indices* in that range, and `materialize()` throws
// because the release's columns are computed views over another table and this one has to say so
// rather than pretend the two are the same kind of thing.
//
// Neither is lazy here. The release computes a column on demand so a table of a million rows can
// answer a subscript without materialising the million; a column here is a vector, so
// `materialize()` is the identity — and it is said to be, in this file, rather than left for a
// caller to discover by timing it.

import Foundation

/// Why a column cannot be read as what was asked for.
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

/// A column of a training table whose element type is not written down.
public struct MLUntypedColumn: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public internal(set) var name: String
    public private(set) var values: [MLDataValue]
    /// Set when a value of a kind the column cannot carry is in it, or when its values are of two
    /// different kinds. The column stays readable and the failure stays visible: `isValid` answers
    /// NO and `error` says why, which is what lets a caller find the bad cell instead of training on
    /// a table that quietly dropped a column.
    public private(set) var error: MLColumnError?

    /// The kind of value this column holds.
    ///
    /// Not optional, and `invalid` for a column with no kind: an empty column has none, a column of
    /// mixed kinds has none, and the framework's enumeration has a case that says exactly that.
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

    /// A column of the *indices* of a range, which is what the framework's `init(_ range:)` builds:
    /// a mask over a table's rows, not the values a range of numbers would suggest.
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

    /// A column narrowed to one kind, so that `MLUntypedColumn(ints:)` over a column of doubles that
    /// are whole numbers is the column of those numbers and not a column of the wrong type.
    private init(_ column: MLUntypedColumn, convertingTo wanted: MLDataValue.ValueType) {
        self.name = column.name
        var out = [MLDataValue](repeating: .invalid, count: column.count)
        for (index, value) in column.values.enumerated() {
            switch wanted {
            case .int: out[index] = value.intValue.map(MLDataValue.int) ?? .invalid
            case .double: out[index] = value.doubleValue.map(MLDataValue.double) ?? .invalid
            case .string: out[index] = value.stringValue.map(MLDataValue.string) ?? .invalid
            default:
                // A sequence, a dictionary and a multi-array are their own kinds and nothing
                // converts between them, so the column is taken as it is and a cell of another kind
                // becomes missing rather than being read as one of these.
                out[index] = value.type == wanted ? value : .invalid
            }
        }
        self.values = out
        self.type = .invalid
        settle()
    }

    /// The kind of the column's values and the reason it cannot be used, decided from its cells.
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

    /// A column is valid when its values are all of one kind, or when it is empty: an empty column
    /// has nothing wrong with it, and a column whose name is empty is a column nobody has named yet.
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

    /// The column read as a type of its own, or nil when it holds something else.
    ///
    /// A *missing* cell becomes the type's own zero and a cell of another kind makes the whole
    /// accessor answer nil. Both halves are measured: the host's `strings` on a column whose second
    /// cell is `Missing` answers `["north", "", "", "south", ...]` — the gap reads as the empty
    /// string — and its `ints` on a *string* column answers nil rather than a column of zeroes. A
    /// reader that returned nil for the first case would make every join's other-side column
    /// unreadable, and one that returned zeroes for the second would make a category column look
    /// like a column of small numbers.
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

    /// The column without its missing values. A missing value is a value, and keeping it would make
    /// a mean over the column a mean over something the caller never wrote.
    public func dropMissing() -> MLUntypedColumn {
        MLUntypedColumn(values.filter { $0.isValid }, name: name)
    }

    public func fillMissing(with value: MLDataValue) -> MLUntypedColumn {
        MLUntypedColumn(values.map { $0.isValid ? $0 : value }, name: name)
    }

    /// The column with each distinct value once, in the order they first appear: the order a
    /// category column is read in is the order it was written in, so a caller comparing two columns
    /// sees the same categories in the same places.
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
            // A sequence, a dictionary, a multi-array and an empty column have no order to sort by.
            // The column is returned as it was rather than in an order invented for them.
            return self
        }
        return MLUntypedColumn(sorted, name: name)
    }

    /// The order of two values of the same kind, and zero across kinds: there is no order between a
    /// string and a number, and answering one would be a comparison nobody asked for.
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

    /// The identity, and said to be: a column here holds its values rather than computing them, so
    /// there is nothing to materialize and a caller that measured this would measure nothing. The
    /// release's own throws here because its columns are views; this one's is declared to throw so
    /// that the same call site compiles against both.
    public func materialize() throws -> MLUntypedColumn { self }

    public var description: String {
        let shown = values.prefix(10).map { $0.description }.joined(separator: ", ")
        return values.count > 10 ? "\(shown), ... (\(values.count) values)" : shown
    }

    public var debugDescription: String {
        // The kind's own name, through a local: `type.description` in this line reads as the
        // *column's* description, which is a sentence about the values rather than a kind's name.
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

// The element-wise operators, because a caller filtering a table reaches for `table["price"] > 3`
// and not for a `map`. The comparison is the column's own order, and across kinds it is false rather
// than a coin: "a sequence is greater than 3" has no answer, and answering it either way would make
// a filter's meaning depend on a type it does not mention.
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

    /// -1, 0 or 1 for a column's order against one value, taken from the column's first cell: a
    /// column is compared cell by cell and the first cell is the one that decides, which is what
    /// makes `table["x"] < 3` mean what it looks like it means.
    static func compare(_ lhs: MLUntypedColumn, _ rhs: MLDataValue) -> Int {
        for value in lhs.values {
            return MLDataValue.compareValues(value, rhs)
        }
        return 0
    }

    public static func != (lhs: MLUntypedColumn, rhs: MLUntypedColumn) -> Bool { !(lhs == rhs) }

    // The arithmetic operators, over a column and a value, in the same spirit: a filter is written
    // `table["x"] * 2 > table["y"]`, and the column's own missing value makes the arithmetic one
    // rather than a value with a hole in it.
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

/// A column of a training table whose element type is written down.
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

    /// The column without its missing values. An `MLDataColumn<Element>` holds only values of its
    /// element type, so a cell it could not convert was dropped at the initialiser and there is
    /// nothing left here to drop; the reason is still on `error`, and a caller that needs the gaps
    /// reads `untyped`.
    public func dropMissing() -> MLDataColumn<Element> { self }

    /// The identity, for the reason `MLUntypedColumn.materialize()` gives: declared to throw so the
    /// same call site compiles against the release's views and against this vector alike.
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
            // A cell that does not convert is not dropped: an `MLDataColumn<Element>` has no
            // representation for it, so the column records why it is shorter than it was and
            // `isValid` says NO. A caller that needs the missing value reads the untyped column,
            // which has one.
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

    /// The column as the untyped column, which is the only column that can hold a missing value.
    public var untyped: MLUntypedColumn {
        MLUntypedColumn(values.map { $0.dataValue }, name: name)
    }
}

// The sums, in the framework's own spellings: `sum()`, `min()`, `max()`, `mean()`, `std()` and
// `stdev()`, each returning nil for a column it cannot answer for rather than a number it invented.
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

    /// The standard deviation of the column: the sum of the squared deviations over `n`, and nil for
    /// a column of one value, which has no spread to speak of.
    ///
    /// Over `n` and not over `n - 1`, which is a *measured* choice and not a slip. The host's own
    /// `stdev()` on the eight prices of the differential answers 36.5718; the unbiased form answers
    /// 39.0969, and the difference is a factor of `sqrt(8/7)`. The framework divides by the number of
    /// values it was given, so this does too — a column of a training table is the whole population
    /// the model will see of that feature, not a sample drawn from a larger one.
    public func stdev() -> Double? {
        guard !values.isEmpty, let mean = mean() else { return nil }
        var total = 0.0
        for value in values {
            guard let double = value.dataValue.doubleValue else { return nil }
            total += (double - mean) * (double - mean)
        }
        return (total / Double(values.count)).squareRoot()
    }

    /// The name the release deprecated in favour of `stdev()`, kept because the surface has both and
    /// a caller written against the older one still calls it.
    public func std() -> Double? { stdev() }
}

extension MLDataColumn where Element: Comparable {
    public func min() -> Element? { values.min() }
    public func max() -> Element? { values.max() }
}

/// A typed column's own slice: the elements in a range of the column's rows, under the column's name.
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

    /// The slice as a column of its own, so a caller can keep reading it as a column.
    public var column: MLDataColumn<Element> { MLDataColumn(elements, name: name) }
}
