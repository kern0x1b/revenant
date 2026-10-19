import Foundation
import PortCreateMLComponents

var checks = 0
var failures = 0

func check(_ what: String, _ equal: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if !equal {
        failures += 1
        print("FAIL \(what)\(detail().isEmpty ? "" : ": \(detail())")")
    }
}

func checkEqual<T: Equatable>(_ what: String, port: T, is expected: T) {
    check(what, port == expected, "port=\(port) expected=\(expected)")
}

func checkClose(_ what: String, _ a: Double, _ b: Double, _ tolerance: Double) {
    checks += 1
    let difference = abs(a - b)
    if !(difference <= tolerance) {
        failures += 1
        print("FAIL \(what): the port answers \(a), the arithmetic says \(b), a difference of \(difference)")
    }
}

struct MeanEstimator: Estimator, SupervisedEstimator {
    struct Fitted: Equatable {
        var mean: Double
        var columns: [String]
    }
    var annotationColumn: String

    func fitted(on input: ColumnarTable) throws -> Fitted {
        let values = input.column(annotationColumn)?.numeric?.compactMap { $0 } ?? []
        precondition(!values.isEmpty, "the mean estimator needs a target column with values in it")
        return Fitted(mean: values.reduce(0, +) / Double(values.count), columns: input.columnNames)
    }
}

struct CountingEstimator: UpdatableSupervisedEstimator {
    struct Fitted: Equatable {
        var updates: Int
        var preprocessorScale: Double?
    }
    var annotationColumn: String

    func makeTransformer() -> Fitted { Fitted(updates: 0, preprocessorScale: nil) }

    func fitted(on input: ColumnarTable) throws -> Fitted {
        _ = input
        return Fitted(updates: 0, preprocessorScale: nil)
    }

    func update(_ transformer: inout Fitted, with input: ColumnarTable) throws {
        transformer.updates += 1
        transformer.preprocessorScale = input.column(annotationColumn)?.numeric?.first ?? nil
    }
}

func featuresOnly() -> ColumnarTable {
    var built = ColumnarTable()
    built.set(.doubles([1, 2, 3, 4, 5, 6, 7, 8].map { Optional($0) }), named: "x")
    return built
}

func table() -> ColumnarTable {
    var built = ColumnarTable()
    built.set(.doubles([10, 12, 14, 16, 18, 20, 22, 24].map { Optional($0) }), named: "y")
    built.set(.doubles([1, 2, 3, 4, 5, 6, 7, 8].map { Optional($0) }), named: "x")
    return built
}

do {
    let pipeline = PortCreateMLComponents.PreprocessingEstimator(PortCreateMLComponents.StandardScaler(),
                                                              MeanEstimator(annotationColumn: "y"))
    let fitted = try pipeline.fitted(on: table())
    check("an unsupervised pipeline's fit does NOT fit the preprocessor, as the host's does not",
          fitted.preprocessor.statistics.rows == 0,
          "the port answers \(fitted.preprocessor.statistics.rows) rows of statistics")
    check("and the estimator the fit produced", fitted.estimator.columns.contains("x"),
          "the port answers \(fitted.estimator.columns)")

    let unsupervisedPreprocessed = try pipeline.preprocessed(from: featuresOnly())
    let unsupervisedX = (unsupervisedPreprocessed.column("x")?.numeric ?? []).compactMap { $0 }
    check("an unsupervised pipeline's preprocessed values are the host's: the raw 1...8",
          unsupervisedX == [1, 2, 3, 4, 5, 6, 7, 8],
          "the port answers \(String(describing: unsupervisedX))")

    let spread = 6.0.squareRoot()
    let transformed = fitted.preprocessor.transformed(table())
    let x: [Double] = (transformed.column("x")?.numeric ?? []).compactMap { $0 }
    checkClose("a pipeline passes its preprocessor through, so the column is the host's raw 1...8",
               x.first ?? 0, 1, 1e-9)
    checkClose("and the last value too", x.last ?? .nan, 8, 1e-9)

    let intermediate = try pipeline.preprocessed(from: table())
    check("preprocessed(from:) transforms every column, the target included, for the *unsupervised* one",
          intermediate.columnNames == ["y", "x"],
          "the port answers \(intermediate.columnNames)")
    checkEqual("and its y column is raw as well, as the host's is",
           port: (intermediate.column("y")?.numeric ?? []).compactMap { $0 }.reduce(0, +), is: 136)

    let supervised = PortCreateMLComponents.PreprocessingSupervisedEstimator(
        PortCreateMLComponents.StandardScaler(), MeanEstimator(annotationColumn: "y"),
        annotationColumn: "y")
    let supervisedFitted = try supervised.fitted(on: table())
    check("a supervised pipeline's preprocessor saw the features only",
          supervisedFitted.preprocessor.statistics.rows == 1,
          "the port answers \(supervisedFitted.preprocessor.statistics.rows) rows of statistics")
    checkClose("and the mean the estimator fitted, in the target's own units",
               supervisedFitted.estimator.mean, 17, 1e-9)
    let supervisedX: [Double] = (supervisedFitted.preprocessor.transformed(featuresOnly()).column("x")?
        .numeric ?? []).compactMap { $0 }
    checkClose("a supervised pipeline standardises the feature with the feature's own statistics",
               supervisedX.first ?? .nan, (1 - 4.5) / spread, 1e-9)

    let updatable = PortCreateMLComponents.PreprocessingUpdatableEstimator(
        PortCreateMLComponents.StandardScaler(), CountingEstimator(annotationColumn: "x"))
    var transformer = updatable.makeTransformer()
    check("an updatable pipeline starts with no updates", transformer.estimator.updates == 0,
          "the port answers \(transformer.estimator.updates)")
    check("and with an unfitted preprocessor", transformer.preprocessor.statistics.rows == 0,
          "the port answers \(transformer.preprocessor.statistics.rows) rows of statistics")
    let fittedScaler = try updatable.preprocessor.fitted(on: table())
    transformer = PortCreateMLComponents.ComposedTransformer(fittedScaler, transformer.estimator)
    let before = transformer.preprocessor.statistics.values
    check("a fitted pipeline's preprocessor has statistics", before.count > 0,
          "the port answers \(before.count) values")
    try updatable.update(&transformer, with: table())
    check("an update moves the inner estimator", transformer.estimator.updates == 1,
          "the port answers \(transformer.estimator.updates)")
    check("and the update read the preprocessed column", transformer.estimator.preprocessorScale != nil,
          "the port answers \(String(describing: transformer.estimator.preprocessorScale))")
    checkEqual("and the preprocessor kept exactly the statistics the fit gave it",
               port: transformer.preprocessor.statistics.values, is: before)

    let supervisedUpdatable = PortCreateMLComponents.PreprocessingUpdatableSupervisedEstimator(
        PortCreateMLComponents.StandardScaler(), CountingEstimator(annotationColumn: "x"),
        annotationColumn: "y")
    var supervisedTransformer = supervisedUpdatable.makeTransformer()
    try supervisedUpdatable.update(&supervisedTransformer, with: table())
    check("a supervised updatable pipeline's update moves the inner estimator",
          supervisedTransformer.estimator.updates == 1,
          "the port answers \(supervisedTransformer.estimator.updates)")
    check("and keeps the preprocessor's fitted statistics",
          supervisedTransformer.preprocessor.statistics.rows == 0,
          "the port answers \(supervisedTransformer.preprocessor.statistics.rows) rows")
    let robustUpdatable = PortCreateMLComponents.PreprocessingUpdatableSupervisedEstimator(
        PortCreateMLComponents.RobustScaler(), CountingEstimator(annotationColumn: "x"),
        annotationColumn: "y")
    var robustTransformer = robustUpdatable.makeTransformer()
    try robustUpdatable.update(&robustTransformer, with: table())
    checkClose("a supervised updatable pipeline's estimator is fed the raw column, as the host feeds it",
               supervisedTransformer.estimator.preprocessorScale ?? .nan, 1.0, 1e-9)
} catch {
    print("FAIL the preprocessing comparison threw: \(error)")
    failures += 1
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
