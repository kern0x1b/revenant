import Foundation

@dynamicMemberLookup
public struct DataFrame {
    public private(set) var columns: [AnyColumn]
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

    public var shape: (rows: Int, columns: Int) {
        (rows: columns.first?.count ?? 0, columns: columns.count)
    }

    public typealias ColumnType = AnyColumn

    public init() {
        columns = []
    }

    public init<S: Sequence>(columns: S) where S.Element == AnyColumn {
        self.columns = Array(columns)
        settle()
    }

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
        self[columnName] ?? AnyColumn(Column<Int>(name: columnName))
    }

    public func selecting<S: Sequence>(columnNames names: S) -> DataFrame where S.Element == String {
        DataFrame(columns: names.compactMap { self[$0] })
    }

    public func selecting(columnNames names: String...) -> DataFrame {
        selecting(columnNames: names)
    }

    public func dropping(_ names: String...) -> DataFrame {
        DataFrame(columns: columns.filter { !names.contains($0.name) })
    }

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
    public var erasedColumn: AnyColumn { AnyColumn(self) }
}

extension ColumnSlice {
    public var erasedColumn: AnyColumn { AnyColumn(self) }
}

extension DiscontiguousColumnSlice {
    public var erasedColumn: AnyColumn { AnyColumn(self) }
}

extension DataFrame {
    public struct Row {
        public let base: DataFrame
        public let index: Int

        public init(base: DataFrame, index: Int) {
            self.base = base
            self.index = index
        }

        public var asColumn: AnyColumn {
            var row = [Any?]()
            row.reserveCapacity(base.columns.count)
            for column in base.columns {
                let values = column.erasedValues
                row.append(index < values.count ? values[index] : nil)
            }
            return AnyColumn(Column<Any>(name: base.columnNames.joined(separator: ", "), row))
        }

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

        public subscript(bounds: Range<Int>) -> Rows {
            Rows(base: DataFrame(rows: base.rows(Array(bounds))))
        }
    }

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

        public subscript(bounds: Range<Int>) -> DataFrame.Slice {
            DataFrame.Slice(base: base, range: range.lowerBound + bounds.lowerBound ..< range.lowerBound + bounds.upperBound)
        }

        public var frame: DataFrame { base.rows(Array(range)) }
    }
}

extension DataFrame: CustomStringConvertible {
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
}

extension Array {
    public subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}
