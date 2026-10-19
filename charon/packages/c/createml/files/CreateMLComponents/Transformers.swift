public protocol ColumnarTransformer {
    var statistics: RowMatrix { get }
    var fittedColumns: [String] { get }

    func fitted(on table: ColumnarTable) throws -> Self

    func transformed(_ table: ColumnarTable) -> ColumnarTable
}

extension ColumnarTransformer {
    static func apply(to table: ColumnarTable, statistics: RowMatrix, fittedColumns: [String],
                      _ transform: (Double, Int, Int) -> Double) -> ColumnarTable {
        var out = ColumnarTable()
        for name in table.columnNames {
            guard case .doubles(let values)? = table.column(name),
                  let column = fittedColumns.firstIndex(of: name), column < statistics.rows else {
                if let original = table.column(name) { out.set(original, named: name) }
                continue
            }
            out.set(.doubles(values.enumerated().map { position, value in
                value.map { transform($0, position, column) }
            }), named: name)
        }
        return out
    }
}

extension TabularTrainingSet {
    public var table: ColumnarTable {
        var table = ColumnarTable()
        for column in 0..<design.columns {
            var values = [Double?](repeating: nil, count: design.rows)
            for row in 0..<design.rows { values[row] = design[row, column] }
            table.set(.doubles(values), named: featureNames[column])
        }
        return table
    }
}

public struct StandardScaler: ColumnarTransformer {
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]

    public init() {
        statistics = RowMatrix(rows: 0, columns: 2)
        fittedColumns = []
    }

    public init(mean: [Double], spread: [Double], columns: [String]) {
        var matrix = RowMatrix(rows: columns.count, columns: 2)
        for index in 0..<columns.count {
            matrix[index, 0] = mean[index]
            matrix[index, 1] = spread[index]
        }
        self.statistics = matrix
        self.fittedColumns = columns
    }

    public func fitted(on training: TabularTrainingSet) throws -> Self {
        try fitted(on: training.table)
    }

    public func fitted(on training: ColumnarTable) throws -> Self {
        var mean = [Double](repeating: 0, count: training.columnNames.count)
        var spread = [Double](repeating: 1, count: training.columnNames.count)
        for (column, name) in training.columnNames.enumerated() {
            guard case .doubles(let values)? = training.column(name) else { continue }
            let present = values.compactMap { $0 }
            let columnSpread = RowMatrix.standardDeviation(present)
            mean[column] = RowMatrix.mean(present)
            spread[column] = columnSpread > 0 ? columnSpread : 1
        }
        return StandardScaler(mean: mean, spread: spread, columns: training.columnNames)
    }

    public func transformed(_ design: RowMatrix) -> RowMatrix {
        var out = RowMatrix(rows: design.rows, columns: design.columns)
        for row in 0..<design.rows {
            for column in 0..<design.columns where column < statistics.rows {
                out[row, column] = (design[row, column] - statistics[column, 0]) / statistics[column, 1]
            }
        }
        return out
    }

    public func transformed(_ table: ColumnarTable) -> ColumnarTable {
        Self.apply(to: table, statistics: statistics, fittedColumns: fittedColumns) { value, row, column in
            (value - statistics[column, 0]) / statistics[column, 1]
        }
    }
}

public struct MinMaxScaler: ColumnarTransformer {
    public var range: ClosedRange<Double>
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]

    public init(range: ClosedRange<Double> = 0...1) {
        self.range = range
        self.statistics = RowMatrix(rows: 0, columns: 2)
        self.fittedColumns = []
    }

    init(lower: [Double], upper: [Double], columns: [String], range: ClosedRange<Double> = 0...1) {
        var matrix = RowMatrix(rows: columns.count, columns: 2)
        for index in 0..<columns.count {
            matrix[index, 0] = lower[index]
            matrix[index, 1] = upper[index]
        }
        self.range = range
        self.statistics = matrix
        self.fittedColumns = columns
    }

    public func fitted(keepingRangeOn training: ColumnarTable) throws -> Self {
        let fitted = try fitted(on: training)
        return MinMaxScaler(lower: (0..<fitted.statistics.rows).map { fitted.statistics[$0, 0] },
                            upper: (0..<fitted.statistics.rows).map { fitted.statistics[$0, 1] },
                            columns: fitted.fittedColumns,
                            range: range)
    }

    public func fitted(on training: TabularTrainingSet) throws -> Self {
        try fitted(on: training.table)
    }

    public func fitted(on table: ColumnarTable) throws -> Self {
        var lower = [Double](repeating: 0, count: table.columnNames.count)
        var upper = [Double](repeating: 1, count: table.columnNames.count)
        for (position, name) in table.columnNames.enumerated() {
            guard let column = table.column(name), let values = column.numeric else { continue }
            let present = values.compactMap { $0 }
            lower[position] = present.min() ?? 0
            upper[position] = present.max() ?? 1
        }
        return MinMaxScaler(lower: lower, upper: upper, columns: table.columnNames, range: range)
    }

    public func transformed(_ table: ColumnarTable) -> ColumnarTable {
        let low = range.lowerBound, high = range.upperBound
        return Self.apply(to: table, statistics: statistics, fittedColumns: fittedColumns) { value, row, column in
            let from = statistics[column, 0]
            let spread = statistics[column, 1] - from
            guard spread != 0 else { return value }
            return low + (value - from) / spread * (high - low)
        }
    }

    public func transformed(_ design: RowMatrix) -> RowMatrix {
        var out = RowMatrix(rows: design.rows, columns: design.columns)
        for row in 0..<design.rows {
            for column in 0..<design.columns where column < statistics.rows {
                let low = statistics[column, 0]
                let spread = statistics[column, 1] - low
                guard spread != 0 else { continue }
                let unit = (design[row, column] - low) / spread
                out[row, column] = range.lowerBound + unit * (range.upperBound - range.lowerBound)
            }
        }
        return out
    }
}

public struct MaxAbsScaler: ColumnarTransformer {
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]

    public init() {
        statistics = RowMatrix(rows: 0, columns: 1)
        fittedColumns = []
    }

    init(magnitude: [Double], columns: [String]) {
        var matrix = RowMatrix(rows: columns.count, columns: 1)
        for index in 0..<columns.count { matrix[index, 0] = magnitude[index] }
        self.statistics = matrix
        self.fittedColumns = columns
    }

    public func fitted(on training: TabularTrainingSet) throws -> Self {
        try fitted(on: training.table)
    }

    public func fitted(on table: ColumnarTable) throws -> Self {
        var magnitude = [Double](repeating: 1, count: table.columnNames.count)
        for (position, name) in table.columnNames.enumerated() {
            guard let column = table.column(name), let values = column.numeric else { continue }
            let present = values.compactMap { $0 }
            let largest = values.compactMap { $0 }.map { abs($0) }.max() ?? 0
            magnitude[position] = largest > 0 ? largest : 1
        }
        return MaxAbsScaler(magnitude: magnitude, columns: table.columnNames)
    }

    public func transformed(_ table: ColumnarTable) -> ColumnarTable {
        Self.apply(to: table, statistics: statistics, fittedColumns: fittedColumns) { value, row, column in
            value / statistics[column, 0]
        }
    }

    public func transformed(_ design: RowMatrix) -> RowMatrix {
        var out = RowMatrix(rows: design.rows, columns: design.columns)
        for row in 0..<design.rows {
            for column in 0..<design.columns where column < statistics.rows {
                out[row, column] = design[row, column] / statistics[column, 0]
            }
        }
        return out
    }
}

public struct RobustScaler: ColumnarTransformer {
    public private(set) var quantileRange: ClosedRange<Double>
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]

    public init(quantileRange: ClosedRange<Double> = 0.25...0.75) {
        self.quantileRange = quantileRange
        statistics = RowMatrix(rows: 0, columns: 2)
        fittedColumns = []
    }

    init(quantileRange: ClosedRange<Double>, centre: [Double], spread: [Double], columns: [String]) {
        var matrix = RowMatrix(rows: columns.count, columns: 2)
        for index in 0..<columns.count {
            matrix[index, 0] = centre[index]
            matrix[index, 1] = spread[index]
        }
        self.quantileRange = quantileRange
        self.statistics = matrix
        self.fittedColumns = columns
    }

    public func fitted(on training: TabularTrainingSet) throws -> Self {
        try fitted(on: training.table)
    }

    public func fitted(on table: ColumnarTable) throws -> Self {
        var centre = [Double](repeating: 0, count: table.columnNames.count)
        let scale = Double(quantileRange.upperBound - quantileRange.lowerBound)
        var spread = [Double](repeating: scale, count: table.columnNames.count)
        for (position, name) in table.columnNames.enumerated() {
            guard let column = table.column(name), let values = column.numeric else { continue }
            let present = values.compactMap { $0 }
            centre[position] = Self.median(present)
        }
        return RobustScaler(quantileRange: quantileRange, centre: centre, spread: spread, columns: table.columnNames)
    }

    public func transformed(_ table: ColumnarTable) -> ColumnarTable {
        Self.apply(to: table, statistics: statistics, fittedColumns: fittedColumns) { value, row, column in
            let centre = statistics[column, 0]
            let spread = statistics[column, 1]
            var result = centre.isFinite ? value - centre : value
            if spread.isFinite && spread != 0 { result /= spread }
            return result
        }
    }

    public func transformed(_ design: RowMatrix) -> RowMatrix {
        var out = RowMatrix(rows: design.rows, columns: design.columns)
        for row in 0..<design.rows {
            for column in 0..<design.columns where column < statistics.rows {
                out[row, column] = (design[row, column] - statistics[column, 0]) / statistics[column, 1]
            }
        }
        return out
    }

    public static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

public struct OneHotEncoder: ColumnarTransformer {
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]
    private let categories: [String: [String]]

    public init() {
        statistics = RowMatrix(rows: 0, columns: 0)
        fittedColumns = []
        categories = [:]
    }

    init(categories: [String: [String]], columns: [String]) {
        self.categories = categories
        self.fittedColumns = columns
        var width = 0
        for (_, list) in categories { width += list.count }
        self.statistics = RowMatrix(rows: width, columns: 1)
    }

    public func categories(of column: String) -> [String] { categories[column] ?? [] }

    public func fitted(on training: ColumnarTable) throws -> Self {
        var found = [String: [String]]()
        for name in training.columnNames {
            guard case .strings? = training.column(name) else { continue }
            guard let column = training.column(name) else { continue }
            var seen = Set<String>()
            var ordered = [String]()
            for value in column.categorical.compactMap({ $0 }) where seen.insert(value).inserted {
                ordered.append(value)
            }
            found[name] = ordered
        }
        return OneHotEncoder(categories: found, columns: training.columnNames)
    }

    public func transformed(_ design: RowMatrix) -> RowMatrix {
        design
    }

    public func transformed(_ table: ColumnarTable) -> ColumnarTable {
        var out = ColumnarTable()
        for name in table.columnNames {
            guard let list = categories[name], let column = table.column(name) else {
                if let column = table.column(name) { out.set(column, named: name) }
                continue
            }
            let values = column.categorical
            for category in list {
                out.set(.doubles(values.map { value in value == category ? 1.0 : 0.0 }),
                        named: "\(name)_\(category)")
            }
        }
        return out
    }
}

public struct OrdinalEncoder: ColumnarTransformer {
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]
    private let order: [String: [String]]

    public init() {
        statistics = RowMatrix(rows: 0, columns: 0)
        fittedColumns = []
        order = [:]
    }

    init(order: [String: [String]], columns: [String]) {
        self.order = order
        self.fittedColumns = columns
        var width = 0
        for (_, list) in order { width += list.count }
        self.statistics = RowMatrix(rows: width, columns: 1)
    }

    public func order(of column: String) -> [String] { self.order[column] ?? [] }

    public func fitted(on training: ColumnarTable) throws -> Self {
        var found = [String: [String]]()
        for name in training.columnNames {
            guard case .strings? = training.column(name) else { continue }
            guard let column = training.column(name) else { continue }
            var seen = Set<String>()
            var ordered = [String]()
            for value in column.categorical.compactMap({ $0 }) where seen.insert(value).inserted {
                ordered.append(value)
            }
            found[name] = ordered
        }
        return OrdinalEncoder(order: found, columns: training.columnNames)
    }

    public func transformed(_ table: ColumnarTable) -> ColumnarTable {
        var out = ColumnarTable()
        for name in table.columnNames {
            guard let list = order[name], let column = table.column(name) else {
                if let column = table.column(name) { out.set(column, named: name) }
                continue
            }
            out.set(.doubles(column.categorical.map { value in
                guard let value = value, let rank = list.firstIndex(of: value) else { return nil }
                return Double(rank)
            }), named: name)
        }
        return out
    }
}

public struct NumericImputer: ColumnarTransformer {
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]
    public private(set) var imputedEverything: [String]

    public init() {
        statistics = RowMatrix(rows: 0, columns: 1)
        fittedColumns = []
        imputedEverything = []
    }

    init(value: [Double], columns: [String], empty: [String]) {
        var matrix = RowMatrix(rows: columns.count, columns: 1)
        for index in 0..<columns.count { matrix[index, 0] = value[index] }
        self.statistics = matrix
        self.fittedColumns = columns
        self.imputedEverything = empty
    }

    public func value(of column: String) -> Double? {
        guard let index = fittedColumns.firstIndex(of: column), index < statistics.rows else { return nil }
        return statistics[index, 0]
    }

    public func fitted(on table: ColumnarTable) throws -> Self {
        var value = [Double](repeating: 0, count: table.columnNames.count)
        var empty = [String]()
        for (position, name) in table.columnNames.enumerated() {
            guard let column = table.column(name), let values = column.numeric else { continue }
            let present = values.compactMap { $0 }
            if present.isEmpty {
                empty.append(name)
                value[position] = 0
            } else {
                value[position] = present.reduce(0, +) / Double(present.count)
            }
        }
        return NumericImputer(value: value, columns: table.columnNames, empty: empty)
    }

    public func transformed(_ table: ColumnarTable) -> ColumnarTable {
        var out = ColumnarTable()
        for name in table.columnNames {
            guard case .doubles(let values)? = table.column(name),
                  let index = fittedColumns.firstIndex(of: name), index < statistics.rows else {
                if let column = table.column(name) { out.set(column, named: name) }
                continue
            }
            let fill = statistics[index, 0]
            out.set(.doubles(values.map { $0 ?? fill }), named: name)
        }
        return out
    }

}

public struct LinearTransformer: ColumnarTransformer {
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]

    public init() {
        statistics = RowMatrix(rows: 0, columns: 2)
        fittedColumns = []
    }

    init(scale: [Double], offset: [Double], columns: [String]) {
        var matrix = RowMatrix(rows: columns.count, columns: 2)
        for index in 0..<columns.count {
            matrix[index, 0] = scale[index]
            matrix[index, 1] = offset[index]
        }
        self.statistics = matrix
        self.fittedColumns = columns
    }

    public func scale(of column: String) -> Double? {
        guard let index = fittedColumns.firstIndex(of: column), index < statistics.rows else { return nil }
        return statistics[index, 0]
    }

    public func offset(of column: String) -> Double? {
        guard let index = fittedColumns.firstIndex(of: column), index < statistics.rows else { return nil }
        return statistics[index, 1]
    }

    public func fitted(on table: ColumnarTable) throws -> Self {
        var scale = [Double](repeating: 1, count: table.columnNames.count)
        var offset = [Double](repeating: 0, count: table.columnNames.count)
        for (position, name) in table.columnNames.enumerated() {
            guard let column = table.column(name), let values = column.numeric else { continue }
            let present = values.compactMap { $0 }
            guard present.count > 1 else { continue }
            let mean = present.reduce(0, +) / Double(present.count)
            let spread = RowMatrix.standardDeviation(present)
            guard spread > 0 else { continue }
            scale[position] = 1 / spread
            offset[position] = -mean / spread
        }
        return LinearTransformer(scale: scale, offset: offset, columns: table.columnNames)
    }

    public func transformed(_ design: RowMatrix) -> RowMatrix {
        var out = RowMatrix(rows: design.rows, columns: design.columns)
        for row in 0..<design.rows {
            for column in 0..<design.columns where column < statistics.rows {
                out[row, column] = statistics[column, 0] * design[row, column] + statistics[column, 1]
            }
        }
        return out
    }

    public func transformed(_ table: ColumnarTable) -> ColumnarTable {
        Self.apply(to: table, statistics: statistics, fittedColumns: fittedColumns) { value, row, column in
            statistics[column, 0] * value + statistics[column, 1]
        }
    }
}
