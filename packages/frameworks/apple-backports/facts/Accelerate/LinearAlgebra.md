# The LinearAlgebra objects of vecLib, iOS 8.0

`vecLib/LinearAlgebra/*.h` is a second face on the BLAS and LAPACK the release already carries: an object is a matrix, a vector or a
splat, and every operation on one is a product, a norm or a solve. iOS 6.1.3 has none of the forty-two entry points
(`la_solve()` and the other forty-one all arrived in 8.0), and the release ships everything they are made of: measured from the
release's own armv7 caches, iOS 4.3, 5.1.1, 6.0, 6.1.3, 7.0, 7.1.2 and 8.0 all export `cblas_sgemm`, `cblas_dgemm`, `sgetrf_`,
`sgetrs_`, `dgetrf_` and `dgetrs_`, and 6.1.3's vecLib carries 148 `cblas_*` names and 290 trailing-underscore LAPACK ones beside
its 415 vDSP and 235 vImage. So no BLAS is built here: every product below is a call into `cblas_sgemm` / `cblas_dgemm` and every
solve into the release's `sgetrf_` / `sgetrs_` / `dgetrf_` / `dgetrs_`, in the objects' own scalar type, which is where the release's
own LinearAlgebra gets its arithmetic from too. That the two gates confirm at both ends of the ladder: the built library's four
LAPACK imports resolve against 6.1.3's 158 520 exports and against 4.3's 85 386, so the release has them on the oldest band this
port supports as well as on the newest. There is no `cblas_sgesv` to reach for instead: the release's CBLAS has 148 names and
none of them is a general solve (measured at 7.1.2 and 8.0), which is why the two LAPACK pairs are the way in.

Source: the host's own Accelerate, held against the port for every case below by `tests/backports/host/linearalgebra`, which runs
the port's `LinearAlgebra8.m` and the host's Accelerate over the same inputs and compares the statuses, the shapes and the elements;
the header of iOS 16.4 for the declarations and the spelling of the forty-two names.

## What the object is

One flat object, and it is the host's own shape: a splat and a vector both answer `OS_la_object` for `-class` (measured), so the
kind, the dimensions, the scalar type, the status, the attributes and either one value or one row-major block of `rows * cols`
elements are one structure rather than a class per kind. `rows` and `cols` are 0 for a splat, for an object that carries an error
and for a dimension that is zero.

The two shapes the release's own `vecLib/LinearAlgebra/object.h` gives `la_object_t`, both from the same source:

- at iOS 6.1.3 and above it is an Objective-C type (`OS_OBJECT_DECL(la_object)` needs only `__OBJC__` and a deployment target of
  6.0 or more), retained with `[object retain]`;
- below 6.0 - the 4.3 band - it is the incomplete `struct la_s *` that `la_retain()` and `la_release()` count.

The 6.1.3 band therefore counts through the runtime, which is the count `[object retain]` moves, and the 4.3 band through a field of
its own; both export `_la_retain` and `_la_release`, which iOS 8.0's own libLinearAlgebra does as well (measured: all forty-two
`la_*` names, `la_retain` and `la_release` among them, are in the 8.0 cache beside the twenty-six other names of the library).

## What was measured

Statuses: `LA_SUCCESS` is 0, `LA_WARNING_POORLY_CONDITIONED` 1000, `LA_INTERNAL_ERROR` -1000, `LA_INVALID_PARAMETER_ERROR` -1001,
`LA_DIMENSION_MISMATCH_ERROR` -1002, `LA_PRECISION_MISMATCH_ERROR` -1003, `LA_SINGULAR_ERROR` -1004, `LA_SLICE_OUT_OF_BOUNDS_ERROR`
-1005 (`vecLib/LinearAlgebra/base.h`).

The order two operands are refused in, which the measurements fix and which the code follows: a parent's own status travels on
first, then the two scalar types, then the shapes. A float and a double splat added together answer `LA_PRECISION_MISMATCH_ERROR`
where two splats of one type answer `LA_INVALID_PARAMETER_ERROR`, so the type is decided before the shape.

`la_status(NULL)` is `LA_INVALID_PARAMETER_ERROR`; `la_matrix_rows(NULL)`, `la_matrix_cols(NULL)` and `la_vector_length(NULL)` are 0.

Storage: `la_matrix_from_float_buffer(buffer, rows, cols, row_stride, hint, attributes)` reads row-major, element (i, j) at
`buffer[i * row_stride + j]`, and `la_matrix_to_float_buffer(buffer, row_stride, matrix)` writes it back the same way; a double object
in a float buffer and the other way round answer `LA_PRECISION_MISMATCH_ERROR` and write nothing.

What the four stores answer for the two kinds of object that are not a matrix at all is one order - the scalar type first, then the
shape - and it accounts for all sixteen measured answers, with the buffer left alone in every one of them (each case is asked by
`tests/backports/host/linearalgebra`, and the sixteen are also in the device run):

| object | `*_to_float_buffer` | `*_to_double_buffer` |
| --- | --- | --- |
| a float splat | `LA_INVALID_PARAMETER_ERROR` | `LA_PRECISION_MISMATCH_ERROR` |
| a double splat | `LA_PRECISION_MISMATCH_ERROR` | `LA_INVALID_PARAMETER_ERROR` |
| an object carrying an error, of either status | `LA_PRECISION_MISMATCH_ERROR` | `LA_PRECISION_MISMATCH_ERROR` |

A splat has a scalar type, so one of the buffer's own type gets as far as the shape and is refused for having no shape to store -
`LA_INVALID_PARAMETER_ERROR`, the answer the header gives for anything that is not a vector or a matrix - while a splat of the other
type never gets that far. An object that carries an error has no scalar type of its own to match, so the type is what answers, in all
four. (The host prints a line of its own for each refusal, "operator vector to float buffer does not support splat" and the like; that
is its diagnostics and not an answer a caller reads.)

The column-major recipe the header gives - pass the counts the other way round, then transpose - is what the host does, measured on
a 3x2 and a 2x3. `la_matrix_from_float_buffer_nocopy` and its double sibling take the block over and give it to the caller's
deallocator when the object goes; a `row_stride` wider than the row count means the block is padded and cannot be the object's
storage, so the object keeps its own copy and hands the block straight back.

`la_vector_length` is `cols` for a 1 x n vector and `rows` for everything else, a matrix with both dimensions above one included: a
2x3 answers 2, a 3x2 answers 3, a 4x4 answers 4, a splat and an error object answer 0. `la_vector_slice` and
`la_splat_from_vector_element` take that length, and both refuse a matrix with both dimensions above one with
`LA_INVALID_PARAMETER_ERROR` and a slice that reaches outside the object with `LA_SLICE_OUT_OF_BOUNDS_ERROR`.

The norms are over every element of the object, a matrix included, and are L1, L2 and L-infinity as the header names them: a
4x4 holding 0...15 answers 35.2136 for L2, and [-1, 2, -3] answers 6, 3.74166 and 3. `la_norm_as_float` of a double object answers
NaN and `la_norm_as_double` of a float object answers NaN, in both directions, and so does a splat, an error object and a norm the
library does not have. `la_normalized_vector` divides by the norm, so a zero vector comes back as it was with `LA_SUCCESS` and a norm
of 0, and a norm the library does not have answers `LA_INVALID_PARAMETER_ERROR`.

Products and sums, all measured: `la_sum`, `la_difference` and `la_elementwise_product` want the same shape, a splat stands for the
other operand's whole shape, two splats answer `LA_INVALID_PARAMETER_ERROR` and two different shapes `LA_DIMENSION_MISMATCH_ERROR`.
`la_inner_product` wants two vectors of one length, or one of them a splat, and answers a 1x1. `la_outer_product` wants two vectors
and refuses a splat with `LA_INVALID_PARAMETER_ERROR` and a matrix with both dimensions above one with
`LA_DIMENSION_MISMATCH_ERROR`; the answer is length(left) x length(right), row by row from the left. `la_matrix_product` answers
rows(left) x cols(right) and `LA_DIMENSION_MISMATCH_ERROR` when cols(left) is not rows(right). `la_transpose` answers cols x rows
and takes a vector, a 6x1 becoming a 1x6.

`la_solve` wants a square A and a right-hand side of n rows whose width is the number of solutions: a vector of length n and a matrix
of n x k both answer n x 1 and n x k, and anything else answers `LA_DIMENSION_MISMATCH_ERROR` (a 3x2 A with a 3x1 right-hand side
answers -1002, measured). It is `sgetrf_` and `sgetrs_` for a float object and `dgetrf_` and `dgetrs_` for a double one, on a
column-major copy of the system in the layout `clapack.h` declares - LAPACK is column-major and the objects are row-major, which is
the one transposition a C caller of it makes - and the answer is read back out of the right-hand side block, all n columns at once
so a matrix right-hand side is one `sgetrs_` and not k of them. A float object is answered in float, because the call is in float: the
port answers 0.09090909362 and 0.6363636255 for [[4,1],[1,3]] against [1,2] where the host's own `la_solve` answers 0.09090907872 and
0.636363685 - the same two numbers to the six significant digits the float type has, and the last place apart is the difference
between the release's LAPACK and the host's own solver.

What the release's LAPACK stores is the reference layout, and that is worth saying because it was in doubt: `sgetrf_` of [[4,1],[1,3]]
gives the block `4 0.25 1 2.75`, which is the reference column-major packed LU - L(2,1) = 0.25, then U(1,1) = 4, U(1,2) = 1, U(2,2)
= 2.75 - and `sgetrs_` of that with 'N' then answers 1/11 and 7/11 to eight places. `sgetrf_` is also what recognises the singular
case: it answers a positive info for a pivot of exactly zero (2, for [[1,1],[1,1]]), and `sgetrs_` of such a system is not a number
(-inf and inf for that one), which is why the solve is not run at all when the factorisation says the system is singular.

`la_identity_matrix` answers `LA_INVALID_PARAMETER_ERROR` for a scalar type that is neither `LA_SCALAR_TYPE_FLOAT` nor
`LA_SCALAR_TYPE_DOUBLE`, and a size of 0 answers a 0x0 object with `LA_SUCCESS`. `la_vector_from_matrix_row` and
`la_vector_from_matrix_col` answer `LA_INVALID_PARAMETER_ERROR` for a row or column the matrix does not have, and
`la_diagonal_matrix_from_vector` takes a vector only, making a matrix of `length + |diagonal|` with element i at (i + diagonal, i) -
a diagonal of 9 on a vector of 6 answers 15 x 15 with `LA_SUCCESS` rather than an error.

The attributes are carried and inherited: a result takes the inclusive-or of the attributes of what it was made from, which is what
`vecLib/LinearAlgebra/object.h` says. The one attribute the library has, `LA_ATTRIBUTE_ENABLE_LOGGING`, changes no answer and prints
nothing for any operation measured on the host, so it is stored and inherited and nothing more.

## Where the host answers differently from the header

Three places, all measured, all recorded here rather than papered over:

- `la_vector_length` of a matrix with both dimensions above one is the number of rows, where
  `vecLib/LinearAlgebra/vector.h` says zero. The port answers as the host does.
- A splat in a matrix product is 1 x cols on the left of the product and rows x 1 on the right, where the table in
  `vecLib/LinearAlgebra/splat.h` has the two the other way round: `la_matrix_product(splat(3), [[1,2],[3,4]])` answers 1x2
  [12 18] and `la_matrix_product([[1,2],[3,4]], splat(3))` answers 2x1 [9 21], measured. The port follows the measurement.
- `la_splat_from_vector_element` with an index below zero: the host answers `LA_SUCCESS` and a value read from before its own buffer,
  which is not an answer that can be reproduced without reading outside the object. The port answers
  `LA_DIMENSION_MISMATCH_ERROR`, the same as for an index one past the end.

Two more where the host answers something the header does not describe, reproduced because a caller sees it:
`la_solve` of a matrix with an exactly zero pivot comes back as zeros with `LA_SUCCESS`, where
`vecLib/LinearAlgebra/linear_systems.h` says `LA_SINGULAR_ERROR`; and a right-hand side of a shape `la_solve` does not take is
`LA_DIMENSION_MISMATCH_ERROR` where the header says a non-square matrix is answered with a least-squares solution - measured on a
3x2 and a 2x3 A, both -1002.

## The one tolerance in the differential, and what it is

`tests/backports/host/linearalgebra` compares a status, a shape and every element exactly, with one
exception: a product and a solve are compared to 1e-5 of the value, relative. That is not a widened
expectation - it is the precision of the type. The two sides sum the same terms in a different order
and factorise with a different solver, and their answers for the systems the cases use differ in the
last place a float has: for [[4,1],[1,3]] against [1,2] the port answers 0.09090909362 and 0.6363636255
where the host's own `la_solve` answers 0.09090907872 and 0.636363685 (both measured, both roundings of
1/11 and 7/11), and for a 3x3 the port answers -0.05882352591 where the host says -0.05882355571. In
double the two agree exactly, which is the same statement one precision up. A tolerance of zero would be
asserting that two independent summations of the same terms produce the same bits, which is not true of
any BLAS on any processor and is not what this port is claiming. Everything else - every status, every
shape, every element of a sum, a difference, a slice, a transpose and a norm - is compared with no
tolerance at all, and the sixteen refusals of the table above are compared as a status and as a buffer.

## What has not been run

`tests/backports/device/linearalgebra.m` calls all 44 entry points on the device against the answers
recorded above, and the two constructors that take a buffer over are called only there: a block a
`la_matrix_from_*_buffer_nocopy` takes over is a block the host differential cannot hand away twice, so
the ownership path - the object reading the elements out, keeping the block, and giving it to the
deallocator once when it goes - is covered by the device run and not by the host one. The run has not
happened yet: the device test is written and compiles for `armv7-apple-ios6.1.3` and
`armv7-apple-ios4.3` against the SDK this port builds with, and until it is run on an emulated 6.1.3 or
on an iPad 2 every answer on this page is a host measurement and a device-unverified one, which is the
floor the port's own contract asks for and not the bar.

## What is reasoned rather than measured

`la_normalized_vector` is asked of both scalar types and both answer: a float object of [3,4] normalises to 3/7 and 4/7 and a double
object of the same two numbers to the same, with `LA_SUCCESS` in every case and for each of the three norms (measured). The one case
this page does not carry is the one the norm functions cannot be asked for at all - they take no scalar type of their own, so there is
no way to pose a mismatch through them - and the port answers it by using the object's own scalar type, which is what those
measurements show the host doing.

Everything else on this page is a measurement, including the sixteen store refusals above, which an earlier version of this file
carried as reasoning instead.
