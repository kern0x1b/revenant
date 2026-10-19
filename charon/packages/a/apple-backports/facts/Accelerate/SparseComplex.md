# The complex sparse BLAS of vecLib/Sparse/BLAS.h (iOS 18.5)

The fifty-eight entry points `Accelerate/SparseComplex18.m` defines, in the float complex and the double
complex of each: the whole complex half of `Sparse/BLAS.h`. Behaviour here is the host's own, measured
case by case by `tests/backports/host/sparseblas/differential-complex.m`, which runs that file and the
host's own Accelerate over the same inputs and compares a status, a count and every element. **170
checks, 0 failures** (`sh tests/backports/host/sparseblas/run.sh`).

Read with `facts/Accelerate/SparseBLAS.md`, which is the real family's file: the storage is the same
(CharonSparseBLAS.h), the refusals are the same, and where this file says "as the real family does" that
is the reference. What follows is only what the complex half does differently, and the five places
where the host cannot be the oracle.

## The release, and why one object file

No release this port supports exports any of the fifty-eight. Measured over the fifty-one rungs of the
ladder this port holds (1.1.4 through 18.0, read through `tools/cache-index/first-rung.lua`), the first
held rung carrying any of them is `NONE`, and the 26.2 header that declares them puts every one of them
at 18.5. They are one object file because they are one release. The iPhoneOS 16.4 SDK this package
compiles against declares none of them, so they are transcribed into
`packages/a/apple-backports/Accelerate/CharonSparseComplex26.h`.

The imports the object does carry are the release's own and resolve on every band: `cblas_ccopy`,
`cblas_zcopy`, `cheev_` and `zheev_` are all first exported by 3.2, and the oldest band this port
supports is 4.0 (the same measurement SparseBLAS.md makes for the real family's `cblas_saxpy`).

## No `_Complex` operator is ever applied to two complex values

A complex product and a complex quotient are the only two operations where the C99 operators need a
helper the compiler calls out to. Measured by compiling a translation unit that multiplies and divides
`float _Complex` and `double _Complex` for `armv7-apple-ios6.0`: the only names left undefined are
`__mulsc3`, `__muldc3`, `__divsc3` and `__divdc3`. Addition, subtraction and a real scaling need none of
them (the same object leaves them all defined), so they are written with the operators in
`CharonSparseComplex.h`, and the two that would need a helper are spelled out there - the product as
`(ar br - ai bi) + (ar bi + ai br)i`, and the quotient by Smith's algorithm, which divides by a real
number once. A complex value is a pair of doubles throughout, and a value is rounded to the width its row
stores when it is written, which is the rule the real family follows when it stores a float through a
double.

A zero divisor is not a special case and needs none: `1/0` is an infinity, an infinity times zero is a
NaN, and the arithmetic carries it into a NaN in both parts. That is what the host's own zero pivot
answers (measured: the lower triangular `[[0,0],[0,1]]` against `(1,1)` gives a NaN in both parts of both
elements).

## The release's complex BLAS, measured

The multiply-add and the gather are the release's own `cblas_caxpy` / `cblas_zaxpy` and `cblas_ccopy` /
`cblas_zcopy`, the same choice the real family makes with `cblas_saxpy` / `cblas_daxpy`. Measured on the
host, a complex alpha is done properly by all four:

| call | alpha | x | host | the product |
| --- | --- | --- | --- | --- |
| `cblas_caxpy(1, &alpha, x, 1, y, 1)` | `2+i` | `3+4i` | `2+11i` | `2+11i` |
| `cblas_caxpy` | `0+i` | `3+4i` | `-4+3i` | `-4+3i` |
| `cblas_caxpy` | `2+i` | `3+0i` | `6+3i` | `6+3i` |
| `cblas_caxpy` | `-1+0.5i` | `2-1i` | `-1.5+2i` | `-1.5+2i` |
| `cblas_zaxpy` | `2+i` | `3+4i` | `2+11i` | `2+11i` |
| `cblas_zaxpy` | `0+i` | `3+4i` | `-4+3i` | `-4+3i` |
| `cblas_ccopy(2, src, 1, dst, 1)` | - | - | `1+1i 2+2i` | the first two |
| `cblas_ccopy(2, src, 2, dst, 1)` | - | - | `1+1i 3+3i` | the first and the third |

**A correction, because it was measured wrong the first time and the wrong answer nearly landed.** An
earlier version of this file reported that `cblas_caxpy` reads the real part of `alpha` and drops the
imaginary one, on the strength of a probe that declared

```c
float _Complex a[2]; a[0] = 2.0f; a[1] = 1.0fi;
```

which is an array of two `float _Complex`, not one value: `a[0] = 2+0i` and `a[1] = 1+0i`, so the alpha
that reached the call was `2+0i`, and `2 * (2+i) = 4+2i` is exactly the answer that probe recorded. The
hand-written "expected" in that probe was wrong as well - `(2+i)(2+i)` is `3+6i`, not the `3+5i` it said.
Both mistakes pointed the same way, at a defect in the host that is not there. The coordinator checked it
and was right; the table above is the re-measurement, and the multiply-add is back in the release's BLAS
where the real family has always kept its own.

## Two measured rules that are not the real family's

**The inner products do not conjugate.** For `x = {3+4i, 1}` and `y = {1+i, 2}` the host answers `1+7i`
for `sparse_inner_product_dense_float_complex`, which is `x.y` term by term; `9-i` is what `conj(x).y`
gives. Both the dense and the sparse-sparse forms are the bilinear form.

**The one norm is the sum of the parts, not the sum of the moduli.** For the values `{3+4i, 1}` the host
answers `8`, which is `(3 + 4) + 1`; the sum of the moduli is `5 + 1 = 6`. The two norm and the infinity
norm are over the moduli - the same vector answers `sqrt(26)` and `5`. This is true of the vector norms
and of the matrix ones: for a matrix whose entries are `3+4i` at `(0,0)`, `1` at `(1,0)` and `-2+i` at
`(1,2)`, the elementwise norms answer `11`, `5.56776` and `5` for one, two and infinity, and the operator
ones answer `8` and `7`. A vector answers zero in a count of zero, a norm the enumeration does not name
is answered as `SPARSE_NORM_INF`, and `SPARSE_NORM_R1` is answered as `SPARSE_NORM_TWO` for a vector and
as a NaN for a matrix - all measured, and the same two fallbacks the real family has.

The operator-two norm is the release's own LAPACK, `cheev_` / `zheev_` over the Hermitian Gram matrix
`A * A'`, and that is the exact answer: the host answers `5.12196` for the matrix above where the exact
largest singular value is `5.12206`, the square root of the larger root of `t^2 - 31t + 125`. That is
the one case in this family with a tolerance, it is `3e-3` in the differential, and it is the host that is
the approximation - the same situation SparseBLAS.md records for the real family's two-norm, where the
port's answer is also the eigen-decomposition and also the exact one.

## Where the host cannot be the oracle

Five places, each named in the differential's case names and each checked against the header's own rule
instead. A differential that cannot ask the host is still a differential: the expectation in each of
these is written out from the header in the test, and it is not the code under test that produces it.
Every one of the five was measured on the host on 2026-10-03, in one program with each case in a child of
its own so that a case which ends the process is reported and does not hide the next.

1. **The outer product's row and column indices.** Not a host defect - the host is right here, and the
   port was wrong. `C[i, indy[k]] = alpha * x[i] * y[k]`: **x is indexed by the row and y by the column.**
   Measured on the host for `M = N = 3`, `nz = 2`, `alpha = 1`, `x = {1, 2, 3}` and `y = {5, -6}` at the
   columns `{0, 2}`: `C[0] = (5, -6)`, `C[1] = (10, -12)`, `C[2] = (15, -18)`, which is `alpha * x[i] * y[k]`
   row by row. Both this family and the real one indexed `x` by the nonzero `k` and wrote the same value
   into every row, which is `alpha * x[k] * y[k]` and agrees with the host **only where x is constant down
   its length** - which is every case either differential had, since they all pass `x = {1, 1}`. Both are
   fixed, both differentials now carry a case with three different values of x, and each carries the
   mutant - the same loop reading x at `k` - which the case asserts differs from the header, so the case
   cannot pass with that bug in it. Measured as a proof rather than asserted: with the port's outer product
   mutated to read x at index 0, both differentials answer exactly one failure, in exactly that case.

2. **A transpose the enumeration does not name, in a matrix-vector product.** The host hands it to
   `cblas_cgemv`: `BLAS error: Parameter transpose passed to cblas_cgemv was 77, which is invalid`, and
   the child exits 255. The port refuses it, which is what the header says.
3. **A zero increment, in a matrix-vector product.** The host hands it to `cblas_cgemv`:
   `BLAS error: Parameter incY passed to cblas_cgemv was 0`, and the child exits 255. The port folds the
   increments into the addresses, so every row's result lands on the one element the increment names and
   the elements between are untouched; the differential checks that against a sum of three products
   written out in the test.
4. **A leading dimension below what the layout needs, in either triangular solve, and an order the
   enumeration does not name.** The host hands it to `cblas_ctrsm`
   (`lda must be >= MAX(M,1): lda=0 M=0 ... cblas_ctrsm had an invalid value`) and walks off the caller's
   buffer; the child exits 255. The real family's differential never asks the host for an `ldb` below what
   the layout needs for the same reason.
5. **A row permutation whose target is outside the matrix or is the row itself.** The host answers
   `SPARSE_SUCCESS` for `{5,5}` on a 2x3 matrix and leaves row 0 holding denormals and a `1e29` - it
   writes through its own row array - and the child then dies on signal 10. The port skips such a target,
   which is what the swap loop the header writes out does, and the differential checks the port against
   that loop run over a plain array of the six entries.
6. **The stored-zero count.** The section below.

Three more, smaller: a matrix that is not one of ours is never handed to either side (the host
dereferences a foreign pointer - measured: `sparse_elementwise_norm_float_complex` on `0x1234` is a
SIGBUS), a `row_end` of `NULL`, and the trace at an offset of 4 or more on a 3x3 (measured: offsets -6 to
3 answer, 4 is a SIGBUS).

## One place the host does not answer one thing

A value of exactly zero, inserted into an empty row. Measured three ways, all with sequenced statements,
all on the same build:

| what is asked | host |
| --- | --- |
| complex, `0@(0,1)` then `2@(1,0)` then `0` over `(1,0)` | count 1, then 1; row 0 holds 1 |
| complex, `0@(0,1)`, `5@(0,1)`, `0@(0,1)`, `0@(1,1)`, `0@(0,0)` | count 1, 1, 1, 2, 3 - the entry stored, the extract answering `0+0i` for it |
| the same three insertions, **real** type | count 1, then 1; row 0 holds 1 |

The second row is what `facts/Accelerate/SparseBLAS.md` records for the real family ("inserting 0.0 into an
empty matrix leaves its nonzero count at 1") and the first and third are what this family's differential
saw, and they are not the same answer to the same calls. A behaviour that differs between two programs on
one build is not a contract, so the port follows the real family's own rule - the entry is stored and
counted - which is also what `sparse_insert_entry_float_complex` is documented to do, and the differential
checks that rule against the port and records the host's answers rather than picking one.

Two further measurements came out of writing the harness, both of which cost real rounds and are the kind
of thing a reader will otherwise repeat:

- `(float)(a + b * 1.0fi)` keeps the **real part only**. Six places in the first version of the
  differential had it and every one of them silently built a matrix with no imaginary parts, after which
  the port and the host agreed on a wrong answer. The imaginary part has to be multiplied in after the
  cast.
- `printf("%d", f(x()), g(y()))` does not sequence `f` before `g`. Three host probes read
  `sparse_get_matrix_nonzero_count` in the same `printf` as the insertion it was supposed to follow and
  reported the count from before it, which is what sent this section the wrong way twice.

## What changed in the shared helpers

Five statics moved out of `SparseBLAS9.m` into `CharonSparseBLAS.h` without a change of behaviour -
`CharonSparseMake`, `CharonSparseRepeated`, `CharonSparseWritable`, `CharonSparsePutEntry` and the two
permutations - because this file needs all of them and a function defined in a file that exports an API
symbol is left out of a band the release already has, which is how a shared C function becomes an
undefined symbol in a later band only. The real family's differential still answers **368 checks, 0
failures** after the move, which is the check that it is the same arithmetic.

One of them changed behaviour, and it is a fix rather than a port of the complex rule:
`CharonSparsePutEntry` refused an index past the end of a matrix but not a **negative** one, so
`sparse_insert_entry_float(A, v, -1, 0)` read `row[-1]` and wrote outside the allocation. Measured on the
host, for the real type and for the complex one alike, all four of `(3,0)`, `(0,3)`, `(-1,0)` and `(0,-1)`
against a 2x2 answer `SPARSE_ILLEGAL_PARAMETER` and change nothing. The guard is now there for both
types.

## What the differential covers

`sh tests/backports/host/sparseblas/run.sh` builds `SparseBLAS9.o`, `SparseProduct10.o` and
`SparseComplex18.o` with every `sparse_*` name the registry carries renamed, and runs two binaries over
them: the real family's `differential.m` (**368 checks, 0 failures**) and this family's
`differential-complex.m` (**170 checks, 0 failures**). Between them every one of the fifty-eight names
is called on both sides with a real and a double value where the two paths differ, and each refusal the
list above is exercised.
