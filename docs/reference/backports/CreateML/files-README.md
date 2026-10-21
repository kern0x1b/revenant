# CreateML and CreateMLComponents, for the port's armv7 releases

Three Swift modules, built for armv7 by `packages/c/createml/xmake.lua` against the
`revenant@swift-runtime` a port carries:

| Module | Holds |
| --- | --- |
| `TabularData` | the `DataFrame` and the column types the tabular API is written against |
| `CreateMLComponents` | the estimator, transformer and metric types, and the arithmetic under them |
| `CreateML` | `MLDataTable`, the high-level `MLLinearRegressor` family and the training session |

The arithmetic is the device's own. Every matrix kernel here is a call into the Accelerate of the
release the program runs on: the armv7 caches from 4.3 up export `cblas_dgemm`, `cblas_dsyrk`,
`cblas_dgemv`, `cblas_ddot`, `dgesv_` and `dpotrf_` (measured over the caches with
`coordination`'s own `~/.revenant/dyld/<release>/dyld_shared_cache_armv7`), and `import Accelerate` at
the port's deployment target declares all six as available from iOS 4.0. There is no matrix code in
this package, and none is wanted: a second implementation of GEMM on a device that already has one
would be a second copy of something that exists, and slower than the vector unit that ships it.

## The protobuf codec

`frameworks/Backports/src/CoreML/Codec.swift` reads and writes Apple's `.mlmodel`, which is a protobuf (proto2, little-endian
fixed fields). The schema is Apple's, under BSD-3-Clause, in `coremltools/mlmodel/format/*.proto`; this package vendors no copy of them.

The codec is not a generator and not a second declaration of the schema. It implements the wire format
only: varints, the fixed 32- and 64-bit values, and the length-delimited submessages, with a reader that
walks a message by field number and a writer that emits one. Every field name and number the model
messages use is read out of the vendored `.proto`, and the fields this package writes are the ones a
Core ML model of these estimators needs. There is no protobuf library in the store for this target, so a
hand-written codec is the native route, and a small one: six wire types, of which four are used.

It does not validate a schema, resolve a `oneof`, or handle extensions. A reader that meets an unknown
field skips it by its wire type, which is what a protobuf reader is required to do.
