// MLDataTable.swift — the table CreateML's own API is written against.
//
// A table is a name, an ordered list of columns and a row count. Everything else — a join, a group, a
// stratified split, a CSV read — is a way of building one of those or of reading one back out.
//
// Two things are worth saying about how this is put together. The columns are untyped here, because
// a training table's columns really are untyped: the release decides a column's kind from its cells,
// and a column read from a CSV is a column of strings until something looks at it. And the table
// knows its own `error`: a table that could not be built is still a table, and `isValid` answers NO
// while the reason stays readable, which is what a caller needs in order to tell an empty table from
// a broken one.

import Foundation
import CreateMLComponents

/// How two tables are joined.
public enum JoinType: String, CaseIterable, Hashable {
    case inner
    case left
    case right
    case outer
}

/// An aggregate over a group of rows: the column it reads and what it does with each group's values.
public typealias Aggregator = MLDataTableAggregator

public struct MLDataTableAggregator {
    /// What the aggregate does. An array, because one aggregator may name several operations over
    /// the same column — a sum and a mean of a price in one group.
    public var operations: [Operations]
    /// The column the operations read.
    public var columnName: String

    public init(operations: Operations..., of columnNamed: String) {
        self.operations = operations
        self.columnName = columnNamed
    }
}

extension MLDataTable {
    /// The aggregate operations, named as the framework names them.
    public enum MLDataTableAggregatorOperations: String, CaseIterable {
        case sum
        case mean
        case min
        case max
        case count
        case distinctCount
        case variance
        case stdev
        case argmin
        case argmax
        case randomlySelectOne
        case sequenceMerge
    }
}

extension MLDataTableAggregator {
    /// One thing an aggregate does.
    ///
    /// The three that name a column — `argmin`, `argmax` and `dictionaryMerge` — are given the
    /// column *they* write, which is what the framework's own spelling has: the operation reads
    /// `columnName` and answers into the column it names, so a caller can ask for "the index of the
    /// smallest price" and get the index in a column of its own beside the sum.
    public enum Operations: Hashable {
        case sum
        case mean
        case min
        case max
        case count
        case distinctCount
        case variance
        case stdev
        case argmin(outputColumn: String)
        case argmax(outputColumn: String)
        case randomlySelectOne
        case sequenceMerge
        case dictionaryMerge(valueColumn: String)

        /// Whether this is the index-of-the-smallest operation, which is the one question the two
        /// index operations share and the only way to tell them apart inside `apply`.
        var isArgmin: Bool {
            if case .argmin = self { return true }
            return false
        }

        /// The name of the column this operation's answer is written into, given the column it
        /// reads: the column's own name and the operation's, run together, in the framework's own
        /// camel case — a price summed is `priceSum` and a price averaged is `priceMean`.
        ///
        /// `count` is the exception and is named for the operation alone, as `Count`. Measured: the
        /// host groups eight rows by city with a sum, a mean and a count over the ids and answers the
        /// columns `city`, `Count`, `priceMean`, `priceSum` — and `Count` carries no column of its own
        /// because the count of anything in a group is the same number whichever column is read.
        public func aggregatedColumn(of column: String) -> String {
            self == .count ? "Count" : column + name.capitalized
        }

        /// The name of the column this operation writes, and nil for the ones that write into the
        /// aggregated column itself.
        public var outputColumn: String? {
            switch self {
            case .argmin(let column), .argmax(let column), .dictionaryMerge(let column): return column
            default: return nil
            }
        }

        /// The name the framework's own enumeration spells this operation with, and which the
        /// registry's rows are written against.
        public var name: String {
            switch self {
            case .sum: return "sum"
            case .mean: return "mean"
            case .min: return "min"
            case .max: return "max"
            case .count: return "count"
            case .distinctCount: return "distinctCount"
            case .variance: return "variance"
            case .stdev: return "stdev"
            case .argmin: return "argmin"
            case .argmax: return "argmax"
            case .randomlySelectOne: return "randomlySelectOne"
            case .sequenceMerge: return "sequenceMerge"
            case .dictionaryMerge: return "dictionaryMerge"
            }
        }

        /// The operation, run over a group's values, with the generator a randomised one needs.
        ///
        /// Every operation skips the cells that are missing rather than treating a missing value as
        /// zero: a mean over a group with three values and one gap is a mean of three, and a sum
        /// that counted the gap would answer a question about a table nobody wrote.
        public func apply(to values: [MLDataValue], generator: inout SeededGenerator) -> MLDataValue {
            let present = values.filter { $0.isValid }
            switch self {
            case .sum:
                return present.reduce(into: MLDataValue.double(0)) { total, value in
                    if let double = value.doubleValue { total = .double((total.doubleValue ?? 0) + double) }
                }
            case .mean:
                let doubles = present.compactMap { $0.doubleValue }
                guard !doubles.isEmpty else { return .invalid }
                return .double(doubles.reduce(0, +) / Double(doubles.count))
            case .min:
                return present.min { valueOrder($0, $1) == .orderedAscending } ?? .invalid
            case .max:
                return present.max { valueOrder($0, $1) == .orderedAscending } ?? .invalid
            case .count:
                return .int(Int64(present.count))
            case .distinctCount:
                return .int(Int64(Set(present).count))
            case .variance, .stdev:
                let doubles = present.compactMap { $0.doubleValue }
                guard doubles.count > 1 else { return .invalid }
                let mean = doubles.reduce(0, +) / Double(doubles.count)
                let spread = doubles.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(doubles.count - 1)
                return .double(self == .variance ? spread : spread.squareRoot())
            case .argmin, .argmax:
                // The index of the smallest or largest, into the group's values *as they were*, so a
                // missing cell still occupies its place: an index into a compacted list would point
                // at a different cell than the one it names.
                let ordered = present.indices.sorted { valueOrder(present[$0], present[$1]) == .orderedAscending }
                guard let position = self.isArgmin ? ordered.first : ordered.last else { return .invalid }
                return .int(Int64(values.firstIndex(of: present[position]) ?? 0))
            case .randomlySelectOne:
                return present.isEmpty ? .invalid : present[generator.nextInteger(below: present.count)]
            case .sequenceMerge:
                var merged = [MLDataValue]()
                for value in present {
                    if case .sequence(let elements) = value { merged.append(contentsOf: elements) }
                }
                return merged.isEmpty ? .invalid : .sequence(merged)
            case .dictionaryMerge:
                var merged = [String: MLDataValue]()
                for value in present {
                    if case .dictionary(let storage) = value {
                        for (key, element) in storage { merged[key] = element }
                    }
                }
                return merged.isEmpty ? .invalid : .dictionary(merged)
            }
        }
    }
}

/// The order two values stand in, which is the table's own: numbers by value, strings by their own
/// collation, and equal across kinds, because there is no order between a string and a number.
func valueOrder(_ lhs: MLDataValue, _ rhs: MLDataValue) -> ComparisonResult {
    if let a = lhs.intValue, let b = rhs.intValue {
        return a < b ? .orderedAscending : (a > b ? .orderedDescending : .orderedSame)
    }
    if let a = lhs.doubleValue, let b = rhs.doubleValue {
        return a < b ? .orderedAscending : (a > b ? .orderedDescending : .orderedSame)
    }
    if let a = lhs.stringValue, let b = rhs.stringValue {
        return a < b ? .orderedAscending : (a > b ? .orderedDescending : .orderedSame)
    }
    return .orderedSame
}

/// How a table's columns are packed into single cells.
public enum PackType {
    case dictionary
    case sequence
}

/// A table of training data.
public struct MLDataTable {
    public private(set) var columns: [String: MLUntypedColumn]
    /// The column names in the order the table holds them, which is the order they were added in and
    /// not an alphabetical order: a table written with its target last keeps its target last.
    public private(set) var columnNames: [String]
    public private(set) var error: MLDataTableError?
    public var isValid: Bool { error == nil }

    public init() {
        columns = [:]
        columnNames = []
    }

    /// A table from columns that are already named, in the order the dictionary gives them.
    ///
    /// Declared `throws` because the framework's is and a call site that compiles against both must
    /// handle the failure — but the columns here are already built, so there is nothing that can
    /// fail: the work is in `building`, and this initialiser is the spelling of it that a caller sees.
    public init(namedColumns: [String: MLUntypedColumn]) throws {
        try self.init(building: namedColumns)
    }

    /// The same table, without the failure a caller cannot cause. Every internal construction goes
    /// through here, so no caller of the port's own ever has to write `try!` for a path that cannot
    /// fail.
    init(building namedColumns: [String: MLUntypedColumn]) {
        columns = namedColumns
        columnNames = Array(namedColumns.keys)
        settle()
    }

    /// A table from a dictionary of columns, one per key.
    public init(dictionary: [String: [MLDataValue]]) throws {
        var built = [String: MLUntypedColumn]()
        var order = [String]()
        for (name, values) in dictionary {
            built[name] = MLUntypedColumn(values, name: name)
            order.append(name)
        }
        self.columns = built
        self.columnNames = order
        settle()
    }

    /// The kind of each column, by name, and nil for one that is not there.
    public var columnTypes: [String: MLDataValue.ValueType] {
        var out = [String: MLDataValue.ValueType]()
        for name in columnNames {
            guard let type = columns[name]?.type, type != .invalid else { continue }
            out[name] = type
        }
        return out
    }

    /// The table's shape, as the framework spells it: a labelled pair, and not a single row count.
    /// Both numbers are here because a caller checking a table wants to know that its columns agree
    /// on a height *and* how many of them there are, and one number cannot say both.
    public var size: (rows: Int, columns: Int) {
        (rows: columnNames.first.flatMap { columns[$0]?.count } ?? 0, columns: columnNames.count)
    }

    public var count: Int { size.rows }
    public var isEmpty: Bool { size.rows == 0 }

    /// The table's rows, each a dictionary of its values.
    public var rows: [[String: MLDataValue]] {
        (0..<count).map { index in
            columnNames.reduce(into: [:]) { row, name in
                row[name] = columns[name]?[index] ?? .invalid
            }
        }
    }

    private mutating func settle() {
        let heights = Set(columnNames.compactMap { columns[$0]?.count })
        if heights.count > 1 {
            // Columns of different heights have no rows in common, so the table has no rows at all.
            // It says so rather than padding one column with missing values, which would be a table
            // of invented data.
            error = .columnsOfDifferentHeights(heights.sorted())
        } else {
            error = nil
        }
    }

    public mutating func addColumn(_ column: MLUntypedColumn, named name: String) {
        if columns[name] == nil { columnNames.append(name) }
        columns[name] = column.renamed(name)
        settle()
    }

    public mutating func removeColumn(named name: String) {
        columns.removeValue(forKey: name)
        columnNames.removeAll { $0 == name }
        settle()
    }

    public mutating func renameColumn(named name: String, to newName: String) {
        guard let column = columns[name] else { return }
        columns.removeValue(forKey: name)
        columns[newName] = column.renamed(newName)
        columnNames = columnNames.map { $0 == name ? newName : $0 }
        settle()
    }

    public func column(_ name: String) -> MLUntypedColumn? { columns[name] }

    public subscript(columnName: String) -> MLUntypedColumn? { columns[columnName] }
    public subscript(columnName: String, columnType: MLDataValue.ValueType) -> MLUntypedColumn? {
        columns[columnName]?.type == columnType ? columns[columnName] : nil
    }
    public subscript(columnNames names: [String]) -> MLDataTable {
        var built = [String: MLUntypedColumn]()
        for name in names {
            if let column = columns[name] { built[name] = column }
        }
        return MLDataTable(building: built)
    }
    public subscript(rows range: Range<Int>) -> MLDataTable {
        var built = [String: MLUntypedColumn]()
        for name in columnNames {
            if let column = columns[name] { built[name] = column[range] }
        }
        return MLDataTable(building: built)
    }
    /// The rows whose mask is true.
    ///
    /// The column's own mask subscripts take a mask *column*, which is what the SDK declares and
    /// what a caller filtering a table passes; an array of flags is wrapped into that column here
    /// rather than becoming a second spelling of the same thing.
    public subscript(mask: [Bool]) -> MLDataTable {
        let flags = MLDataColumn(mask)
        var built = [String: MLUntypedColumn]()
        for name in columnNames {
            if let source = columns[name] { built[name] = source[flags] }
        }
        return MLDataTable(building: built)
    }

    public mutating func append(contentsOf other: MLDataTable) {
        for name in other.columnNames {
            guard let incoming = other.columns[name] else { continue }
            if let existing = columns[name] {
                var joined = existing
                joined.append(contentsOf: incoming)
                columns[name] = joined
            } else {
                addColumn(incoming, named: name)
            }
        }
        settle()
    }

    public func prefix(_ count: Int) -> MLDataTable { self[rows: 0..<Swift.min(count, self.count)] }

    public func suffix(_ count: Int) -> MLDataTable {
        let start = Swift.max(0, self.count - count)
        return self[rows: start..<self.count]
    }

    /// A table of the given rows, in the given order and with repeats kept: a bootstrap sample and a
    /// random split are both "these rows, in this order", and neither is a subsequence.
    public func rows(_ indices: [Int]) -> MLDataTable {
        var built = [String: MLUntypedColumn]()
        for name in columnNames {
            if let column = columns[name] { built[name] = column.select(indices) }
        }
        return MLDataTable(building: built)
    }

    public func map(_ transform: (String, MLUntypedColumn) -> MLUntypedColumn) -> MLDataTable {
        var built = [String: MLUntypedColumn]()
        for name in columnNames {
            guard let column = columns[name] else { continue }
            built[name] = transform(name, column)
        }
        return MLDataTable(building: built)
    }

    public func exclude(_ columnsToExclude: [String], of type: MLDataValue.ValueType? = nil) -> MLDataTable {
        var built = [String: MLUntypedColumn]()
        for name in columnNames {
            guard !columnsToExclude.contains(name), let column = columns[name] else { continue }
            if let type = type, column.type != type { continue }
            built[name] = column
        }
        return MLDataTable(building: built)
    }

    public func dropMissing() -> MLDataTable {
        var keep = [Bool](repeating: true, count: count)
        for name in columnNames {
            guard let column = columns[name] else { continue }
            for (index, value) in column.values.enumerated() where !value.isValid {
                keep[index] = false
            }
        }
        return self[keep]
    }

    public func dropDuplicates() -> MLDataTable {
        var seen = Set<[MLDataValue]>()
        var keep = [Bool](repeating: false, count: count)
        for index in 0..<count {
            let row = columnNames.map { columns[$0]?[index] ?? .invalid }
            if seen.insert(row).inserted { keep[index] = true }
        }
        return self[keep]
    }

    public func fillMissing(columnNamed name: String, with value: MLDataValue) -> MLDataTable {
        guard let column = columns[name] else { return self }
        var filled = self
        filled.addColumn(column.fillMissing(with: value), named: name)
        return filled
    }

    public func sort(columnNamed name: String, byIncreasingOrder: Bool = true) -> MLDataTable {
        guard let column = columns[name] else { return self }
        let order = column.values.indices.sorted { left, right in
            let order = valueOrder(column.values[left], column.values[right])
            return byIncreasingOrder ? order == .orderedAscending : order == .orderedDescending
        }
        return rows(order)
    }

    /// Two tables joined on a column of each.
    ///
    /// The four kinds differ only in which rows survive, and they are written once here rather than
    /// four times: every kind keeps this table's rows in this table's order, and `right` and `outer`
    /// then add the other table's rows that matched nothing. The other table's columns answer a
    /// missing value for a row that did not match, and the join key is not carried twice — it is
    /// already the joined column, and a second copy under the same name would be a table with two
    /// columns of one name and no way to say which is which.
    ///
    /// A key that appears twice on either side is refused: the join would have to invent a pairing,
    /// and the two rows it invented would be the ones a caller least expects to see.
    public func join(with other: MLDataTable, on key: String, type: JoinType) throws -> MLDataTable {
        guard let mineKey = columns[key] else { throw MLDataTableError.noSuchColumn(key) }
        guard let theirsKey = other.columns[key] else { throw MLDataTableError.noSuchColumn(key) }

        // A key that appears twice on either side is refused: the join would have to invent a
        // pairing, and the two rows it invented would be the ones a caller least expects to see.
        func indexByKey(_ column: MLUntypedColumn) throws -> [MLDataValue: Int] {
            var seen = Set<MLDataValue>()
            var out = [MLDataValue: Int]()
            for (index, value) in column.values.enumerated() {
                guard seen.insert(value).inserted else { throw MLDataTableError.duplicateKey(value.description) }
                out[value] = index
            }
            return out
        }
        let theirsByKey = try indexByKey(theirsKey)
        _ = try indexByKey(mineKey)

        // The join is decided once, here, as a list of row *pairs*: which of this table's rows
        // survive, and which row of the other table each of them is paired with — or nil for a row
        // that matched nothing. Every column of the result then walks that one list, which is what
        // keeps the result's columns the same height as each other. Deriving a column's length from
        // this table's own height and then filling only the rows that were kept leaves the result
        // with this table's height and the other table's values in the wrong places, and that is
        // what the host differential named on an inner and a right join.
        struct Pair { var mine: Int?; var theirs: Int? }
        var pairs = [Pair]()
        var theirRowsUsed = Set<Int>()
        for (index, value) in mineKey.values.enumerated() {
            let otherRow = theirsByKey[value]
            if type == .inner, otherRow == nil { continue }
            pairs.append(Pair(mine: index, theirs: otherRow))
            if let otherRow = otherRow { theirRowsUsed.insert(otherRow) }
        }
        // `right` and `outer` then add the other table's rows that matched nothing, after this
        // table's — which is the order the framework's own answers come in.
        //
        // `right` is *this* table's rows replaced by the other table's, not this table's rows with
        // the other one's appended. Measured: joining eight rows against three whose keys all match,
        // the host's `right` answers three rows and the host's `outer` answers eight, and a reading
        // in which `right` appended the other table's unmatched rows would have answered eight for
        // both. So `right` starts from the other table's rows, and this table's columns are filled
        // in for the ones that matched.
        if type == .right {
            pairs.removeAll()
            for otherRow in theirsKey.values.indices {
                let mine = mineKey.values.firstIndex(of: theirsKey.values[otherRow])
                pairs.append(Pair(mine: mine, theirs: otherRow))
            }
        } else if type == .outer {
            for otherRow in theirsKey.values.indices where !theirRowsUsed.contains(otherRow) {
                pairs.append(Pair(mine: nil, theirs: otherRow))
            }
        }

        let theirNames = other.columnNames.filter { $0 != key }
        var out = MLDataTable()
        for name in columnNames {
            if name == key {
                // The key is the other table's value for a row that came from there, and this
                // table's for a row that came from here: the two spell the same value, and taking
                // this table's own for a row it does not have would put a missing value where the
                // join has the answer.
                out.addColumn(MLUntypedColumn(pairs.map { pair in
                    if let theirs = pair.theirs { return theirsKey.values[theirs] }
                    return mineKey.values[pair.mine ?? 0]
                }, name: name), named: name)
            } else if let column = columns[name] {
                out.addColumn(MLUntypedColumn(pairs.map { pair in
                    pair.mine.map { column.values[$0] } ?? .invalid
                }, name: name), named: name)
            }
        }
        for name in theirNames {
            guard let column = other.columns[name] else { continue }
            out.addColumn(MLUntypedColumn(pairs.map { pair in
                pair.theirs.map { column.values[$0] } ?? .invalid
            }, name: name), named: name)
        }
        return out
    }

    /// One row per distinct combination of the named columns, with the aggregations beside them.
    public func group(columnsNamed names: [String], aggregators: [MLDataTableAggregator]) throws -> MLDataTable {
        for name in names where columns[name] == nil {
            throw MLDataTableError.noSuchColumn(name)
        }
        for aggregator in aggregators where columns[aggregator.columnName] == nil {
            throw MLDataTableError.noSuchColumn(aggregator.columnName)
        }
        var groups = [[MLDataValue]: [Int]]()
        for index in 0..<count {
            // The key of a group is the tuple of its rows' values in the named columns, which is why
            // a `[MLDataValue]` and not a `MLDataValue`: grouping by two columns and by one are
            // different questions and a single value cannot tell them apart.
            let key = names.map { columns[$0]?[index] ?? .invalid }
            groups[key, default: []].append(index)
        }
        // The groups come out in key order, not in the order the rows happened to arrive in. The
        // host's do — measured, grouping eight rows by city answers `berlin`, `madrid`, `paris` for a
        // file whose first city is `berlin`, its second `paris` and its fifth `berlin` again — and a
        // group's order is part of what a caller reads the table back as.
        let order = groups.keys.sorted { left, right in
            for (a, b) in zip(left, right) {
                let order = valueOrder(a, b)
                if order != .orderedSame { return order == .orderedAscending }
            }
            return left.count < right.count
        }
        var out = MLDataTable()
        for (position, name) in names.enumerated() {
            out.addColumn(MLUntypedColumn(order.map { $0[position] }, name: name), named: name)
        }
        // Each operation writes into a column named after the one it reads and the operation itself
        // — `price` summed is `price_sum` — because two operations over one column have two answers
        // and a table has one column per name. The three that name a column of their own, the index
        // of the smallest, the index of the largest and the merged dictionaries, write into that.
        for aggregator in aggregators {
            let source = columns[aggregator.columnName]!
            for operation in aggregator.operations {
                let target = operation.outputColumn ?? operation.aggregatedColumn(of: aggregator.columnName)
                if out.column(target) != nil { continue }
                let values = order.map { key -> MLDataValue in
                    let groupValues = source.select(groups[key]!).values
                    var generator = SeededGenerator(seed: SeededGenerator.timestampSeed())
                    return operation.apply(to: groupValues, generator: &generator)
                }
                out.addColumn(MLUntypedColumn(values, name: target), named: target)
            }
        }
        return out
    }

    /// A random split of the rows into two tables.
    ///
    /// Every row is drawn **independently with probability `proportion`**, not a cut at
    /// `count * proportion` of a shuffle. That is measured and it is the difference between a split
    /// whose halves are the sizes a caller asked for and one whose halves scatter: over two thousand
    /// rows at a half the host answers 968, 1004 and 999 for three seeds, and a cut would answer
    /// 1000 every time. At eight rows and three quarters the host answers five, which a cut at
    /// `8 * 0.75 = 6` cannot be, and the host's own answer is reproducible for a seed — so the draw
    /// is random and the seed is what makes it repeatable.
    public func randomSplit(by proportion: Double, seed: UInt64) -> (MLDataTable, MLDataTable) {
        var generator = SeededGenerator(seed: seed)
        let share = Swift.max(0, Swift.min(1, proportion))
        var taken = [Int]()
        var left = [Int]()
        for index in 0..<count {
            if generator.nextUniform() < share { taken.append(index) } else { left.append(index) }
        }
        return (rows(taken), rows(left))
    }

    /// A random split that keeps the groups' proportions, so that a table whose rows come from
    /// different sources is not split into a training set of one and a validation set of another.
    public func stratifiedSplit(proportions: [Double], on groups: MLUntypedColumn,
                                seed: UInt64) -> [MLDataTable] {
        var generator = SeededGenerator(seed: seed)
        var byValue = [MLDataValue: [Int]]()
        for (index, value) in groups.values.enumerated() {
            byValue[value, default: []].append(index)
        }
        var taken = [[Int]](repeating: [], count: proportions.count)
        for value in byValue.keys.sorted(by: { valueOrder($0, $1) == .orderedAscending }) {
            var indices = byValue[value]!
            generator.shuffle(&indices)
            var start = 0
            for (position, proportion) in proportions.enumerated() {
                let share = position == proportions.count - 1
                    ? indices.count - start
                    : Int((Double(indices.count) * proportion).rounded())
                taken[position].append(contentsOf: indices[start..<Swift.min(indices.count, start + share)])
                start += share
            }
        }
        return taken.map { rows($0) }
    }
}

extension MLUntypedColumn {
    /// A column's cells at the given rows, in that order, with repeats kept.
    func select(_ indices: [Int]) -> MLUntypedColumn {
        let inRange = indices.map { $0 >= 0 && $0 < count ? $0 : 0 }
        return MLUntypedColumn(inRange.map { self[$0] }, name: name)
    }

    func renamed(_ newName: String) -> MLUntypedColumn {
        MLUntypedColumn(values, name: newName)
    }
}

/// Why a table could not be built or read.
public enum MLDataTableError: Error, CustomStringConvertible, Equatable {
    case columnsOfDifferentHeights([Int])
    case noSuchColumn(String)
    case duplicateKey(String)
    case noAggregators
    case unreadableFile(String)
    case badCSVRow(Int, String)
    case noTargetColumn(String)

    public var description: String {
        switch self {
        case .columnsOfDifferentHeights(let heights):
            return "The columns are of different lengths: \(heights)."
        case .noSuchColumn(let name):
            return "There is no column \"\(name)\" in the table."
        case .duplicateKey(let key):
            return "The join key \"\(key)\" is not unique, so the join would have to invent a pairing."
        case .noAggregators:
            return "No aggregators were given, so there is nothing to add to the groups."
        case .unreadableFile(let path):
            return "The file at \(path) could not be read."
        case .badCSVRow(let number, let text):
            return "Row \(number) of the CSV does not have as many fields as the header: \(text)."
        case .noTargetColumn(let name):
            return "There is no target column \"\(name)\" in the table."
        }
    }
}
