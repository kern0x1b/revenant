# CreateML and CreateMLComponents, for the port's armv7 releases

Three Swift modules, built for armv7 by `packages/frameworks/createml/xmake.lua` against the
`revenant@swift-runtime` a port carries:

| Module | Holds |
| --- | --- |
| `TabularData` | `DataFrame`, `ColumnID`, `Column`, `ColumnSlice`, `DiscontiguousColumnSlice`, `AnyColumn`, the CSV reader with `CSVType`, `CSVReadingOptions` and `CSVReadingError` (`facts/TabularData/CSVReading.md`), its date readings and the `ParseStrategy` a caller adds (`facts/TabularData/DateParsing.md`), and the CSV writer with `CSVWritingOptions` and `CSVWritingError` (`facts/TabularData/CSVWriting.md`) |
| `CoreML` | the shaped-array overlay: `MLShapedArray`, `MLShapedArraySlice`, `MLShapedArrayScalar` |
| `CreateMLComponents` | the estimator types, the kernel layer, and the arithmetic under them |
| `CreateML` | `MLDataTable`, `MLDataColumn`, and the six tabular estimators |

**A note on `TabularData`:** its columns carry the collection's members as *members* and do not
conform to a collection — a user-defined collection conformance does not compile with the port's
Swift 6.4 at all, measured on both compilers. `facts/TabularData/Columns.md` has the witness and
`registry/TabularData/createml-tabular.json` records the divergence per member.

**What is not here yet**, and is absent rather than stubbed: the `DataFrame` JSON writers, the
JSON readers, the `ColumnID` variants of the readers, the summaries
and groupings, the linear and logistic
models that are constrained to `MLShapedArrayScalar` (the overlay they need is here; the models are
not), the tabular transformers (the scalers, the encoders, the imputers, the column selector, the
preprocessing wrappers), and the `.mlmodel` export. `write(to:)` is declared on all six estimators and
**throws** `MLCreateErrorCode.cannotWriteModel`: the specification writer belongs to the CoreML
package, and a table that wrote a file with the right extension and bytes no Core ML can read would be
worse than one that says it cannot.

The arithmetic is the device's own. Every matrix kernel here is a call into the Accelerate of the
release the program runs on: the armv7 caches from 4.3 up export `cblas_dgemm`, `cblas_dsyrk`,
`cblas_dgemv`, `cblas_ddot`, `dgesv_` and `dpotrf_` (measured over the caches with
`coordination`'s own `~/.revenant/dyld/<release>/dyld_shared_cache_armv7`), and `import Accelerate` at
the port's deployment target declares all six as available from iOS 4.0. There is no matrix code in
this package, and none is wanted: a second implementation of GEMM on a device that already has one
would be a second copy of something that exists, and slower than the vector unit that ships it.
