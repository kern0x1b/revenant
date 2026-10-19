import Foundation

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

    public var numeric: [Double?]? {
        switch self {
        case .integers(let values): return values.map { $0.map(Double.init) }
        case .doubles(let values): return values
        case .strings: return nil
        }
    }

    public var categorical: [String?] {
        switch self {
        case .integers(let values): return values.map { $0.map(String.init) }
        case .doubles(let values): return values.map { $0.map { Self.describe($0) } }
        case .strings(let values): return values
        }
    }

    public static func describe(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return "\(value)"
    }

    public var isNumeric: Bool { numeric != nil }
}

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

    public func rows(_ indices: [Int]) -> ColumnarTable {
        var taken = ColumnarTable()
        taken.order = order
        for name in order {
            guard let source = columns[name] else { continue }
            taken.columns[name] = source.select(indices)
        }
        return taken
    }

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
                combined = mine
            default:
                combined = .strings([nil])
            }
            set(combined, named: name)
        }
    }
}

extension TrainingColumn {
    public func select(_ indices: [Int]) -> TrainingColumn {
        let inRange = indices.map { $0 >= 0 && $0 < count ? $0 : 0 }
        switch self {
        case .integers(let values): return .integers(inRange.map { values[$0] })
        case .doubles(let values): return .doubles(inRange.map { values[$0] })
        case .strings(let values): return .strings(inRange.map { values[$0] })
        }
    }
}

public struct TabularTrainingSet {
    public var featureNames: [String]
    public var design: RowMatrix
    public var targets: [Double]
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
