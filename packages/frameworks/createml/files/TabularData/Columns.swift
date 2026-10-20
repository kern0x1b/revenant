import Foundation

public struct ColumnID<T>: Sendable {
    public var name: String

    public init(_ name: String, _ type: T.Type) {
        self.name = name
    }
}

extension ColumnID: CustomStringConvertible {
    public var description: String { name }
}

extension ColumnID: Equatable {
    public static func == (lhs: ColumnID, rhs: ColumnID) -> Bool { lhs.name == rhs.name }
}

extension ColumnID: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

public protocol ColumnProtocol<Element> {
    associatedtype Element
    var name: String { get set }
}

internal final class ColumnStorage<Element>: @unchecked Sendable {
    var values: [Element?]

    init(_ values: [Element?]) { self.values = values }
}

public struct Column<Element>: ColumnProtocol {
    public var name: String
    internal var storage: ColumnStorage<Element>

    private mutating func takeUniqueBox() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = ColumnStorage<Element>(storage.values)
        }
    }
    public var values: [Element?] {
        get { storage.values }
        set {
            takeUniqueBox()
            storage.values = newValue
        }
    }

    public var presentValues: [Element] { storage.values.compactMap { $0 } }

    public init(name: String = "") {
        self.storage = ColumnStorage<Element>([])
        self.name = name
    }

    public init(name: String = "", _ values: [Element]) {
        self.storage = ColumnStorage<Element>(values.map { $0 })
        self.name = name
    }

    public init<S>(name: String, contents: S) where S: Sequence, S.Element == Element? {
        self.storage = ColumnStorage<Element>(Array(contents))
        self.name = name
    }

    public init<S>(name: String, contents: S) where Element == S.Element, S: Sequence {
        self.storage = ColumnStorage<Element>(contents.map { $0 })
        self.name = name
    }

    public init<S: Sequence>(_ source: S, name: String = "") where S.Element == Element {
        self.storage = ColumnStorage<Element>(source.map { $0 })
        self.name = name
    }

    public init(_ column: Column<Element>, name: String? = nil) {
        self.storage = column.storage
        self.name = name ?? column.name
    }

    public init(copying column: Column<Element>, name: String? = nil) {
        self.storage = ColumnStorage<Element>(column.storage.values)
        self.name = name ?? column.name
    }

    public init(repeating value: Element, count: Int, name: String = "") {
        self.storage = ColumnStorage<Element>([Element?](repeating: value, count: count))
        self.name = name
    }


    public var count: Int { values.count }
    public var isEmpty: Bool { values.isEmpty }
    public var startIndex: Int { 0 }
    public var endIndex: Int { values.count }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }

    public subscript(position: Int) -> Element? {
        get { values[position] }
        set {
            takeUniqueBox()
            values[position] = newValue
        }
    }

    internal mutating func setCellInSharedBox(_ position: Int, _ value: Element?) {
        storage.values[position] = value
    }

    public subscript(bounds: Range<Int>) -> ColumnSlice<Element> {
        ColumnSlice(base: self, range: bounds)
    }

    public var slice: ColumnSlice<Element> { ColumnSlice(base: self, range: 0..<count) }

    public func eraseToAnyColumn() -> AnyColumn { AnyColumn(self) }

    public mutating func append(_ value: Element) { values.append(value) }
    public mutating func append(contentsOf other: [Element]) { values.append(contentsOf: other) }
    public mutating func reserveCapacity(_ capacity: Int) { values.reserveCapacity(capacity) }

    public func map<T>(_ transform: (Element?) throws -> T?) rethrows -> Column<T> {
        var mapped = [T?]()
        for cell in storage.values { mapped.append(try transform(cell)) }
        return Column<T>(name: name, contents: mapped)
    }

    public func compactMap<T>(_ transform: (Element?) throws -> T?) rethrows -> [T] {
        var out = [T]()
        for cell in storage.values {
            if let result = try transform(cell) { out.append(result) }
        }
        return out
    }

    public func filter(_ isIncluded: (Element?) throws -> Bool) rethrows -> DiscontiguousColumnSlice<Element> {
        var kept = [Int]()
        for (position, cell) in storage.values.enumerated() {
            if try isIncluded(cell) { kept.append(position) }
        }
        return DiscontiguousColumnSlice(name: name, base: self, indices: kept)
    }
}

extension Column: Equatable where Element: Equatable {
    public static func == (lhs: Column, rhs: Column) -> Bool {
        lhs.name == rhs.name && lhs.values == rhs.values
    }
}

extension Column: Sendable where Element: Sendable {}

public struct ColumnSlice<Element>: ColumnProtocol, BidirectionalCollection {
    public var base: Column<Element>
    public let range: Range<Int>
    public var name: String {
        get { base.name }
        set { base.name = newValue }
    }

    public typealias SubSequence = ColumnSlice<Element>

    public init(base: Column<Element>, range: Range<Int>) {
        self.base = base
        self.range = range
    }

    public init(name: String = "", _ values: [Element]) {
        self.base = Column<Element>(name: name, values)
        self.range = 0..<values.count
    }

    public var count: Int { range.count }
    public var isEmpty: Bool { range.isEmpty }

    public var startIndex: Int { range.lowerBound }
    public var endIndex: Int { range.upperBound }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }

    public subscript(position: Int) -> Element? {
        get {
            precondition(range.contains(position),
                         "position \(position) is not in the slice's range \(range)")
            return base[position]
        }
        set {
            precondition(range.contains(position),
                         "position \(position) is not in the slice's range \(range)")
            base.setCellInSharedBox(position, newValue)
        }
    }

    public subscript(bounds: Range<Int>) -> ColumnSlice<Element> {
        ColumnSlice(base: base, range: bounds)
    }

    public var column: Column<Element> { Column<Element>(name: name, values) }

    public var values: [Element] { range.compactMap { base[$0] } }
}

extension ColumnSlice: Equatable where Element: Equatable {}

public struct DiscontiguousColumnSlice<Element>: ColumnProtocol, BidirectionalCollection {
    public var base: Column<Element>
    public let indices: [Int]
    public var name: String {
        get { base.name }
        set { base.name = newValue }
    }

    public typealias SubSequence = DiscontiguousColumnSlice<Element>

    public init(name: String = "", base: Column<Element>, indices: [Int]) {
        self.base = base
        self.indices = indices
    }

    public var count: Int { indices.count }
    public var isEmpty: Bool { indices.isEmpty }
    public var startIndex: Int { indices.first ?? 0 }
    public var endIndex: Int { (indices.last ?? -1) + 1 }
    public func index(after i: Int) -> Int { indices.first { $0 > i } ?? endIndex }
    public func index(before i: Int) -> Int {
        guard let previous = indices.last(where: { $0 < i }) else {
            preconditionFailure("Can't move index before startIndex")
        }
        return previous
    }

    public subscript(position: Int) -> Element? {
        get {
            precondition(indices.contains(position),
                         "position \(position) is not a valid slice index")
            return base[position]
        }
        set {
            precondition(indices.contains(position),
                         "position \(position) is not a valid slice index")
            base[position] = newValue
        }
    }

    public subscript(bounds: Range<Int>) -> DiscontiguousColumnSlice<Element> {
        DiscontiguousColumnSlice(base: base, indices: Array(indices[bounds]))
    }

    public var values: [Element] { indices.compactMap { base[$0] } }

    public var column: Column<Element> { Column<Element>(name: name, values) }
}

extension DiscontiguousColumnSlice: Equatable where Element: Equatable {}

public struct AnyColumn: @unchecked Sendable {
    public var name: String

    public let wrappedElementType: Any.Type

    private let storage: [Any?]

    private let makeTyped: (String) -> Any

    internal init<T>(_ column: Column<T>) {
        self.name = column.name
        self.wrappedElementType = T.self
        self.storage = column.values.map { $0 as Any? }
        self.makeTyped = { renamed in
            var copy = column
            copy.name = renamed
            return copy
        }
    }

    internal init<T>(_ slice: ColumnSlice<T>) {
        self.init(Column(slice.base, name: slice.base.name)[slice.range])
    }

    internal init<T>(_ slice: DiscontiguousColumnSlice<T>) {
        self.init(Column(name: slice.name, slice.values))
    }

    public var count: Int { storage.count }

    public var missingCount: Int {
        var missing = 0
        for index in storage.indices where storage[index] == nil { missing += 1 }
        return missing
    }

    public func isNil(at index: Int) -> Bool {
        guard storage.indices.contains(index) else { return true }
        return storage[index] == nil
    }

    public func assumingType<T>(_ type: T.Type) -> Column<T>? {
        guard wrappedElementType == T.self else { return nil }
        return makeTyped(name) as? Column<T>
    }

    internal var presentValues: [Any] {
        storage.map { element -> Any in
            guard let element = element else { return Optional<Any>.none as Any }
            return element
        }
    }

    internal var erasedValues: [Any] {
        storage.map { element -> Any in
            guard let element = element else { return Optional<Any>.none as Any }
            return element
        }
    }

    public subscript(_ position: Int) -> Any? {
        guard position >= 0 && position < storage.count else { return nil }
        return storage[position]
    }

    internal func values<T>(as type: T.Type = T.self) -> [T?]? {
        var out = [T?]()
        out.reserveCapacity(storage.count)
        for value in storage {
            guard let value = value else { out.append(nil); continue }
            guard let typed = value as? T else { return nil }
            out.append(typed)
        }
        return out
    }

}

private protocol _AlreadyOptional {
    var anyValue: Any? { get }
    static var wrappedElementType: Any.Type { get }
}

extension Optional: _AlreadyOptional {
    var anyValue: Any? {
        switch self {
        case .none: return nil
        case .some(let value): return value
        }
    }

    static var wrappedElementType: Any.Type { Wrapped.self }
}
