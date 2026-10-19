// ColumnarTable.swift — the table the estimators train on, and the one `MLDataTable` and `DataFrame`
// both are.
//
// The public tabular API of CreateMLComponents takes a `DataFrame` and the public API of CreateML
// takes an `MLDataTable`, and the two are the same table with two names. Neither of those two types
// is the place the arithmetic should live: a decision tree has no opinion about whether a column is
// a `Column<Double>` or an `MLUntypedColumn`, and putting the split search in either of them means
// writing it twice when the other one arrives.
//
// So the training core is here, over a column of one of the four kinds a tabular column really is —
// integers, doubles, strings, or a column of sequences — and both public table types are adapters
// onto it. One copy of the arithmetic, and the public surface is a projection of it.

import Foundation

/// One column of a training table.
///
/// The four cases are the four things a column of a training table can hold on this release. A
/// missing value is `nil` in a column of Int, Double or String, and it is a distinct case here
/// rather than a sentinel, because "this observation has no value" and "this observation has the
/// value 0" have to be told apart by a split search.
public enum TrainingColumn {
    case integers([Int64?])
    case doubles([Double?])
    case strings([String?])

    public var count: Int {
        switch self {
        case .integers(let values): return values.count
        case .doubles(let values): return values.count
        case .strings(let values): return values.count
        }
    }

    /// The column as doubles, where it has a numeric reading at all. Strings do not.
    public var numeric: [Double?]? {
        switch self {
        case .integers(let values): return values.map { $0.map(Double.init) }
        case .doubles(let values): return values
        case .strings: return nil
        }
    }

    /// The column as strings, which is how a categorical label and a categorical feature are both
    /// compared and grouped: Apple's own representation of a category is its string, and matching
    /// that is what makes a split threshold comparable with a host's.
    public var categorical: [String?] {
        switch self {
        case .integers(let values): return values.map { $0.map(String.init) }
        case .doubles(let values): return values.map { $0.map { Self.describe($0) } }
        case .strings(let values): return values
        }
    }

    /// A double as the string a label column spells it in.
    ///
    /// Apple's tabular format prints a double through its shortest round-tripping decimal form and
    /// drops a whole number's `.0`, so that a column of doubles read from a CSV and a column of the
    /// same values read as integers share one spelling — which is what lets a label column be
    /// either. `1e-05` rather than `1.0e-05` for the same reason: the exponent carries no `.0`.
    public static func describe(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return "\(value)"
    }

    public var isNumeric: Bool { numeric != nil }
}

/// A table the estimators train on: named columns of one height.
public struct ColumnarTable {
    public private(set) var order: [String]
    public private(set) var columns: [String: TrainingColumn]

    public init(order: [String] = [], columns: [String: TrainingColumn] = [:]) {
        self.order = order
        self.columns = columns
    }

    public init(_ columns: [String: [Double?]], order: [String]? = nil) {
        self.order = order ?? columns.keys.sorted()
        self.columns = self.order.reduce(into: [:]) { $0[$1] = .doubles(columns[$1] ?? []) }
    }

    public var count: Int { order.first.map { columns[$0]?.count ?? 0 } ?? 0 }
    public var isEmpty: Bool { count == 0 }
    public var columnNames: [String] { order }
    public func column(_ name: String) -> TrainingColumn? { columns[name] }

    public subscript(name: String) -> TrainingColumn? { columns[name] }

    public mutating func set(_ column: TrainingColumn, named name: String) {
        if columns[name] == nil { order.append(name) }
        columns[name] = column
    }

    public mutating func removeColumn(named name: String) {
        columns.removeValue(forKey: name)
        order.removeAll { $0 == name }
    }

    public mutating func renameColumn(named name: String, to newName: String) {
        guard let column = columns[name] else { return }
        columns.removeValue(forKey: name)
        columns[newName] = column
        order = order.map { $0 == name ? newName : $0 }
    }

    /// The rows `indices` names, in that order and with repeats kept: a bootstrap sample and a
    /// random split are both "these rows, in this order", and neither is a subsequence.
    public func rows(_ indices: [Int]) -> ColumnarTable {
        var taken = ColumnarTable()
        taken.order = order
        for name in order {
            guard let source = columns[name] else { continue }
            taken.columns[name] = source.select(indices)
        }
        return taken
    }

    /// A mask applied to the rows.
    public func rows(where mask: [Bool]) -> ColumnarTable {
        rows((0..<count).filter { mask[$0] })
    }

    public mutating func append(_ other: ColumnarTable) {
        for name in other.order {
            let combined: TrainingColumn
            switch (columns[name], other.columns[name]) {
            case (.some(.integers(let mine)), .some(.integers(let theirs))):
                combined = .integers(mine + theirs)
            case (.some(.doubles(let mine)), .some(.doubles(let theirs))):
                combined = .doubles(mine + theirs)
            case (.some(.strings(let mine)), .some(.strings(let theirs))):
                combined = .strings(mine + theirs)
            case (.none, .some(let theirs)):
                combined = theirs
            case (.some(let mine), .some(let theirs)):
                // Two columns of the same name and different kinds are a table with a column that
                // has no reading, which is what the release reports as an unreadable table.
                combined = mine
            default:
                combined = .strings([nil])
            }
            set(combined, named: name)
        }
    }
}

extension TrainingColumn {
    /// A column of the same kind carrying `indices` of this one, in that order.
    public func select(_ indices: [Int]) -> TrainingColumn {
        let inRange = indices.map { $0 >= 0 && $0 < count ? $0 : 0 }
        switch self {
        case .integers(let values): return .integers(inRange.map { values[$0] })
        case .doubles(let values): return .doubles(inRange.map { values[$0] })
        case .strings(let values): return .strings(inRange.map { values[$0] })
        }
    }
}

// MARK: - The design matrix and the targets a supervised fit is made of

/// One fitted model's view of its data: the features as a matrix, the label as a vector, and the
/// feature names the matrix's columns came from.
public struct TabularTrainingSet {
    public var featureNames: [String]
    public var design: RowMatrix
    public var targets: [Double]
    /// The label of each row as a string, for a classifier. A regressor's is empty.
    public var targetLabels: [String]
    public var isClassification: Bool

    public init(featureNames: [String], design: RowMatrix, targets: [Double],
                targetLabels: [String] = [], isClassification: Bool = false) {
        self.featureNames = featureNames
        self.design = design
        self.targets = targets
        self.targetLabels = targetLabels
        self.isClassification = isClassification
    }
}

/// Why a table cannot be fitted, in the words of the framework that refuses it.
public enum TabularFittingError: Error, CustomStringConvertible, Equatable {
    case noTargetColumn(String)
    case noFeatureColumn(String)
    case featureIsCategorical(String)
    case targetIsNotNumeric(String)
    case noFeatureColumns
    case tooFewRows(Int)
    case targetHasMissingValues(Int)
    case featureHasMissingValues(String, Int)
    case allLabelsIdentical
    case noCategories

    public var description: String {
        switch self {
        case .noTargetColumn(let name):
            return "The target column \"\(name)\" is not in the table."
        case .noFeatureColumn(let name):
            return "The feature column \"\(name)\" is not in the table."
        case .featureIsCategorical(let name):
            return "The feature column \"\(name)\" holds a category, and a numeric feature was asked for."
        case .targetIsNotNumeric(let name):
            return "The target column \"\(name)\" holds a category, and a numeric target was asked for."
        case .noFeatureColumns:
            return "No feature columns were given, and the table has none besides the target."
        case .tooFewRows(let count):
            return "\(count) rows is too few to train on."
        case .targetHasMissingValues(let count):
            return "The target column has \(count) missing values."
        case .featureHasMissingValues(let name, let count):
            return "The feature column \"\(name)\" has \(count) missing values."
        case .allLabelsIdentical:
            return "Every label is the same, so there is nothing to learn."
        case .noCategories:
            return "The target column has no value in it."
        }
    }
}

/// Builds the design matrix and the targets out of a table.
///
/// The rules are the ones a caller can see: the feature columns are the ones named, or every column
/// but the target; a missing value in a feature is refused here with the column and the count named,
/// because an estimator that silently averaged over the gaps would be answering a question about
/// different data. A missing *label* is refused the same way, and for the same reason: there is no
/// honest prediction to make for a row whose answer is not written down.
public enum TabularFitting {
    public static func make(_ table: ColumnarTable,
                            targetColumn: String,
                            featureColumns: [String]?,
                            classification: Bool) throws -> TabularTrainingSet {
        guard let target = table.column(targetColumn) else {
            throw TabularFittingError.noTargetColumn(targetColumn)
        }
        guard target.count > 0 else { throw TabularFittingError.noCategories }
        let names = featureColumns ?? table.columnNames.filter { $0 != targetColumn }
        guard !names.isEmpty else { throw TabularFittingError.noFeatureColumns }
        guard table.count > 1 else { throw TabularFittingError.tooFewRows(table.count) }

        var numeric: [[Double?]] = []
        for name in names {
            guard let column = table.column(name) else {
                throw TabularFittingError.noFeatureColumn(name)
            }
            guard let values = column.numeric else {
                throw TabularFittingError.featureIsCategorical(name)
            }
            let missing = values.filter { $0 == nil }.count
            if missing > 0 {
                throw TabularFittingError.featureHasMissingValues(name, missing)
            }
            numeric.append(values)
        }

        var targets: [Double] = []
        var labels: [String] = []
        if classification {
            for value in target.categorical {
                guard let label = value else { throw TabularFittingError.targetHasMissingValues(1) }
                labels.append(label)
                targets.append(0)
            }
            let distinct = Set(labels)
            guard distinct.count > 1 else { throw TabularFittingError.allLabelsIdentical }
        } else {
            guard let values = target.numeric else {
                throw TabularFittingError.targetIsNotNumeric(targetColumn)
            }
            let missing = values.filter { $0 == nil }.count
            if missing > 0 {
                throw TabularFittingError.targetHasMissingValues(missing)
            }
            targets = values.map { $0! }
        }

        let rows = table.count
        var design = RowMatrix(rows: rows, columns: names.count)
        for (column, values) in numeric.enumerated() {
            for row in 0..<rows {
                design[row, column] = values[row] ?? 0
            }
        }
        return TabularTrainingSet(featureNames: names, design: design, targets: targets,
                                  targetLabels: labels, isClassification: classification)
    }
}


extension TabularTrainingSet {
    /// The same table over `rows`, renumbered from zero.
    ///
    /// A forest's bootstrap sample sees some rows twice and misses others, and the rows it does see
    /// are a *sub-table* — its own row indices, its own target vector, its own design matrix — not
    /// the whole table with some rows marked. A view would have carried the full matrix into every
    /// tree and made the tree's own row numbers mean nothing, which is the difference between a
    /// sample and a mask and is worth a copy of the indices.
    public func sample(rows indices: [Int]) -> TabularTrainingSet {
        let total = design.rows
        let inRange = indices.map { $0 >= 0 && $0 < total ? $0 : 0 }
        var taken = RowMatrix(rows: inRange.count, columns: design.columns)
        for (position, source) in inRange.enumerated() {
            for column in 0..<design.columns {
                taken[position, column] = design[source, column]
            }
        }
        return TabularTrainingSet(featureNames: featureNames, design: taken,
                                  targets: inRange.map { targets[$0] },
                                  targetLabels: inRange.compactMap { targetLabels.indices.contains($0) ? targetLabels[$0] : nil },
                                  isClassification: isClassification)
    }
}
