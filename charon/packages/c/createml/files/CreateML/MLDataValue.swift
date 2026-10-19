import Foundation

public enum MLDataValue: Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    case invalid
    case int(Int64)
    case double(Double)
    case string(String)
    case sequence([MLDataValue])
    case dictionary([String: MLDataValue])
    case multiArray(MultiArrayType)

    public enum ValueType: Int, CaseIterable, Hashable, CustomStringConvertible {
        case invalid = 0
        case int = 1
        case double = 2
        case string = 3
        case multiArray = 4
        case sequence = 5
        case dictionary = 6

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

    public var isValid: Bool { type != .invalid }

    public var intValue: Int64? {
        switch self {
        case .int(let value): return value
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
        public var debugDescription: String { "Sequence(\(description))" }
    }

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
            var seen = Set<String>()
            for (key, _) in pairs {
                precondition(seen.insert(key).inserted,
                             "a dictionary built from pairs has the key \(key) twice")
            }
            var built = [String: MLDataValue](minimumCapacity: pairs.count)
            for (key, value) in pairs { built[key] = value }
            self.storage = built
        }

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

    public struct MultiArrayType: Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
        public var shape: [Int]
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

public protocol MLDataValueConvertible {
    var dataValue: MLDataValue { get }
    static var dataValueType: MLDataValue.ValueType { get }
    init()
    init?(from value: MLDataValue)
}

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
    public static func compareValues(_ lhs: MLDataValue, _ rhs: MLDataValue) -> Int {
        if let a = lhs.intValue, let b = rhs.intValue { return a < b ? -1 : (a > b ? 1 : 0) }
        if let a = lhs.doubleValue, let b = rhs.doubleValue { return a < b ? -1 : (a > b ? 1 : 0) }
        if let a = lhs.stringValue, let b = rhs.stringValue { return a < b ? -1 : (a > b ? 1 : 0) }
        return 0
    }
}
