// Columns.swift — the columns a `DataFrame` is made of.
//
// **A column here does not conform to a collection, and the reason is the toolchain.** A
// user-defined `RandomAccessCollection` conformance does not compile with the port's Swift 6.4 at
// all: the smallest possible one — a non-generic struct over `[Double]` with `startIndex`,
// `endIndex`, `index(after:)`, `index(before:)` and `subscript(position:)` — is rejected with
//
//     type 'Fixed' does not conform to protocol 'RandomAccessCollection'
//     unavailable subscript 'subscript(_:)' was used to satisfy a requirement of protocol
//
// on the *port's* compiler at `-target armv7-apple-ios6.0` as well as on the host's, and
// `Array` — which is in the same standard library — conforms without trouble. So this is the
// compiler and not the declarations, and it is measured on both targets and recorded in
// `facts/TabularData/Columns.md` and in the registry.
//
// What that costs, precisely: the conformance itself. Nothing else. A column still has `count`,
// `isEmpty`, `startIndex`, `endIndex`, `index(after:)`, `index(before:)`, `subscript(position:)` and
// `subscript(bounds:)`, spelled as the collection spells them, and those are the names the surface's
// rows are written against. What a caller loses is writing `for x in column`, which is a convenience
// over `for i in 0..<column.count` — and the alternative, declaring a conformance that does not
// compile, is not available.
//
// `ColumnProtocol` therefore declares its `Element` and its `name` and nothing else. It keeps the
// primary associated type the surface names, `ColumnProtocol<Element>`, which is what a caller writes
// to name a column and its type.

import Foundation

/// A column's name, and the type of its values: how a caller asks a frame for a column and gets a
/// typed one back.
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

/// A column of a frame: a name and a vector of values of one type.
///
/// It does not refine a collection — see the file's header for the measurement — and the columns
/// conform to `BidirectionalCollection` themselves.
public protocol ColumnProtocol<Element> {
    associatedtype Element
    var name: String { get set }
}

/// A column's storage, in a box.
///
/// The box is what makes a slice a **view** rather than a copy. `Column` is a struct, so a
/// `ColumnSlice` holding it by value holds a *copy* of the column, and a write through the slice
/// would land in that copy while the frame kept the old value — the exact silent no-op the first
/// version of this file avoided by making the slice read-only, which cost every caller the ability to
/// write through a view. With the storage in a reference the slice and the column see the same values,
/// which is what the name says and what the framework's own slice does.
internal final class ColumnStorage<Element>: @unchecked Sendable {
    /// `[Element?]`, not `[Element]`: the SDK's `Column<WrappedElement>` is itself
    /// `OptionalColumnProtocol`, and the missing cell is expressed by the *type* rather than by a
    /// separate optional column. A column therefore has to be able to hold a nil while reporting its
    /// element type as the value's own type, and `[Element]` cannot hold one at all.
    var values: [Element?]

    init(_ values: [Element?]) { self.values = values }
}

/// A column of a frame, holding values of one type.
public struct Column<Element>: ColumnProtocol {
    public var name: String
    /// The column's values, in the box every view of this column shares. `storage` is `internal` and
    /// the views are in this file, so nothing outside can reach past the value semantics.
    ///
    /// `var`, not `let`, because a **mutation** has to be able to replace the box when the box is not
    /// this column's alone - that is the whole of copy-on-write, and without the check a struct over a
    /// shared reference is not value semantics at all. Measured: with `let` and no check, a copy of a
    /// column that was written to wrote *through* to the original.
    internal var storage: ColumnStorage<Element>

    /// Take a box of this column's own before writing to it, when the box is shared.
    ///
    /// `isKnownUniquelyReferenced` is the only question worth asking: a column and a slice over it are
    /// both holders of the same box, and a write through either has to reach the cells every holder
    /// sees. Copying first is what makes the two independent again, and it costs one array copy only on
    /// the write that needed it.
    private mutating func takeUniqueBox() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = ColumnStorage<Element>(storage.values)
        }
    }
    /// The column's cells, each of which may be missing. `Element` is the *value* type, so a nil
    /// here is a cell with no value and a `.some(nil)` a value that is itself an optional - the
    /// distinction the SDK keeps and this column now keeps with it.
    public var values: [Element?] {
        get { storage.values }
        set {
            // Replacing every cell is a mutation of every cell, so the box has to be this column's own
            // first - otherwise a second column over the same values would see the replacement.
            takeUniqueBox()
            storage.values = newValue
        }
    }

    /// The cells that hold a value, with the missing ones dropped. What most callers of a column
    /// want, and the port's own readers used to get it from `values` before the missing cell became
    /// expressible.
    public var presentValues: [Element] { storage.values.compactMap { $0 } }

    /// Every initialiser assigns the **box** first and `name` second: `values` goes through the box,
    /// so writing `self.values` before the box exists reads `self` uninitialised. That is a real
    /// Swift restriction and not a style choice, and it is why the order is the same in all of them.
    public init(name: String = "") {
        self.storage = ColumnStorage<Element>([])
        self.name = name
    }

    public init(name: String = "", _ values: [Element]) {
        self.storage = ColumnStorage<Element>(values.map { $0 })
        self.name = name
    }

    /// The SDK's two `contents:` initialisers, verbatim in their constraints.
    ///
    ///     public init<S>(name: String, contents: S) where S: Sequence, S.Element == WrappedElement?
    ///     public init<S>(name: String, contents: S) where WrappedElement == S.Element, S: Sequence
    ///
    /// The first is the ordinary form: the cells are `Element?` and a `nil` in them is a missing
    /// cell by the type. The second is the present form: the cells are `Element` and cannot be
    /// missing. The port could not write the first before, because `Column<Int>(name:_:)` took
    /// `[Int]` and `nil` did not fit - so a column that is missing a cell had no spelling at all.
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

    /// A **view** of another column: the storage is shared, so a write through either is a write
    /// through both, which is what makes `ColumnSlice` a view rather than a copy. Only
    /// `init(copying:)` starts a column of its own over the same values.
    public init(_ column: Column<Element>, name: String? = nil) {
        self.storage = column.storage
        self.name = name ?? column.name
    }

    /// A column of its own over a copy of another one's values.
    public init(copying column: Column<Element>, name: String? = nil) {
        self.storage = ColumnStorage<Element>(column.storage.values)
        self.name = name ?? column.name
    }

    public init(repeating value: Element, count: Int, name: String = "") {
        self.storage = ColumnStorage<Element>([Element?](repeating: value, count: count))
        self.name = name
    }


    /// How many cells, missing ones included. A plain member rather than a `Collection` one: the
    /// column is not a `Collection` (Apple's is not either, and an optional subscript cannot be one)
    /// and the count of its cells is asked for constantly.
    public var count: Int { values.count }
    public var isEmpty: Bool { values.isEmpty }
    public var startIndex: Int { 0 }
    public var endIndex: Int { values.count }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }

    /// A cell, which may be missing. `Element?` is what makes a column that is missing a cell
    /// possible, and it is the SDK's own subscript type.
    public subscript(position: Int) -> Element? {
        get { values[position] }
        set {
            takeUniqueBox()
            values[position] = newValue
        }
    }

    /// Write one cell into the box **every holder shares**, without taking it first.
    ///
    /// This is the slice's setter and nothing else's. A `ColumnSlice` is a *view* of its base, and a
    /// write through it is meant to reach the base: the slice and the column are two holders of one box
    /// on purpose, and that is the whole of what makes a slice a view rather than a copy. A copy of a
    /// column is the opposite case - it is a value, so `subscript(position:)` takes the box first and
    /// the copy ends up independent. Both are right, and mixing them is what the read-only-slice
    /// workaround got wrong in the first place.
    internal mutating func setCellInSharedBox(_ position: Int, _ value: Element?) {
        storage.values[position] = value
    }

    public subscript(bounds: Range<Int>) -> ColumnSlice<Element> {
        ColumnSlice(base: self, range: bounds)
    }

    public var slice: ColumnSlice<Element> { ColumnSlice(base: self, range: 0..<count) }

    /// The column as a `AnyColumn`, which is the SDK's own way in and the port's only public one.
    ///
    /// Carried exactly as the iPhoneOS 26.2 interface has it -
    /// `public func eraseToAnyColumn() -> TabularData.AnyColumn` on `Column<WrappedElement>` (line 523).
    /// The same name on `ColumnSlice` (658) and `DiscontiguousColumnSlice` (1522) answers an
    /// `AnyColumnSlice`, which the port does not declare yet, so those two arrive with it.
    public func eraseToAnyColumn() -> AnyColumn { AnyColumn(self) }

    public mutating func append(_ value: Element) { values.append(value) }
    public mutating func append(contentsOf other: [Element]) { values.append(contentsOf: other) }
    public mutating func reserveCapacity(_ capacity: Int) { values.reserveCapacity(capacity) }

    /// The cells, transformed. A missing cell stays missing: the transform sees the present values
    /// and the gap is carried through, so `map` over a column that is missing a cell does not
    /// invent one and does not lose the place.
    /// The cells, transformed. The closure is given the **cell**, which is `Element?` and for the
    /// optional form `Element??`, and answers `T?`; the result is a `Column<T>` whose element type is
    /// the transform's *unwrapped* return.
    ///
    /// Measured on Apple's own, with a transform answering a different type than the base's:
    ///
    ///     Column<Int>.map { cell -> String? in … }   ->  type Column<String>, wrappedElementType String
    ///     Column<Int>.map { cell -> Int?    in … }   ->  type Column<Int>,    wrappedElementType Int
    ///
    /// so `T` is **inferred from the transform, not pinned to the base**, and the optional in the
    /// transform's answer is the "may be absent" part rather than the column's element type. With the
    /// old `(Element) -> T` the same closure inferred `T == Int?` and produced a `Column<Int?>` whose
    /// `values` is `[Int??]`, so a caller reading `[0]` got a doubly optional where Apple's gives one.
    /// `map` does not compact: a five-cell column maps to five cells, with the gaps in place.
    public func map<T>(_ transform: (Element?) throws -> T?) rethrows -> Column<T> {
        var mapped = [T?]()
        for cell in storage.values { mapped.append(try transform(cell)) }
        return Column<T>(name: name, contents: mapped)
    }

    /// The cells, transformed, with the results that are nil dropped **and** the missing cells
    /// dropped: both are absent, which is what `compactMap` has always meant.
    ///
    /// Measured on Apple's own: a three-cell optional column whose transform doubles answers
    /// `Array<Int>` of length 2. So this **compacts**, where `map` does not, and the result is a
    /// plain array rather than a column.
    public func compactMap<T>(_ transform: (Element?) throws -> T?) rethrows -> [T] {
        var out = [T]()
        for cell in storage.values {
            if let result = try transform(cell) { out.append(result) }
        }
        return out
    }

    /// The cells the predicate keeps, as a **discontiguous slice of the kept positions**.
    ///
    /// Measured on Apple's own: `Column<Int>` of `[5, 1, 4, 20, 3]` filtered on `> 3` answers
    /// `DiscontiguousColumnSlice<Int>` of count 3, and the slice is indexed by the *base's* positions -
    /// `kept[0]` is 5 and `kept[3]` is 20, while `kept[1]` traps with
    /// `Fatal error: position 1 is not a valid slice index`.
    ///
    /// The element type here is the base's, not one inferred from a closure: there is no closure return
    /// to infer it from, and Apple's answers `DiscontiguousColumnSlice<Int>` for a `Column<Int>`.
    public func filter(_ isIncluded: (Element?) throws -> Bool) rethrows -> DiscontiguousColumnSlice<Element> {
        var kept = [Int]()
        for (position, cell) in storage.values.enumerated() {
            if try isIncluded(cell) { kept.append(position) }
        }
        return DiscontiguousColumnSlice(name: name, base: self, indices: kept)
    }
}

/// Equality is over the *values*, not over the boxes: two columns holding the same numbers are the
/// same column whatever boxes they are in, and a row projection that copies a column's values must
/// compare equal to the column it came from.
extension Column: Equatable where Element: Equatable {
    public static func == (lhs: Column, rhs: Column) -> Bool {
        lhs.name == rhs.name && lhs.values == rhs.values
    }
}

extension Column: Sendable where Element: Sendable {}

/// A contiguous run of a column's rows: the column and a range into it.
public struct ColumnSlice<Element>: ColumnProtocol, BidirectionalCollection {
    /// The column the slice is a run of. Held by value and **mutable**, so a write through the slice
    /// reaches the column.
    ///
    /// It used to be a `let` with a read-only subscript, on the reasoning that a slice holds its
    /// base by value so a write would land in a copy and the frame would keep the old value. That
    /// reasoning was right about the bug and wrong about the repair: the bug was a subscript spelled
    /// with a second parameter name (see the file's header), and the honest fix is to let the write
    /// through. A column's slice is a view of that column, and a view that cannot be written is a
    /// copy wearing a view's name.
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

    /// The slice's index space is **the base's positions**, not `0..<count`.
    ///
    /// Measured on Apple's own, over `d = Column<Int>(name: "c", contents: [1, 2, 3])` and
    /// `view = d[1..<3]`:
    ///
    ///     startIndex = 1   endIndex = 3   count = 2
    ///     view[1] = Optional(2)     the base's cell 1
    ///     view[2] = Optional(3)     the base's cell 2
    ///
    /// The same index space as `DiscontiguousColumnSlice`, and for the same reason: a slice is a *view*
    /// of a column, and a view is addressed by the positions of what it views. A port that is dense
    /// where Apple's is base-addressed returns a **different element** for the same expression, to a
    /// real caller and without any error - `view[1]` would answer the base's cell 0. That is the whole of
    /// the gap this closes, and it was invisible here because the suite's slice checks all read `[0]`.
    public var startIndex: Int { range.lowerBound }
    public var endIndex: Int { range.upperBound }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }

    /// A cell of the **base**, addressed by the base's own position, and a **trap** outside the range.
    ///
    /// The host traps here. Measured as its own process, over the same `view = d[1..<3]`, with each
    /// program doing one thing:
    ///
    ///     the slice read only                exit 133
    ///     markers to startIndex/endIndex      marker 3: startIndex=1 endIndex=3 count=2, then exit 133
    ///
    /// and `view[0]` is the read that dies, because 0 is not in `1..<3`. The suite checks that trap the
    /// way it has to be checked - in a child process, comparing the exit status with the host's - rather
    /// than with an `if let` that could never fail.
    public subscript(position: Int) -> Element? {
        get {
            precondition(range.contains(position),
                         "position \(position) is not in the slice's range \(range)")
            return base[position]
        }
        // Through the shared box on purpose: this is a view of `base`, and a write here is a write to
        // the column. A copy of a column takes its own box instead - see `setCellInSharedBox`.
        set {
            precondition(range.contains(position),
                         "position \(position) is not in the slice's range \(range)")
            base.setCellInSharedBox(position, newValue)
        }
    }

    /// A sub-slice of this slice, addressed by the **base's** positions like everything else here.
    ///
    /// Not `range.lowerBound + bounds...`: that was the dense model, where `bounds` was an offset from
    /// the start of the slice. With the index space being the base's positions, `bounds` *is* a range of
    /// the base and is taken as it stands.
    public subscript(bounds: Range<Int>) -> ColumnSlice<Element> {
        ColumnSlice(base: base, range: bounds)
    }

    /// The slice as a column of its own, which **is** a copy: a caller asking for a column of the
    /// slice's values gets values of their own, and `Column(_:)` with a name makes a view of it
    /// instead.
    public var column: Column<Element> { Column<Element>(name: name, values) }

    /// The values, which is what a caller reading a slice as a column needs and what the copy is for.
    /// Read through the range, because the index space *is* the range.
    public var values: [Element] { range.compactMap { base[$0] } }
}

extension ColumnSlice: Equatable where Element: Equatable {}

/// Rows taken from more than one place — a filtered frame, a sorted one, rows named by index — which
/// is what a caller has after anything but a straight range.
public struct DiscontiguousColumnSlice<Element>: ColumnProtocol, BidirectionalCollection {
    public var base: Column<Element>
    /// The positions of the base this slice keeps. Public because it is what a discontiguous slice
    /// *is* - Apple answers one from `filter`, and a caller that cannot see the positions cannot tell
    /// which cells survived.
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
    /// The slice's index set is the **kept positions of the base**, so iteration walks them and never
    /// asks for one that is not kept: over a base of `[5, 1, 4, 20, 3]` filtered on `> 3` the indices
    /// are `[0, 2, 3]`, so the walk is 0, 2, 3 and `endIndex` is 4. `startIndex` and `endIndex` are
    /// the sentinels on either side of that set, and `index(after:)` returns `endIndex` at the end so
    /// a forward walk stops rather than trapping.
    public var startIndex: Int { indices.first ?? 0 }
    public var endIndex: Int { (indices.last ?? -1) + 1 }
    public func index(after i: Int) -> Int { indices.first { $0 > i } ?? endIndex }
    /// The previous kept position, or a **trap** when there is none.
    ///
    /// Measured on Apple's own, over a base of `[5, 1, 4, 20, 3]` filtered on `> 3`:
    ///
    ///     kept.index(before: kept.startIndex)
    ///     TabularData/DiscontiguousColumnSlice.swift:128: Fatal error: Can't move index before startIndex
    ///
    /// An earlier version answered `startIndex` instead, which leaves a backward walk *in place*: the
    /// walk does not terminate, and a `reversed()` over such a slice would spin rather than fail. A
    /// trap is the honest answer and is what the host gives, and it is why a backward walk ends the
    /// same way a forward walk ends - at a boundary it cannot cross.
    public func index(before i: Int) -> Int {
        guard let previous = indices.last(where: { $0 < i }) else {
            preconditionFailure("Can't move index before startIndex")
        }
        return previous
    }

    /// A cell of the **base**, addressed by the base's own position.
    ///
    /// Not `base[indices[position]]`. Measured on the port, over a base of `[5, 1, 4, 20, 3]` filtered
    /// on `> 3` - the same filter and the same data the host was run on:
    ///
    ///     kept[0] = 5      kept[1] = 4      kept[2] = 20      kept[3] traps
    ///
    /// The host answers `kept[0]` and `kept[3]` and **traps on `kept[1]`**, with
    /// `Fatal error: position 1 is not a valid slice index`. So the index space is the base's positions
    /// and a position the slice does not keep is not a position at all. The port's `indices`-indexed
    /// read is a *different slice with the same positions*: it answers `kept[1]` with the cell at base
    /// position 2, and traps at `kept[3]` because the indices array ends first.
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

    /// The cells this slice keeps, read through the base's own positions.
    ///
    /// Not `Array(self)`: the index space is the base's kept positions, so a walk from `startIndex` to
    /// `endIndex` is 0, 2, 3 rather than three consecutive indices. Reading the kept positions is the
    /// same answer without asking the standard library to iterate a sparse space - and it is *not* the
    /// same code as a contiguous slice's `values`, which walks a run and needs no help.
    public var values: [Element] { indices.compactMap { base[$0] } }

    public var column: Column<Element> { Column<Element>(name: name, values) }
}

extension DiscontiguousColumnSlice: Equatable where Element: Equatable {}

/// A column of a frame whose element type the frame does not commit to: what `frame["price"]` gives
/// when the caller has not asked for a type.
public struct AnyColumn: @unchecked Sendable {
    public var name: String

    /// The type the column's elements have, recorded when the column was made and with any
    /// optional layer taken off.
    ///
    /// This is Apple's `wrappedElementType`, and it is the whole reason this type is a box rather
    /// than a wrapper around `[Any]`. Inferred from the values it would be three different answers:
    /// `nil` for an empty column, `nil` for one that mixes types, and `Optional<T>` rather than `T`
    /// for a column of optionals — and the last of those is not an edge case here, because a `Row`
    /// builds its own column out of `[Any?]`. So the type is recorded, and `wrapped` is what the
    /// word means: a `Column<Any?>` reports `Any`.
    public let wrappedElementType: Any.Type

    /// The values, erased but not destroyed. `nil` survives as a nil, which is the only thing that
    /// makes `missingCount` and `isNil(at:)` answerable at all.
    private let storage: [Any?]

    /// Builds the typed column back, under whatever name the box currently has.
    ///
    /// This is the box's inside. It is a closure rather than a stored `Column<T>` because Swift
    /// cannot hold a `Column` of an unknown `T` in a non-generic type, and the alternative - dropping
    /// the type and rebuilding the column from the erased values - is the failure this change exists
    /// to remove: a rebuilt `Column<T>` would be a column of zeros and it would compile. The closure
    /// takes the name so renaming the box renames the typed column it hands back.
    private let makeTyped: (String) -> Any

    internal init<T>(_ column: Column<T>) {
        self.name = column.name
        self.wrappedElementType = T.self
        // An element that is already optional keeps its own nil and is not wrapped a second time.
        // `Row` builds its column from `[Any?]`, so without this the row's values arrive as
        // `Optional(Optional("berlin"))` and every row read describes as an optional of the value.
        // The cells as they are. A `nil` here is a cell with no value and a `.some(nil)` a value
        // that is itself an optional, which is the distinction the SDK keeps; there is nothing to
        // strip, and stripping is what merged the two forms in the first place.
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
        // A discontiguous slice's values are a copy of the columns it names, in that order, so the box
        // holds a column of them. The indices are not kept: an `AnyColumn` is contiguous, which is why
        // a caller that needs the positions asks the slice rather than the column.
        self.init(Column(name: slice.name, slice.values))
    }

    public var count: Int { storage.count }

    /// How many of the elements are nil, counted by asking each position rather than kept as a
    /// tally: a tally would be a second answer to the same question, and a differential would only
    /// ever compare the tally with itself.
    public var missingCount: Int {
        var missing = 0
        for index in storage.indices where storage[index] == nil { missing += 1 }
        return missing
    }

    /// Whether the element at a position is nil. A position outside the column is nil, so an index
    /// past the end reads as missing rather than trapping.
    public func isNil(at index: Int) -> Bool {
        guard storage.indices.contains(index) else { return true }
        return storage[index] == nil
    }

    /// The column as a `Column<T>`, or `nil` when the box does not hold a `T`.
    ///
    /// Apple's signature is non-optional, so a wrong `T` on Apple's type traps. The port answers nil
    /// instead, for two reasons that are the same reason: a trap cannot be tested, and the port's box
    /// is a value a caller can build, so the wrong `T` is reachable. A frame that handed out a
    /// `Column<T>` of anything but `T` is the failure this guards, and the differential checks the
    /// values that come back, not the type that came back.
    public func assumingType<T>(_ type: T.Type) -> Column<T>? {
        guard wrappedElementType == T.self else { return nil }
        return makeTyped(name) as? Column<T>
    }

    /// The values as `[Any]`, which is what a row lookup and a frame's own column-copying read. The
    /// column is erased on purpose — a frame holds `AnyColumn`s and a caller that knows the type
    /// asks for it through `values(as:)`, which answers nil for a column of another type rather than
    /// a value of the wrong one.
    /// The values as the frame stores them, and the payload of each rather than the box.
    ///
    /// `storage` is `[Any?]` so a nil element survives. Handing that back as `[Any]` goes through an
    /// implicit `Any?` -> `Any` conversion that *boxes* the optional rather than taking it off, so
    /// "berlin" arrives as `Optional(Optional("berlin"))` and a row that reads through here describes
    /// as an optional of the value. The optional is taken off here, by hand, and a missing cell stays
    /// a nil instead of becoming a value.
    /// The cells that hold a value, with the missing ones dropped. The public way to read an erased
    /// column's values, since `values(as:)` is internal: the SDK has no such accessor, and a caller
    /// reaching for one would be reaching for a name this port invented.
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

    /// A cell, as `Any?` and **unlabelled**, which is the host's form in both respects.
    ///
    /// Measured on Apple's own, over a present-form `Column<String>` of `["berlin", "paris", "madrid"]`:
    ///
    ///     hostStrings[0]  =  Optional("berlin")
    ///     hostStrings[2]  =  Optional("madrid")
    ///
    /// The value *describes* as an optional because the subscript answers `Any?`, and the port's
    /// answered a bare `Any`, so `berlin` where the host has `Optional("berlin")`. The label is the
    /// other half: `[position: 0]` is an **extraneous argument label** on the host, so Apple's
    /// subscript is `subscript(_ position: Int) -> Any?` and the port's `subscript(position:) -> Any`
    /// was wrong in the label and in the type.
    ///
    /// A cell that is missing is `nil` here rather than a boxed none, which is what makes a caller's
    /// `if let` take the same branch it would on the host.
    public subscript(_ position: Int) -> Any? {
        guard position >= 0 && position < storage.count else { return nil }
        return storage[position]
    }

    /// The values as the type the caller names, or nil when the column is not of that type — which is
    /// the answer a caller needs, because a column of a different type read as this one is how a
    /// frame gives a category column away as a column of zeroes.
    /// The cells as the type the caller names, **of the column's own length**, or `nil` when the
    /// column is not of that type.
    ///
    /// `internal`, because the SDK declares no such accessor: Apple's caller reaches a cell through
    /// the subscript, which is `Element?`, and an invented name that is public is a public API this
    /// port has invented.
    ///
    /// The result is `[T?]` and the length is the column's, deliberately. Dropping the missing cells
    /// would make the result shorter than the column, and every caller that indexes it by row
    /// position would then be reading a different row after the first gap - a column of six cells
    /// missing the third answers five values, and `values[3]` is the fifth row, not the fourth. A
    /// caller that wants only the cells that are there compacts them itself, having chosen to.
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

/// The two questions the box has to ask about an element type, without a way to name the type itself.
private protocol _AlreadyOptional {
    /// The value with its optional taken off, so a `nil` arrives as a `nil` and not as a layer.
    var anyValue: Any? { get }
    /// The type underneath, which is what `wrappedElementType` reports.
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
