# CreateML and CreateMLComponents, for the port's armv7 releases

Three Swift modules, built for armv7 by `packages/c/createml/xmake.lua` against the
`charon@swift-runtime` a port carries:

| Module | Holds |
| --- | --- |
| `TabularData` | the `DataFrame` and the column types the tabular API is written against |
| `CreateMLComponents` | the estimator, transformer and metric types, and the arithmetic under them |
| `CreateML` | `MLDataTable`, the high-level `MLLinearRegressor` family and the training session |

The arithmetic is the device's own. Every matrix kernel here is a call into the Accelerate of the
release the program runs on: the armv7 caches from 4.3 up export `cblas_dgemm`, `cblas_dsyrk`,
`cblas_dgemv`, `cblas_ddot`, `dgesv_` and `dpotrf_` (measured over the caches with
`coordination`'s own `~/.charon/dyld/<release>/dyld_shared_cache_armv7`), and `import Accelerate` at
the port's deployment target declares all six as available from iOS 4.0. There is no matrix code in
this package, and none is wanted: a second implementation of GEMM on a device that already has one
would be a second copy of something that exists, and slower than the vector unit that ships it.
