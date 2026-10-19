// preprocessing.swift — the pipeline wrappers, against the arithmetic they are made of.
//
// A pipeline adds no arithmetic, so the checks are about the two things it does change: the
// preprocessor's statistics travel with the model, and an update touches the inner estimator and not
// the preprocessor. Both are checked against the port's own scalers, whose arithmetic the
// transformers suite already holds to the closed form.
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

/// `port:` and `is:` because both arguments here are the port's - the first is what it produced and
/// the second is what it should be, and neither is a host. The differential's own calls in
/// `tabularframe.swift` name their sides `host:` and `port:`, which is why this helper's names differ:
/// a file that compares against Apple's uses the other pair, and a message that said "the port answers"
/// for *both* sides is how four turns of reports went wrong in the other suite.
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

/// An estimator over a table, so the pipeline has something real to fit. The "model" is the mean of
/// the target column, which is one number and is enough to tell a fitted estimator from an unfitted one.
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

    /// The supervised half: the pipeline's own fit, which for this estimator is the unfitted
    /// transformer with nothing counted yet.
    func fitted(on input: ColumnarTable) throws -> Fitted {
        _ = input
        return Fitted(updates: 0, preprocessorScale: nil)
    }

    func update(_ transformer: inout Fitted, with input: ColumnarTable) throws {
        transformer.updates += 1
        // An update reads the *preprocessed* column, which is how a caller can see the pipeline fed
        // it: the scale is what the fitted scaler produced and the raw column does not have it.
        transformer.preprocessorScale = input.column(annotationColumn)?.numeric?.first ?? nil
    }
}

/// The same table without its target, which is what a supervised wrapper hands the preprocessor.
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
    // The unsupervised pipeline: a scaler in front of an estimator, fitted once.
    let pipeline = PortCreateMLComponents.PreprocessingEstimator(PortCreateMLComponents.StandardScaler(),
                                                              MeanEstimator(annotationColumn: "y"))
    let fitted = try pipeline.fitted(on: table())
    // **The host does not fit a pipeline's preprocessor**, measured with the host's own
    // `LinearTransformer` as the instrument (a fitted one has non-identity `scale` and `offset`):
    //
    //     after fitted(to:): preprocessor scale=1.0 offset=0.0
    //     after preprocessed(from:): the values are [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    //
    // `probe/preprocessing-estimator-host.swift` and its `.txt`. A pipeline holds a `Transformer`,
    // and `Transformer` has no `fitted(to:)` of its own, so the preprocessor it was handed is the one it
    // transforms through; fitting it is the caller's separate step.
    check("an unsupervised pipeline's fit does NOT fit the preprocessor, as the host's does not",
          fitted.preprocessor.statistics.rows == 0,
          "the port answers \(fitted.preprocessor.statistics.rows) rows of statistics")
    check("and the estimator the fit produced", fitted.estimator.columns.contains("x"),
          "the port answers \(fitted.estimator.columns)")

    // The host's recorded value for the preprocessed column, from the same probe: the raw `1...8`,
    // because the identity preprocessor was used. A port that fitted answers standardised values here.
    let unsupervisedPreprocessed = try pipeline.preprocessed(from: featuresOnly())
    let unsupervisedX = (unsupervisedPreprocessed.column("x")?.numeric ?? []).compactMap { $0 }
    check("an unsupervised pipeline's preprocessed values are the host's: the raw 1...8",
          unsupervisedX == [1, 2, 3, 4, 5, 6, 7, 8],
          "the port answers \(String(describing: unsupervisedX))")

    // The preprocessor's own arithmetic, unchanged by being in a pipeline: a standard scaler over
    // `1...8` has mean 4.5 and the unbiased deviation sqrt(6), so the first value is
    // (1 - 4.5) / sqrt(6).
    // `1...8`: mean 4.5, sum of squared deviations 42, unbiased variance 42/7 = 6.
    let spread = 6.0.squareRoot()
    let transformed = fitted.preprocessor.transformed(table())
    let x: [Double] = (transformed.column("x")?.numeric ?? []).compactMap { $0 }
    // These two used to expect the *standardised* values, which is what the port produced by fitting
    // the preprocessor inside the pipeline. The host does not fit it, so it passes the caller's
    // transformer through: over `1...8` with the identity preprocessor the values are the raw ones, and
    // that is the host's recorded answer (probe/preprocessing-estimator-host.txt).
    checkClose("a pipeline passes its preprocessor through, so the column is the host's raw 1...8",
               x.first ?? 0, 1, 1e-9)
    checkClose("and the last value too", x.last ?? .nan, 8, 1e-9)

    // The two halves separately, because a caller who wants to look at the intermediate calls them.
    let intermediate = try pipeline.preprocessed(from: table())
    check("preprocessed(from:) transforms every column, the target included, for the *unsupervised* one",
          intermediate.columnNames == ["y", "x"],
          "the port answers \(intermediate.columnNames)")
    // The y column is the target and this pipeline is unsupervised, so there is nothing to hold it out -
    // and the preprocessor is not fitted, so the column is raw too: 10...24 sums to 136.
    checkEqual("and its y column is raw as well, as the host's is",
           port: (intermediate.column("y")?.numeric ?? []).compactMap { $0 }.reduce(0, +), is: 136)

    // A supervised pipeline, which keeps its target column out of the scaler: scaling a target is a
    // different model, and the wrapper is not that.
    let supervised = PortCreateMLComponents.PreprocessingSupervisedEstimator(
        PortCreateMLComponents.StandardScaler(), MeanEstimator(annotationColumn: "y"),
        annotationColumn: "y")
    let supervisedFitted = try supervised.fitted(on: table())
    // ONE row of statistics, not two: the supervised wrapper fits the preprocessor over the features
    // alone, with the target column taken out first.
    check("a supervised pipeline's preprocessor saw the features only",
          supervisedFitted.preprocessor.statistics.rows == 1,
          "the port answers \(supervisedFitted.preprocessor.statistics.rows) rows of statistics")
    checkClose("and the mean the estimator fitted, in the target's own units",
               supervisedFitted.estimator.mean, 17, 1e-9)
    let supervisedX: [Double] = (supervisedFitted.preprocessor.transformed(featuresOnly()).column("x")?
        .numeric ?? []).compactMap { $0 }
    checkClose("a supervised pipeline standardises the feature with the feature's own statistics",
               supervisedX.first ?? .nan, (1 - 4.5) / spread, 1e-9)

    // An updatable pipeline: the transformer starts unfitted, and an update moves the inner estimator
    // and not the preprocessor. The preprocessor's statistics after an update are the ones the *fit*
    // left, which is the whole semantic and the thing a refitting pipeline would get wrong.
    let updatable = PortCreateMLComponents.PreprocessingUpdatableEstimator(
        PortCreateMLComponents.StandardScaler(), CountingEstimator(annotationColumn: "x"))
    // `makeTransformer()` is the **unfitted** pipeline, so its preprocessor has no statistics yet -
    // which is itself a claim worth pinning, because a wrapper that fitted the preprocessor here
    // would be a pipeline whose features move under an update.
    var transformer = updatable.makeTransformer()
    check("an updatable pipeline starts with no updates", transformer.estimator.updates == 0,
          "the port answers \(transformer.estimator.updates)")
    check("and with an unfitted preprocessor", transformer.preprocessor.statistics.rows == 0,
          "the port answers \(transformer.preprocessor.statistics.rows) rows of statistics")
    // A fit, so the preprocessor *has* statistics, and then the update: they must be the same
    // afterwards. That is the semantic the `Updatable` name changes and the only thing it changes.
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

    // The supervised updatable one, same semantic.
    let supervisedUpdatable = PortCreateMLComponents.PreprocessingUpdatableSupervisedEstimator(
        PortCreateMLComponents.StandardScaler(), CountingEstimator(annotationColumn: "x"),
        annotationColumn: "y")
    var supervisedTransformer = supervisedUpdatable.makeTransformer()
    try supervisedUpdatable.update(&supervisedTransformer, with: table())
    // Its preprocessor is unfitted too, so `update` transforms with an empty one; what is checked is
    // that the update reached the inner estimator and did not throw on the way.
    check("a supervised updatable pipeline's update moves the inner estimator",
          supervisedTransformer.estimator.updates == 1,
          "the port answers \(supervisedTransformer.estimator.updates)")
    check("and keeps the preprocessor's fitted statistics",
          supervisedTransformer.preprocessor.statistics.rows == 0,
          "the port answers \(supervisedTransformer.preprocessor.statistics.rows) rows")
    // ... and the *value* the inner estimator is fed, which is the question the case above does not
    // ask. `update` transforms through `transformer.preprocessor`, and `makeTransformer()` hands over
    // the preprocessor as it stands - unfitted, because `ComposedTransformer.init`
    // (Preprocessing.swift:33) stores it as given. A preprocessor whose answer depends on its fit
    // therefore transforms with nothing, and the estimator is fed something that is not the
    // preprocessed feature at all. The case above only counted that the update arrived.
    // Asserting the *number*, not that there is one: with a preprocessor whose answer depends on its
    // fit, an unfitted one hands the estimator the raw column and a fitted one hands it the preprocessed
    // column, and the two differ by the centre and the scale. A `RobustScaler` is the case to use - its
    // answer is median-dependent, so an unfitted fit is visibly wrong rather than accidentally equal.
    let robustUpdatable = PortCreateMLComponents.PreprocessingUpdatableSupervisedEstimator(
        PortCreateMLComponents.RobustScaler(), CountingEstimator(annotationColumn: "x"),
        annotationColumn: "y")
    var robustTransformer = robustUpdatable.makeTransformer()
    try robustUpdatable.update(&robustTransformer, with: table())
    // The *value* the inner estimator is fed, and the host's answer is **the raw column**.
    //
    // `makeTransformer()` (Preprocessing.swift:168) hands the preprocessor to `ComposedTransformer.init`
    // (line 33), which stores it as given, and `update(_:with:)` (line 174) transforms through it. So a
    // supervised-updatable pipeline's preprocessor is **the caller's to fit**, and the pipeline itself
    // never fits it - which is what the host does, measured twice with the host's own
    // `LinearTransformer` as the instrument, since a fitted one has non-identity `scale` and `offset`:
    //
    //     after makeTransformer(): preprocessor scale=1.0 offset=0.0
    //     after the first  update(): the estimator saw Optional(1.0), scale=1.0 offset=0.0
    //     after the second update(): the estimator saw Optional(1.0), scale=1.0 offset=0.0
    //
    // The probe and its run are `probe/preprocessing-updatable-host.swift` and its `.txt`. The case
    // that used to expect a preprocessed -7 here was **wrong**: it took the *unsupervised* sibling's
    // behaviour (Preprocessing.swift:137 does fit) as the specification for the supervised one, and
    // turned the suite red to prove a defect that was not there.
    checkClose("a supervised updatable pipeline's estimator is fed the raw column, as the host feeds it",
               supervisedTransformer.estimator.preprocessorScale ?? .nan, 1.0, 1e-9)
} catch {
    print("FAIL the preprocessing comparison threw: \(error)")
    failures += 1
}

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
