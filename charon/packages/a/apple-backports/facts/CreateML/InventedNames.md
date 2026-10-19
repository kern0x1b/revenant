# Public types the SDK does not declare, at any nesting - an OPEN decision, not a proposal to remove

**The count is 53, and it is derived, not typed:**

    $ python3 tests/backports/host/createml/invented-names.py

which walks `packages/c/createml/files/**/*.swift` for a public declaration **at any indentation**, and
collects the SDK's names from **every `*.swiftinterface`, every `*.h` and every `module.modulemap`**
under `TabularData`, `CreateMLComponents`, `CreateML` and `CoreML` - 89 files, 568 names. Then it
reports the difference:

    port public types (any nesting): 122   SDK names (headers + interfaces + modulemaps): 568
    public types the SDK does not declare, at any nesting: 53

**Two earlier counts were wrong, for two different reasons, and both are recorded because the
difference is what the owner is being asked to look at.**

*53 from an unindented walk.* The earlier pattern was `^public (struct|final class|class|enum|protocol)`,
so it saw 108 top-level public types and missed `ParsingOptions` in
`packages/c/createml/files/CreateML/MLDataTable+CSV.swift:143` - an **indented** `public typealias`,
and one the SDK does not declare either. The current walk includes it, and
`grep ParsingOptions` on the tool's own output confirms it is there.

*54, claimed by the review, from not scanning the whole SDK.* `JoinType` and `PackType` are declared by
Apple - `public enum JoinType : Swift::Sendable` and `public enum PackType : Swift::Sendable` in
`CreateML.swiftinterface`, **nested in `MLDataTable`**, which is why an unindented walk missed them on
the SDK side as well as the port's. Scanning the SDK at any nesting, with the headers and modulemaps as
well as the interfaces, excludes both: `grep -E 'JoinType|PackType'` on the tool's output returns
nothing.

So **53** is the number the tool derives, and the table below is that tool's output.


| type | kind | declared in | an Apple counterpart? | why it is public (mechanical) |
| --- | --- | --- | --- | --- |
| `BoostedTreeFitter` | enum | `BoostedTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `BoostedTreeModel` | struct | `BoostedTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `BoostedTreeParameters` | struct | `BoostedTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a value type describing a fit or a result, where Apple carries the same values as parameters on its own types |
| `BoostingLoss` | enum | `BoostedTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a value type describing a fit or a result, where Apple carries the same values as parameters on its own types |
| `ColumnarTable` | struct | `ColumnarTable.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the port's own name for a shape Apple calls something else |
| `ColumnarTransformer` | protocol | `Transformers.swift` | the SDK has this as `ColumnSelectorTransformer` (CreateMLComponents) | a protocol the port's generics are written against |
| `DecisionTreeFitter` | enum | `DecisionTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `DecisionTreeModel` | struct | `DecisionTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `ForestFeatures` | enum | `Ensembles.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `FrameError` | enum | `DataFrame.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `Impurity` | enum | `DecisionTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `LinearModelError` | enum | `LinearModels.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `LinearRegressorConfiguration` | struct | `LinearModels.swift` | the SDK has this as `MultivariateLinearRegressorConfiguration` (CreateMLComponents) | a value type describing a fit or a result, where Apple carries the same values as parameters on its own types |
| `LinearScalar` | protocol | `LinearModels.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a protocol the port's generics are written against |
| `LogisticRegressionClassifierConfiguration` | struct | `LinearModels.swift` | the SDK has this as `LogisticRegressionClassifier` (CreateMLComponents) | a value type describing a fit or a result, where Apple carries the same values as parameters on its own types |
| `MLBoostedTreeClassifierModel` | struct | `TabularEstimators.swift` | the SDK has this as `MLBoostedTreeClassifier` (CreateML) | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `MLBoostedTreeModel` | struct | `TabularEstimators.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `MLClassifierMetricsError` | enum | `TabularEstimators.swift` | the SDK has this as `MLClassifierMetrics` (CreateML) | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `MLColumnError` | enum | `MLUntypedColumn.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `MLCreateErrorCode` | enum | `TabularEstimators.swift` | the SDK has this as `MLCreateError` (CreateML) | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `MLDataColumnSlice` | struct | `MLUntypedColumn.swift` | the SDK has this as `MLDataColumn` (CreateML) | a type the port needs and the SDK does not declare |
| `MLDataTableAggregator` | struct | `MLDataTable.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the port's own name for a shape Apple calls something else |
| `MLDataTableAggregatorOperations` | enum | `MLDataTable.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the port's own name for a shape Apple calls something else |
| `MLDataTableError` | enum | `MLDataTable.swift` | the SDK has this as `MLDataTable` (CreateML) | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `MLDataTableParsingOptions` | struct | `MLDataTable+CSV.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a value type describing a fit or a result, where Apple carries the same values as parameters on its own types |
| `MLDecisionTreeClassifierModel` | struct | `TabularEstimators.swift` | the SDK has this as `MLDecisionTreeClassifier` (CreateML) | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `MLDecisionTreeModel` | struct | `TabularEstimators.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `MLRandomForestClassifierModel` | struct | `TabularEstimators.swift` | the SDK has this as `MLRandomForestClassifier` (CreateML) | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `MLRandomForestModel` | struct | `TabularEstimators.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `MLRegressorMetricsError` | enum | `TabularEstimators.swift` | the SDK has this as `MLRegressorMetrics` (CreateML) | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `MLTrainingDataSplit` | struct | `TabularEstimators.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `MLTrainingDataValidation` | struct | `TabularEstimators.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `MLTrainingDataValidationData` | struct | `TabularEstimators.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `ModelWriter` | enum | `ModelWriter.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `ProtoError` | enum | `Codec.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `ProtoField` | enum | `Codec.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `ProtoReader` | struct | `Codec.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `ProtoWriter` | struct | `Codec.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `ProximalSolver` | enum | `Proximal.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `RandomForestFitter` | enum | `Ensembles.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `RandomForestModel` | struct | `Ensembles.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the fitted result of a fit, which Apple returns as an opaque `Transformer` |
| `RandomForestParameters` | struct | `Ensembles.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a value type describing a fit or a result, where Apple carries the same values as parameters on its own types |
| `RegressionMetrics` | enum | `Metrics.swift` | the SDK has this as `MLRegressorMetrics` (CreateML) | a type the port needs and the SDK does not declare |
| `RowMatrix` | struct | `LinearAlgebra.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | the port's own name for a shape Apple calls something else |
| `SeededGenerator` | struct | `Random.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `SplitSearch` | enum | `DecisionTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `SplitSide` | struct | `DecisionTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `TabularEstimatorCore` | enum | `TabularEstimators.swift` | the SDK has this as `TabularEstimator` (CreateMLComponents) | a type the port needs and the SDK does not declare |
| `TabularFitting` | enum | `ColumnarTable.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `TabularFittingError` | enum | `ColumnarTable.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a name Apple puts in `NSError`'s domain rather than in a Swift type |
| `TabularTrainingSet` | struct | `ColumnarTable.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `TrainingColumn` | enum | `ColumnarTable.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a type the port needs and the SDK does not declare |
| `TreeParameters` | struct | `DecisionTrees.swift` | **no counterpart** in TabularData, CreateMLComponents, CreateML or CoreML | a value type describing a fit or a result, where Apple carries the same values as parameters on its own types |

**How to use it.** Rows with a counterpart are a *naming* question: the port's name and Apple's
differ and one of them could go. Rows marked **no counterpart** are a *scope* question: either the port
carries something the SDK does not, or it carries a helper the SDK keeps internal. They are different
decisions and should not be taken together.

**What is not here.** Nothing in this table is a crutch, and nothing in it is a defect. A public type
the SDK does not declare is a divergence in *surface*: a record to be made and an owner to decide on, not
something this band may resolve by deleting a name a caller might already use.

**The "why" column is mechanical** - derived from the type's name, its kind and its file - so it is a
starting point for a reader and not a verdict, and the rows that matter are the ones where it is plainly
wrong.
## Why F4 finds 53 and not 54
The owner's count and this tool's count differed because each was derived from a different scan, and
both scans were wrong in opposite directions:

* the earlier walk matched `^public`, so it **missed `ParsingOptions`** - an indented
  `public typealias` in `MLDataTable+CSV.swift`, which the SDK does not declare, and which therefore
  belongs in the table;
* the earlier SDK side read the four `.swiftinterface` files only, and at top level, so it **counted
  `JoinType` and `PackType` as invented** when Apple declares both, nested in `MLDataTable`.

53 unindented, minus the two the SDK does declare, plus the one an anchored pattern missed, is 53 again -
but the two walks are not the same walk, and the current one scans the SDK's headers and modulemaps as
well as its interfaces so that a C or Objective-C declaration counts against the port's names too.
