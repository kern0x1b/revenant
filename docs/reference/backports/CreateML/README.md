# CreateML and CreateMLComponents, for the port's armv7 releases

Four Swift modules and the CoreML overlay they need, built for armv7 by `packages/c/createml/xmake.lua` against the
`revenant@swift-runtime` a port carries. What follows was checked against the sources in `frameworks/Backports/src/`.

| Module | Holds |
| --- | --- |
| `TabularData` | `DataFrame`, `ColumnID`, `Column`, `ColumnSlice`, `DiscontiguousColumnSlice`, `AnyColumn`; the CSV reader with `CSVType`, `CSVReadingOptions` and `CSVReadingError` ([reading](TabularData/CSVReading.md)); its date readings and the `ParseStrategy` a caller adds ([dates](TabularData/DateParsing.md)); the CSV writer with `CSVWritingOptions` and `CSVWritingError` ([writing](TabularData/CSVWriting.md)) |
| `CoreML` | the shaped-array overlay: `MLShapedArray`, `MLShapedArraySlice`, `MLShapedArrayScalar`; the protobuf wire codec (`Codec.swift`), the model messages (`ModelWriter.swift`), and the Core ML schema they use, vendored in `frameworks/Backports/src/CoreML/proto/` |
| `CreateMLComponents` | the estimators and their models: linear and logistic regression (`LinearRegressor`, `LogisticRegressionClassifier`, over `Float` and `Double`), decision trees, ensembles and boosted trees; the transformers `StandardScaler`, `MinMaxScaler`, `MaxAbsScaler`, `RobustScaler`, `OneHotEncoder`, `OrdinalEncoder`, `NumericImputer` and `LinearTransformer`; the preprocessing wrappers around an estimator; the metrics; and the arithmetic under them |
| `CreateML` | `MLDataTable` (with its CSV and JSON text), `MLDataColumn`, `MLLinearRegressor`, and the six tabular estimators: decision trees, random forests and boosted trees, each as a regressor and a classifier, with their models, metrics and the training data split and validation types |

**A note on `TabularData`:** its columns carry the collection's members as *members* and do not
conform to a collection — a user-defined collection conformance does not compile with the port's
Swift 6.4 at all, measured on both compilers.

**What is not here yet**, and is absent rather than stubbed: the `DataFrame` JSON writers and readers (`MLDataTable`
has its own JSON text, above), the `ColumnID` variants of the CSV readers, the summaries and groupings, the column
selector, and the `.mlmodel` export. `write(to:)` and `write(toFile:)` are declared on the estimators and **throw**
`MLCreateErrorCode.cannotWriteModel`, so nothing in the tree writes a `.mlmodel` file. `ModelWriter` builds the messages
of one model shape, a neural-network regressor, as protobuf values in memory, and nothing turns them into a file. A
file needs the whole specification written and checked: a table that wrote a file with the right extension and bytes no
Core ML can read would be worse than one that says it cannot.

## The protobuf codec

`CoreML/Codec.swift` implements the protobuf wire format and nothing else: varints, fixed 32- and 64-bit values, and
length-delimited submessages, with a reader that walks a message by field number and a writer that emits one. It does
not validate a schema, resolve a `oneof`, or handle extensions, and a reader skips an unknown field by its wire type,
as a protobuf reader must. `CoreML/ModelWriter.swift` builds its messages with the field numbers that the vendored
schema names. The schema is Apple's, from the `coremltools` repository, pinned at a commit in
`frameworks/Backports/src/CoreML/proto/README.md`, with Apple's licence (`LICENSE.txt`) beside it.

## The arithmetic

The arithmetic is the device's own. Every matrix kernel here is a call into the Accelerate of the release the program
runs on: the armv7 caches from 4.3 up export `cblas_dgemm`, `cblas_dsyrk`, `cblas_dgemv`, `cblas_ddot`, `dgesv_` and
`dpotrf_` (measured over the caches in `~/.revenant/dyld/<release>/dyld_shared_cache_armv7`), and `import Accelerate` at
the port's deployment target declares all six as available from iOS 4.0. There is no matrix code in this package, and
none is wanted: a second implementation of GEMM on a device that already has one would be a second copy of something
that exists, and slower than the vector unit that ships it.
