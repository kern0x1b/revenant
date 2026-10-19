// DataFrame.swift — a table of named columns and a row count.
//
// The shape is Apple's: `columns` as `[AnyColumn]`, `shape` as a labelled pair, a `Row` looked up by
// name or by `ColumnID<T>`, `indexOfColumn(_:)` for a position, `selecting`/`filter`/`prefix`/
// `suffix` for the projections, and the dynamic member lookup so that `frame.price` is the column
// called "price". The columns themselves are in `Columns.swift`, which says why they are not
// collections.
//
// A frame is keyed by name: adding a column of a name that is already there replaces it, because two
// columns of one name is a frame with a column no caller can choose. And a frame whose columns
// disagree on a height is invalid and says so, rather than padding the short column with a value
// nobody wrote — that is a table of invented data, and every summary over it would be a summary of
// the invention.

import Foundation

@dynamicMemberLookup
public struct DataFrame {
    public private(set) var columns: [AnyColumn]
    /// Why the frame has no rows, when its columns do not agree on a height.
    public private(set) var error: FrameError?

    public enum FrameError: Swift.Error, CustomStringConvertible, Equatable {
        case columnsOfDifferentHeights([Int])

        public var description: String {
            switch self {
            case .columnsOfDifferentHeights(let heights):
                return "The columns are of different lengths: "
                    + heights.map { String($0) }.joined(separator: ", ") + "."
            }
        }
    }

    /// The frame's shape, as a labelled pair: a caller checking a frame wants to know that its
    /// columns agree on a height *and* how many there are, and one number cannot say both.
    public var shape: (rows: Int, columns: Int) {
        (rows: columns.first?.count ?? 0, columns: columns.count)
    }

    public typealias ColumnType = AnyColumn

    public init() {
        columns = []
    }

    /// A frame from columns that are already erased. The typed route is `append(column:)`, which
    /// takes a `Column<T>` or a `ColumnSlice<T>` and erases it; two `init(columns:)` overloads that
    /// differed only in a constraint are ambiguous for a concrete `[AnyColumn]` and name the element
    /// type in the error, so there is one.
    public init<S: Sequence>(columns: S) where S.Element == AnyColumn {
        self.columns = Array(columns)
        settle()
    }

    /// A frame from a run of another frame's rows, keeping the base and the range: a frame is
    /// a view of a view here, and `.frame` is where a caller asks for the copy.
    public init(rows slice: DataFrame) {
        self.columns = slice.columns
        self.error = nil
        settle()
    }

    public init(_ slice: DataFrame.Slice) {
        self.columns = slice.frame.columns
        self.error = nil
        settle()
    }

    private mutating func settle() {
        let heights = Set(columns.map(\.count))
        error = heights.count > 1 ? FrameError.columnsOfDifferentHeights(heights.sorted()) : nil
    }

    public var isValid: Bool { error == nil }
    public var isEmpty: Bool { columns.isEmpty }
    public var count: Int { shape.rows }
    public var columnNames: [String] { columns.map(\.name) }

    /// The position of a column by name, and nil for one that is not there. A position, not a
    /// subscript, so a caller can ask without a column in hand.
    public func indexOfColumn(_ columnName: String) -> Int? {
        columns.firstIndex { $0.name == columnName }
    }

    public func containsColumn(_ name: String) -> Bool { indexOfColumn(name) != nil }
    public func containsColumn<T>(_ id: ColumnID<T>) -> Bool { indexOfColumn(id.name) != nil }

    public func containsColumn<T>(_ name: String, _ type: T.Type) -> Bool {
        self[name]?.values(as: type) != nil
    }

    public subscript(columnName: String) -> AnyColumn? {
        guard let index = indexOfColumn(columnName) else { return nil }
        return columns[index]
    }

    /// The typed column by its identifier, which is the subscript a caller reaches for when it knows
    /// the type. A frame's column that is not of that type gives an empty column rather than a wrong
    /// one: a column of zeroes where the frame holds strings is the failure this avoids, and the
    /// caller who wants to know can ask `containsColumn(_:_:)`.
    public subscript<T>(columnID: ColumnID<T>) -> Column<T> {
        guard let column = self[columnID.name], let values = column.values(as: T.self) else {
            return Column<T>(name: columnID.name)
        }
        return Column<T>(name: columnID.name, contents: values)
    }

    public subscript<T>(columnName: String, type: T.Type) -> Column<T>? {
        guard let column = self[columnName], let values = column.values(as: T.self) else { return nil }
        return Column<T>(name: columnName, contents: values)
    }

    public subscript(dynamicMember columnName: String) -> AnyColumn {
        // Through the optional subscript above: a non-optional one would have to invent a column for
        // a name that is not there, and an invented column of the wrong type is a wrong answer that
        // looks like data.
        self[columnName] ?? AnyColumn(Column<Int>(name: columnName))
    }

    /// A frame of the named columns, in the order they are named. A column that is not there is not
    /// in the result: `selecting` is a projection and a projection cannot invent a column.
    public func selecting<S: Sequence>(columnNames names: S) -> DataFrame where S.Element == String {
        DataFrame(columns: names.compactMap { self[$0] })
    }

    public func selecting(columnNames names: String...) -> DataFrame {
        selecting(columnNames: names)
    }

    public func dropping(_ names: String...) -> DataFrame {
        DataFrame(columns: columns.filter { !names.contains($0.name) })
    }

    /// A column added, or replaced where one of that name is already there.
    public mutating func append(column: AnyColumn) {
        if let index = indexOfColumn(column.name) {
            columns[index] = column
        } else {
            columns.append(column)
        }
        settle()
    }

    public mutating func append<T>(column: Column<T>) {
        append(column: AnyColumn(column))
    }

    public mutating func append<T>(columnID: ColumnID<T>, _ values: [T]) {
        append(column: Column<T>(name: columnID.name, values))
    }

    public mutating func removeColumn(at index: Int) {
        guard columns.indices.contains(index) else { return }
        columns.remove(at: index)
        settle()
    }

    public mutating func removeColumn(_ name: String) {
        guard let index = indexOfColumn(name) else { return }
        columns.remove(at: index)
        settle()
    }

    public subscript(rows range: Range<Int>) -> DataFrame.Slice {
        DataFrame.Slice(base: self, range: range)
    }

    public subscript<R: RangeExpression>(rows range: R) -> DataFrame.Slice where R.Bound == Int {
        DataFrame.Slice(base: self, range: range.relative(to: 0..<count))
    }

    public func prefix(_ maxLength: Int) -> DataFrame.Slice {
        self[rows: 0..<Swift.min(maxLength, count)]
    }

    public func suffix(_ maxLength: Int) -> DataFrame.Slice {
        let start = Swift.max(0, count - maxLength)
        return self[rows: start..<count]
    }

    /// The rows whose column value passes, in the frame's own order and with the repeats kept: a
    /// filter is a projection of the rows and not a reordering of them.
    public func filter(_ isIncluded: (Row) throws -> Bool) rethrows -> DataFrame {
        var keep = [Int]()
        for index in 0..<count where try isIncluded(Row(base: self, index: index)) {
            keep.append(index)
        }
        return rows(keep)
    }

    public func filter<T>(on columnName: String, _ type: T.Type,
                           _ isIncluded: (T?) throws -> Bool) rethrows -> DataFrame {
        let column = self[columnName, T.self]
        var keep = [Int]()
        for index in 0..<count {
            if let cell = column?.values[safe: index], try isIncluded(cell) { keep.append(index) }
        }
        return rows(keep)
    }

    public func filter<T>(on columnID: ColumnID<T>,
                           _ isIncluded: (T?) throws -> Bool) rethrows -> DataFrame {
        try filter(on: columnID.name, T.self, isIncluded)
    }

    /// A frame of the given rows, in the order given.
    public func rows(_ indices: [Int]) -> DataFrame {
        DataFrame(columns: columns.map { column in
            AnyColumn(DiscontiguousColumnSlice(
                name: column.name,
                base: Column<Any>(name: column.name, column.erasedValues),
                indices: indices))
        })
    }

    public var rowSequence: Rows { Rows(base: self) }
}

extension Column {
    /// The column with its element type erased, which is how a frame holds it.
    public var erasedColumn: AnyColumn { AnyColumn(self) }
}

extension ColumnSlice {
    public var erasedColumn: AnyColumn { AnyColumn(self) }
}

extension DiscontiguousColumnSlice {
    public var erasedColumn: AnyColumn { AnyColumn(self) }
}

extension DataFrame {
    /// One row: each column's value at this row, looked up by name or by `ColumnID`.
    public struct Row {
        public let base: DataFrame
        public let index: Int

        public init(base: DataFrame, index: Int) {
            self.base = base
            self.index = index
        }

        /// The row's values as an `AnyColumn` of one row, which is the form every lookup goes
        /// through — a row is a frame of one row, and building that is cheaper than a switch over
        /// the column kinds.
        public var asColumn: AnyColumn {
            var row = [Any?]()
            row.reserveCapacity(base.columns.count)
            for column in base.columns {
                let values = column.erasedValues
                row.append(index < values.count ? values[index] : nil)
            }
            return AnyColumn(Column<Any>(name: base.columnNames.joined(separator: ", "), row))
        }

        /// A cell of one column of this row, which may be missing.
        ///
        /// Read through the column's own subscript, which answers `Any?` and answers **`nil`** for a
        /// cell that has no value. `erasedValues` cannot be used here: it is `[Any]`, so a missing cell
        /// has to become a value, and the one it became was `Optional<Any>.none as Any` - which
        /// *describes* as `nil` and is not `== nil`. Measured against Apple's own, over the ordinary
        /// form of `[1, nil, 3]`:
        ///
        ///     String(describing: f1.rows[1]["a"])  ->  nil
        ///     String(describing: f2.rows[1]["a"])  ->  Optional(nil)   (the optional form)
        ///
        /// so a missing cell and a cell whose value is nil are different answers, and a caller's `if
        /// let` has to take a different branch for each.
        public subscript(columnName: String) -> Any? {
            guard let column = base[columnName], index < column.count else { return nil }
            return column[index]
        }

        public subscript<T>(columnID: ColumnID<T>) -> T? {
            base[columnID].values[safe: index] ?? nil
        }

        public subscript<T>(columnName: String, type: T.Type) -> T? {
            base[columnName, type]?.values[safe: index] ?? nil
        }
    }

    /// The frame's rows, in order — a **random-access** collection, so a caller writes
    /// `for row in frame.rows`.
    ///
    /// `RandomAccessCollection` and not `BidirectionalCollection` because it gives away a
    /// `subscript(bounds:)` where `BidirectionalCollection` makes one a requirement. A frame's rows
    /// are random access — any row is as cheap as any other — so the richer conformance is also the
    /// true one, and it is the one that compiles without the port writing out a subscript the
    /// standard library already has.
    public struct Rows: RandomAccessCollection {
        public let base: DataFrame
        public typealias Element = Row
        public typealias Index = Int
        public typealias Indices = Range<Int>
        public typealias SubSequence = Rows
        public typealias Iterator = IndexingIterator<Rows>

        public init(base: DataFrame) {
            self.base = base
        }

        public var startIndex: Int { 0 }
        public var endIndex: Int { base.count }
        public func index(after i: Int) -> Int { i + 1 }
        public func index(before i: Int) -> Int { i - 1 }
        public var count: Int { base.count }
        public var isEmpty: Bool { base.count == 0 }
        public subscript(position: Int) -> Row { Row(base: base, index: position) }

        /// `RandomAccessCollection` *overrides* `Collection`'s `subscript(bounds:)` — which the
        /// standard library marks `@available(*, unavailable)` — with a requirement of its own, so a
        /// conforming type supplies it. This is the compiler's own note, and it is the whole of every
        /// `unavailable subscript` this file and `Columns.swift` kept hitting.
        public subscript(bounds: Range<Int>) -> Rows {
            Rows(base: DataFrame(rows: base.rows(Array(bounds))))
        }
    }

    /// A run of a frame's rows, which keeps the base and the range rather than copying the columns.
    public struct Slice {
        public let base: DataFrame
        public let range: Range<Int>

        public init(base: DataFrame, range: Range<Int>) {
            self.base = base
            self.range = range
        }

        public var shape: (rows: Int, columns: Int) { (range.count, base.columns.count) }
        public var columnNames: [String] { base.columnNames }
        public var isEmpty: Bool { range.isEmpty }
        public var count: Int { range.count }

        public subscript(columnName: String) -> AnyColumn? { base[columnName] }

        public subscript<T>(columnID: ColumnID<T>) -> ColumnSlice<T> {
            ColumnSlice(base: base[columnID], range: range)
        }

        /// The slice's columns, each one a slice of the frame's own column: a view of a view, and
        /// still a view all the way down, because the range is carried rather than copied.
        public subscript(bounds: Range<Int>) -> DataFrame.Slice {
            DataFrame.Slice(base: base, range: range.lowerBound + bounds.lowerBound ..< range.lowerBound + bounds.upperBound)
        }

        /// The slice as a frame of its own, which copies the rows out of the base: a slice is a view
        /// and a frame owns its columns.
        public var frame: DataFrame { base.rows(Array(range)) }
    }
}

extension DataFrame: CustomStringConvertible {
    /// The frame's shape and its column names, which is what a caller reads first; a frame of a
    /// million rows is not something to print.
    public var description: String {
        let (rows, columns) = shape
        return "DataFrame(" + String(rows) + " rows, " + String(columns) + " columns: "
            + columnNames.joined(separator: ", ") + ")"
    }
}

extension DataFrame: CustomDebugStringConvertible {
    public var debugDescription: String { description }
}

extension DataFrame: Equatable {
    public static func == (lhs: DataFrame, rhs: DataFrame) -> Bool {
        lhs.columnNames == rhs.columnNames
            && zip(lhs.columns, rhs.columns).allSatisfy { left, right in
                String(describing: left.erasedValues) == String(describing: right.erasedValues)
            }
    }
}



extension AnyColumn: @unchecked Sendable {
    // A column holds erased values, and `[Any]` is not `Sendable`; the values themselves are the
    // caller's, copied in, and a frame never mutates one in place behind a caller's back. The
    // conformance is unchecked for that reason and the file says so.
}

extension Array {
    /// A subscript that answers nil rather than trapping, for the places where the index comes from
    /// a frame whose columns may not agree on a height — which is the one case where a frame is
    /// already invalid and a trap would replace a readable error with a crash.
    public subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}
