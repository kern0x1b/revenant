import Foundation
import CreateMLComponents

public enum JoinType: String, CaseIterable, Hashable {
    case inner
    case left
    case right
    case outer
}

public typealias Aggregator = MLDataTableAggregator

public struct MLDataTableAggregator {
    public var operations: [Operations]
    public var columnName: String

    public init(operations: Operations..., of columnNamed: String) {
        self.operations = operations
        self.columnName = columnNamed
    }
}

extension MLDataTable {
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

        var isArgmin: Bool {
            if case .argmin = self { return true }
            return false
        }

        public func aggregatedColumn(of column: String) -> String {
            self == .count ? "Count" : column + name.capitalized
        }

        public var outputColumn: String? {
            switch self {
            case .argmin(let column), .argmax(let column), .dictionaryMerge(let column): return column
            default: return nil
            }
        }

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

public enum PackType {
    case dictionary
    case sequence
}

public struct MLDataTable {
    public private(set) var columns: [String: MLUntypedColumn]
    public private(set) var columnNames: [String]
    public private(set) var error: MLDataTableError?
    public var isValid: Bool { error == nil }

    public init() {
        columns = [:]
        columnNames = []
    }

    public init(namedColumns: [String: MLUntypedColumn]) throws {
        try self.init(building: namedColumns)
    }

    init(building namedColumns: [String: MLUntypedColumn]) {
        columns = namedColumns
        columnNames = Array(namedColumns.keys)
        settle()
    }

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

    public var columnTypes: [String: MLDataValue.ValueType] {
        var out = [String: MLDataValue.ValueType]()
        for name in columnNames {
            guard let type = columns[name]?.type, type != .invalid else { continue }
            out[name] = type
        }
        return out
    }

    public var size: (rows: Int, columns: Int) {
        (rows: columnNames.first.flatMap { columns[$0]?.count } ?? 0, columns: columnNames.count)
    }

    public var count: Int { size.rows }
    public var isEmpty: Bool { size.rows == 0 }

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

    public func join(with other: MLDataTable, on key: String, type: JoinType) throws -> MLDataTable {
        guard let mineKey = columns[key] else { throw MLDataTableError.noSuchColumn(key) }
        guard let theirsKey = other.columns[key] else { throw MLDataTableError.noSuchColumn(key) }

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

        struct Pair { var mine: Int?; var theirs: Int? }
        var pairs = [Pair]()
        var theirRowsUsed = Set<Int>()
        for (index, value) in mineKey.values.enumerated() {
            let otherRow = theirsByKey[value]
            if type == .inner, otherRow == nil { continue }
            pairs.append(Pair(mine: index, theirs: otherRow))
            if let otherRow = otherRow { theirRowsUsed.insert(otherRow) }
        }
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

    public func group(columnsNamed names: [String], aggregators: [MLDataTableAggregator]) throws -> MLDataTable {
        for name in names where columns[name] == nil {
            throw MLDataTableError.noSuchColumn(name)
        }
        for aggregator in aggregators where columns[aggregator.columnName] == nil {
            throw MLDataTableError.noSuchColumn(aggregator.columnName)
        }
        var groups = [[MLDataValue]: [Int]]()
        for index in 0..<count {
            let key = names.map { columns[$0]?[index] ?? .invalid }
            groups[key, default: []].append(index)
        }
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
    func select(_ indices: [Int]) -> MLUntypedColumn {
        let inRange = indices.map { $0 >= 0 && $0 < count ? $0 : 0 }
        return MLUntypedColumn(inRange.map { self[$0] }, name: name)
    }

    func renamed(_ newName: String) -> MLUntypedColumn {
        MLUntypedColumn(values, name: newName)
    }
}

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
