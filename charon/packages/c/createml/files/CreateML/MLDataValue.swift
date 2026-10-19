// MLDataValue.swift — the value a cell of a training table holds, and the conversions into it.
//
// This is CreateML's own value type and it is an enumeration, not a class: a table of a few hundred
// thousand rows is a few hundred thousand of these, and a reference type per cell would be an
// allocation per cell for a value that is at most a multi-array.
//
// The cases are the six the surface names. `invalid` is not a placeholder — it is what a cell holds
// when a value of a type the table cannot carry was put in, and it is what makes `isValid` a real
// question rather than a constant.

import Foundation

/// A value a cell of an `MLDataTable` can hold.
public enum MLDataValue: Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Nothing: a cell that was never filled, or one whose value was of a type the table cannot
    /// carry. `isValid` answers NO for exactly this.
    case invalid
    /// A 64-bit integer.
    case int(Int64)
    /// A double-precision float.
    case double(Double)
    /// A string, which is also how a category is carried.
    case string(String)
    /// A sequence of values: a row of a nested table, packed by `MLDataTable.pack`.
    case sequence([MLDataValue])
    /// A dictionary of values: a structured value packed by `MLDataTable.pack`.
    case dictionary([String: MLDataValue])
    /// A shaped array of doubles. A `MultiArrayType` rather than a bare `[Double]` because the shape
    /// is part of the value: a column of 2x3 and a column of 3x2 are different columns, and an
    /// estimator that flattened both would be answering about a table nobody wrote.
    case multiArray(MultiArrayType)

    /// The kind of value this is, as the framework's own enumeration spells it.
    public enum ValueType: Int, CaseIterable, Hashable, CustomStringConvertible {
        case invalid = 0
        case int = 1
        case double = 2
        case string = 3
        case multiArray = 4
        case sequence = 5
        case dictionary = 6

        /// The kind's own name, spelled as the framework spells it: the *type* names, capitalised,
        /// and not the case names. Read out of the host's own answers by the differential
        /// (`tests/backports/host/createml`), which is the only thing that can settle it — a reader
        /// sees "int" and "Int" in a log and cannot tell which one the framework prints.
        public var description: String {
            switch self {
            case .invalid: return "Invalid"
            case .int: return "Int"
            case .double: return "Double"
            case .string: return "String"
            case .multiArray: return "MultiArray"
            case .sequence: return "Sequence"
            case .dictionary: return "Dictionary"
            }
        }
    }

    public var type: ValueType {
        switch self {
        case .invalid: return .invalid
        case .int: return .int
        case .double: return .double
        case .string: return .string
        case .multiArray: return .multiArray
        case .sequence: return .sequence
        case .dictionary: return .dictionary
        }
    }

    /// Whether the value is one the table can carry, which is everything but `invalid`.
    public var isValid: Bool { type != .invalid }

    public var intValue: Int64? {
        switch self {
        case .int(let value): return value
        // A double that is a whole number reads as that whole number, and nothing else does: a
        // double of 1.5 is not an integer, and a string is not a number at all, so neither is
        // silently coerced into one.
        case .double(let value):
            guard value == value.rounded(), value.magnitude < 9.2e18 else { return nil }
            return Int64(value)
        default: return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .int(let value): return Double(value)
        case .double(let value): return value
        default: return nil
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        // An int reads as its decimal, and a double as the shortest form that reads back as itself,
        // so a table of numbers written as text and a table of numbers agree cell for cell.
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        default: return nil
        }
    }

    public var sequenceValue: [MLDataValue]? {
        if case .sequence(let value) = self { return value }
        return nil
    }

    public var dictionaryValue: [String: MLDataValue]? {
        if case .dictionary(let value) = self { return value }
        return nil
    }

    public var multiArrayValue: MultiArrayType? {
        if case .multiArray(let value) = self { return value }
        return nil
    }

    public var description: String {
        switch self {
        case .invalid: return "Invalid"
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .string(let value): return value
        case .multiArray(let value): return value.description
        case .sequence(let value): return value.map(\.description).joined(separator: ", ")
        case .dictionary(let value):
            return value.keys.sorted().map { "\($0): \(value[$0]!.description)" }.joined(separator: ", ")
        }
    }

    public var debugDescription: String { "\(type): \(description)" }

    // MARK: The nested value types, in the framework's own names.

    /// A sequence of values.
    public struct SequenceType: RandomAccessCollection, Equatable, Hashable,
                                CustomStringConvertible, CustomDebugStringConvertible {
        public var elements: [MLDataValue]
        public typealias Element = MLDataValue
        public typealias Index = Int
        public typealias Indices = Range<Int>
        public typealias SubSequence = Slice<SequenceType>
        public typealias Iterator = IndexingIterator<SequenceType>
        public typealias ArrayLiteralElement = MLDataValue

        public init() { elements = [] }
        public init(_ elements: [MLDataValue]) { self.elements = elements }
        public init(arrayLiteral elements: MLDataValue...) { self.elements = elements }

        public var startIndex: Int { 0 }
        public var endIndex: Int { elements.count }
        public func index(after i: Int) -> Int { i + 1 }

        public subscript(index: Int) -> MLDataValue { elements[index] }

        public var dataValue: MLDataValue { .sequence(elements) }
        public static var dataValueType: MLDataValue.ValueType { .sequence }
        public var description: String { elements.map(\.description).joined(separator: ", ") }
        // Its *description*, like its three siblings: interpolating `debugDescription` here is
        // a call into this same getter, and any caller that reflects or dumps a sequence
        // value gets a stack overflow rather than a string.
        public var debugDescription: String { "Sequence(\(description))" }
    }

    /// A dictionary of values.
    public struct DictionaryType: RandomAccessCollection, Equatable, Hashable,
                                 CustomStringConvertible, CustomDebugStringConvertible {
        public var storage: [String: MLDataValue]
        public typealias Element = (key: String, value: MLDataValue)
        public typealias Index = Int
        public typealias Indices = Range<Int>
        public typealias SubSequence = Slice<DictionaryType>
        public typealias Iterator = IndexingIterator<DictionaryType>
        public typealias Key = String
        public typealias Value = MLDataValue

        public init() { storage = [:] }
        public init(_ storage: [String: MLDataValue]) { self.storage = storage }
        public init(uniqueKeysWithValues pairs: [(String, MLDataValue)]) {
            // A repeated key is a programming error and is refused rather than resolved: a
            // dictionary built from pairs that disagree about one key has no value for it, and
            // picking one of the two silently is how a table ends up with a category that was never
            // written down. The duplicates are found first, in a set, and the storage is built
            // afterwards, so the check never reads a half-built dictionary.
            var seen = Set<String>()
            for (key, _) in pairs {
                precondition(seen.insert(key).inserted,
                             "a dictionary built from pairs has the key \(key) twice")
            }
            var built = [String: MLDataValue](minimumCapacity: pairs.count)
            for (key, value) in pairs { built[key] = value }
            self.storage = built
        }

        /// The keys in a fixed order, so that iterating this dictionary twice gives the same order —
        /// which a Swift `Dictionary` does not promise, and a table's equality does depend on. This
        /// is why the index is an `Int` and not a `Dictionary.Index`: the collection is over the
        /// sorted keys, which is an order, and not over the storage, which is not.
        public var sortedKeys: [String] { storage.keys.sorted() }

        public var startIndex: Int { 0 }
        public var endIndex: Int { storage.count }
        public func index(after i: Int) -> Int { i + 1 }

        public subscript(key: String) -> MLDataValue? {
            get { storage[key] }
            set { storage[key] = newValue }
        }

        public subscript(index: Int) -> Element {
            let key = sortedKeys[index]
            return (key, storage[key]!)
        }

        public var dataValue: MLDataValue { .dictionary(storage) }
        public var dataValueType: MLDataValue.ValueType { .dictionary }
        public var description: String {
            sortedKeys.map { "\($0): \(storage[$0]!.description)" }.joined(separator: ", ")
        }
        public var debugDescription: String { "Dictionary(\(description))" }
    }

    /// A shaped array of doubles: `shape` dimensions of `counts` elements each, row-major, with the
    /// strides the shape implies.
    public struct MultiArrayType: Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
        public var shape: [Int]
        /// The strides, in elements, of each dimension: `strides[0]` is 1 and the rest are the
        /// products of the following shapes. Carried rather than recomputed so that a slice of a
        /// multi-array is the multi-array of a sub-block and not a copy with the wrong shape.
        public private(set) var strides: [Int]
        public private(set) var count: Int
        public private(set) var data: [Double]

        public init(shape: [Int]) {
            self.shape = shape
            var strides = [Int](repeating: 1, count: shape.count)
            var running = 1
            for dimension in stride(from: shape.count - 1, to: 0, by: -1) {
                strides[dimension] = running
                running *= max(0, shape[dimension])
            }
            self.strides = strides
            self.count = running
            self.data = [Double](repeating: 0, count: running)
        }

        public init(_ data: [Double]) {
            self.shape = [data.count]
            self.strides = [1]
            self.count = data.count
            self.data = data
        }

        public init(_ data: [Double], shape: [Int]) {
            precondition(data.count == shape.reduce(1, *), "a shaped array of shape \(shape) holds \(shape.reduce(1, *)) values, not \(data.count)")
            self.shape = shape
            var strides = [Int](repeating: 1, count: shape.count)
            var running = 1
            for dimension in stride(from: shape.count - 1, to: 0, by: -1) {
                strides[dimension] = running
                running *= max(0, shape[dimension])
            }
            self.strides = strides
            self.count = running
            self.data = data
        }

        public subscript(index: Int) -> Double {
            get { data[index] }
            set { data[index] = newValue }
        }

        /// The element at a set of indices, one per dimension.
        public subscript(indices: Int...) -> Double {
            get {
                precondition(indices.count == shape.count, "this array is \(shape.count)-dimensional and was given \(indices.count) indices")
                var flat = 0
                for (dimension, index) in indices.enumerated() { flat += index * strides[dimension] }
                return data[flat]
            }
            set {
                precondition(indices.count == shape.count, "this array is \(shape.count)-dimensional and was given \(indices.count) indices")
                var flat = 0
                for (dimension, index) in indices.enumerated() { flat += index * strides[dimension] }
                data[flat] = newValue
            }
        }

        public var mlMultiArray: MultiArrayType { self }
        public var dataValue: MLDataValue { .multiArray(self) }
        public var dataValueType: MLDataValue.ValueType { .multiArray }

        public var description: String {
            "[\(data.map { "\($0)" }.joined(separator: ", "))]"
        }
        public var debugDescription: String { "MultiArray(\(shape): \(description))" }
    }
}

/// A type a cell of a training table can be read out of as an `MLDataValue`.
public protocol MLDataValueConvertible {
    /// This value as the framework's own value type.
    var dataValue: MLDataValue { get }
    /// The kind a value of this type becomes. A static, and not an instance member, because a caller
    /// naming a type asks what it will become without having a value of it to ask.
    static var dataValueType: MLDataValue.ValueType { get }
    init()
    init?(from value: MLDataValue)
}

// The nested value types are values of a table but are deliberately NOT `MLDataValueConvertible`,
// which is what the SDK's own interface says: they carry `dataValueType` as an *instance* member,
// and Swift has one name per type per level, so a static of the same name for a protocol
// conformance would collide with it. The three accessors that read them convert explicitly instead,
// through the same `case` the value came from, so the conversion is the identity and is written
// where a reader can see it.

extension Int: MLDataValueConvertible {
    public var dataValue: MLDataValue { .int(Int64(self)) }
    public static var dataValueType: MLDataValue.ValueType { .int }
    public init() { self = 0 }
    public init?(from value: MLDataValue) {
        guard let int = value.intValue else { return nil }
        self = Int(int)
    }
}

extension Int32: MLDataValueConvertible {
    public var dataValue: MLDataValue { .int(Int64(self)) }
    public static var dataValueType: MLDataValue.ValueType { .int }
    public init() { self = 0 }
    public init?(from value: MLDataValue) {
        guard let int = value.intValue, int >= Int64(Int32.min), int <= Int64(Int32.max) else { return nil }
        self = Int32(int)
    }
}

extension Int64: MLDataValueConvertible {
    public var dataValue: MLDataValue { .int(self) }
    public static var dataValueType: MLDataValue.ValueType { .int }
    public init() { self = 0 }
    public init?(from value: MLDataValue) {
        guard let int = value.intValue else { return nil }
        self = int
    }
}

extension Double: MLDataValueConvertible {
    public var dataValue: MLDataValue { .double(self) }
    public static var dataValueType: MLDataValue.ValueType { .double }
    public init() { self = 0 }
    public init?(from value: MLDataValue) {
        guard let double = value.doubleValue else { return nil }
        self = double
    }
}

extension Float: MLDataValueConvertible {
    public var dataValue: MLDataValue { .double(Double(self)) }
    public static var dataValueType: MLDataValue.ValueType { .double }
    public init() { self = 0 }
    public init?(from value: MLDataValue) {
        guard let double = value.doubleValue else { return nil }
        self = Float(double)
    }
}

extension String: MLDataValueConvertible {
    public var dataValue: MLDataValue { .string(self) }
    public static var dataValueType: MLDataValue.ValueType { .string }
    public init() { self = "" }
    public init?(from value: MLDataValue) {
        guard let string = value.stringValue else { return nil }
        self = string
    }
}

extension Bool: MLDataValueConvertible {
    // A boolean is carried as an integer, which is what a CSV of `true`/`false` has to become
    // before a column of it can be numeric, and what a JSON `true` becomes for the same reason.
    public var dataValue: MLDataValue { .int(self ? 1 : 0) }
    public static var dataValueType: MLDataValue.ValueType { .int }
    public init() { self = false }
    public init?(from value: MLDataValue) {
        switch value {
        case .int(let int): self = int != 0
        case .string(let string):
            switch string.lowercased() {
            case "true", "yes", "1": self = true
            case "false", "no", "0": self = false
            default: return nil
            }
        default: return nil
        }
    }
}

extension Array: MLDataValueConvertible where Element: MLDataValueConvertible {
    public var dataValue: MLDataValue { .sequence(self.map(\.dataValue)) }
    public static var dataValueType: MLDataValue.ValueType { .sequence }
    public init() { self = [] }
    public init?(from value: MLDataValue) {
        guard case .sequence(let elements) = value else { return nil }
        var out = [Element]()
        out.reserveCapacity(elements.count)
        for element in elements {
            guard let converted = Element(from: element) else { return nil }
            out.append(converted)
        }
        self = out
    }
}

extension MLDataValue {
    /// -1, 0 or 1 for the order of two values, and 0 across kinds: there is no order between a
    /// string and a number, and answering one would be a comparison nobody asked for. A column's
    /// comparisons go through here, so a filter's meaning never depends on a type it does not name.
    public static func compareValues(_ lhs: MLDataValue, _ rhs: MLDataValue) -> Int {
        if let a = lhs.intValue, let b = rhs.intValue { return a < b ? -1 : (a > b ? 1 : 0) }
        if let a = lhs.doubleValue, let b = rhs.doubleValue { return a < b ? -1 : (a > b ? 1 : 0) }
        if let a = lhs.stringValue, let b = rhs.stringValue { return a < b ? -1 : (a > b ? 1 : 0) }
        return 0
    }
}
