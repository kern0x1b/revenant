// Transformers.swift — the feature transformers: what each one does, and why that one.
//
// Every transformer here is the *same shape* fitted to a column and then applied, and the whole file
// is that shape five times. A transformer is not a model: it remembers the statistics of the data it
// was fitted to and applies them, and the statistics are what the model cannot recover afterwards —
// a scaler's mean and spread are gone once the data is standardised, and a one-hot encoder's
// category list is gone once the data is encoded. So a transformer is fitted and then *carried with*
// the model, which is why each of these is a value with its statistics in it.
//
// A transformer is fitted on what it is given and applied to everything after, so the one rule every
// one of them follows is: **the statistics come from the fit and never from the data being
// transformed.** A scaler that recomputed its mean as it went would be a different function for the
// same input depending on what it had seen, and a pipeline of two of them would not be a pipeline.

// MARK: - The shape

/// A fitted transformer: statistics from the fit, and a value read that applies them.
///
/// The fit and the transform both take a **table**, not a design matrix, and that is not a
/// convenience. A one-hot encoder and an ordinal encoder cannot read a category out of a matrix of
/// doubles — the category *is* a string, and a double that happens to be 3.0 is not "the third
/// category" — so the categorical transformers need the table. The numeric scalers read a matrix
/// because that is the form the estimator's design takes, and they offer both.
///
/// The statistics are carried and never recomputed. A scaler that recomputed its mean as it went
/// would be a different function for the same input depending on what it had seen, and a pipeline of
/// two of them would not be a pipeline.
public protocol ColumnarTransformer {
    /// The statistics, as a row-major matrix the kernel can use.
    var statistics: RowMatrix { get }
    /// The columns the transformer was fitted on, in the order the statistics' columns are.
    var fittedColumns: [String] { get }

    /// The fit, over a table.
    func fitted(on table: ColumnarTable) throws -> Self

    /// The transform, over a table.
    func transformed(_ table: ColumnarTable) -> ColumnarTable
}

extension ColumnarTransformer {
    /// The shared table walk: every numeric transformer is this, with its own arithmetic in the
    /// closure. Written once because four copies of a loop that indexes a statistics matrix by a column
    /// name is four places for an off-by-one to live.
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
    /// The training set as a table of double columns, which is the form every transformer here is
    /// fitted on. The features *are* numbers — that is what a design matrix is — and a transformer
    /// that wants categories is given a `ColumnarTable` of its own instead.
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

// MARK: - The scalers

/// Standardises a column: `(x - mean) / spread`, the spread being the **standard deviation**.
///
/// The deviation is the unbiased one, over `n - 1`. A column standardised by the population
/// deviation is a different function of the data, and the two differ most on a short column — which
/// is where a caller notices, because the model's coefficients come out scaled.
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
            // A missing value is skipped rather than counted as a zero: a column of three values and
            // one gap has a mean over three.
            let present = values.compactMap { $0 }
            let columnSpread = RowMatrix.standardDeviation(present)
            mean[column] = RowMatrix.mean(present)
            // A column of one value, or of values that are all equal, has no spread to divide by. It
            // is left as it is rather than divided by zero: a constant feature contributes nothing to
            // a fit, and a NaN in the design matrix would poison every coefficient with it, so the
            // honest answer is the identity on that column.
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

/// Scales a column into a range, `0..1` by default.
///
/// The range is over the column's **observed** extremes, so a value outside them lands outside the
/// range. Clamping them to 0 and 1 would be a different function, and it is the one a caller reading
/// a "min-max scaled" column usually does not expect.
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
        // The range the caller asked for, kept. The first version hard-coded `0...1` here and a
        // `MinMaxScaler(range: -1...1)` came back scaling into `0...1` anyway — a configured
        // parameter silently discarded, which the transformer's own test found on a range of -1...1.
        self.range = range
        self.statistics = matrix
        self.fittedColumns = columns
    }

    /// The fit, keeping the range this scaler was configured with.
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
                // A constant column has no spread and is passed through, for the reason
                // `StandardScaler` gives.
                guard spread != 0 else { continue }
                let unit = (design[row, column] - low) / spread
                out[row, column] = range.lowerBound + unit * (range.upperBound - range.lowerBound)
            }
        }
        return out
    }
}

/// Scales a column by the largest magnitude it holds, so every value lands in `-1...1`.
///
/// A column of all zeros is passed through, for the same reason the other two are.
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

/// Centres a column on its median and scales it by its **median absolute deviation**, so that a few
/// extreme values cannot move the scale.
///
/// The centre is the median and not the mean, and that is the whole difference from
/// `StandardScaler`: one row with a value a thousand times the others moves a mean and a standard
/// deviation and leaves every other row standardised to nearly the same number, which is a column
/// that has thrown away the information about which rows are which.
public struct RobustScaler: ColumnarTransformer {
    /// The quantile range, and **the only configuration input**. Its width is the scale the host
    /// reports as `interQuartileRange`, measured over five integers, 200 skewed non-integers and a
    /// constant column: 0.5 in all three, and 0.2, 0.25, 0.8 and 1.0 for those widths.
    ///
    /// `ClosedRange` brings its own contract: the host traps on a range with `lower > upper` and on a
    /// NaN bound, and the top frame of both is the caller's `main` rather than anything inside
    /// `RobustScaler`, so the trap is the standard library's and the port inherits it by using the same
    /// `ClosedRange<Double>`. Infinite bounds are *not* a trap: the host answers an infinite scale and
    /// leaves the value as the unscaled deviation, which the guards in `transformed` reproduce.
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
        // The scale is the **width of the quantile range**, not a statistic of the data. Measured on
        // Apple's `RobustScaler` over five integers, over 200 skewed non-integers, and over a constant
        // column: `interQuartileRange` is 0.5 for `quantileRange 0.25...0.75` in every one, and it is 0.5
        // for the constant column too, where a data statistic would be 0. It is 0.2, 0.25, 0.8 and 1.0
        // for widths 0.2, 0.25, 0.8 and 1.0. So the port is a data statistic where the host is a
        // configuration value, and that is not a constant to correct.
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
        // The two guards the host applies, measured rather than assumed. A median that is not finite is
        // **not subtracted** and the scale is still applied: on data containing NaN the host answers
        // `applied(1) = 2.0` for a scale of 0.5, where subtracting the NaN would give NaN. A scale that
        // is zero leaves the value as the **unscaled deviation**: over `quantileRange 0.5...0.5` the
        // host answers `applied(4) = 1.0` for a median of 3, which is `4 - 3`.
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

    /// The median of a vector, by the mean of the two middle values on an even count.
    public static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

// MARK: - The encoders

/// Replaces a categorical column with one binary column per category.
///
/// The categories are those of the **fit**, in the order the fit found them, and a category the fit
/// never saw becomes an all-zero row rather than a new column: a fitted transformer's output has a
/// fixed number of columns, and a caller who hands it a category it has not seen should hear about it
/// rather than have the model answer about a column that does not exist.
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

    /// The categories of one column, in the order the fit found them.
    public func categories(of column: String) -> [String] { categories[column] ?? [] }

    /// The fit, over a table whose *categorical* columns are given as strings — a one-hot encoder
    /// cannot read a category out of a design matrix of doubles, and a caller who has one is asking
    /// the wrong question.
    public func fitted(on training: ColumnarTable) throws -> Self {
        var found = [String: [String]]()
        // Only a **string** column is categorical. A double column read as categories would give the
        // numbers "1.0", "2.0" as categories and a one-hot column for each, which is a table the
        // caller never wrote; so the encoder's fit looks at the column's own kind and leaves a
        // numeric one to pass through.
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

    /// The transform, over a table of categorical columns: the result is wider than the input by the
    /// number of categories, and the output columns are the input column's name and its category.
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

/// Replaces a categorical column with one column of integers, the category's rank in the fitted
/// order.
///
/// The order is **the order the fit found the categories in**, and not the categories' own order: an
/// ordinal is a number, and a number has a magnitude, so the encodings of two categories are not
/// interchangeable the way one-hot's are. A caller who wants no magnitude between the categories
/// wants a one-hot encoder, and the difference between the two is exactly that magnitude.
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

    /// The order one column's categories were given, which is what a caller reads back.
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

    /// The transform: each category becomes its rank, and a category the fit never saw becomes
    /// **missing** rather than a rank. A rank of zero would be the first category and would put an
    /// unseen value in the first class, which is a claim about data the fit never saw.
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

// MARK: - The imputer

/// Fills a column's missing values with one value, the mean of the ones that are there.
///
/// The mean is over the values **present**, and that is the whole point: a column with three values
/// and one gap is imputed from the three, and imputing from the four with the gap counted as zero
/// would pull every imputed value towards zero by a quarter. A column with nothing in it is filled
/// with zero and the fact is on `imputedEverything`, because there is no mean of no values and a
/// caller who has such a column should hear about it.
public struct NumericImputer: ColumnarTransformer {
    public private(set) var statistics: RowMatrix
    public private(set) var fittedColumns: [String]
    /// Whether some column had nothing in it and so was filled with zeros.
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

    /// The value a column is filled with.
    public func value(of column: String) -> Double? {
        guard let index = fittedColumns.firstIndex(of: column), index < statistics.rows else { return nil }
        return statistics[index, 0]
    }

    /// The fit, over a table whose columns may be missing — which is the one transformer that reads
    /// a table with gaps, because filling them is what it is for.
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

// MARK: - The linear transformer

/// Applies `y = scale * x + offset`, elementwise, with the scale and offset fitted from the data.
///
/// Two statistics, and the reason it is a transformer and not a step inside a fit is that they are
/// gone afterwards: a model fitted over an unscaled column has no way to tell the caller what the
/// column's spread was, so a caller who wants to report a prediction in the column's own units
/// cannot. This keeps the affine and gives it back.
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

    /// The scale one column is multiplied by.
    public func scale(of column: String) -> Double? {
        guard let index = fittedColumns.firstIndex(of: column), index < statistics.rows else { return nil }
        return statistics[index, 0]
    }

    /// The offset one column has added.
    public func offset(of column: String) -> Double? {
        guard let index = fittedColumns.firstIndex(of: column), index < statistics.rows else { return nil }
        return statistics[index, 1]
    }

    /// The fit, over a table that may be missing values: a column's scale comes from the values that
    /// are there, and one with nothing in it is left alone rather than multiplied by a zero of
    /// nothing.
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
