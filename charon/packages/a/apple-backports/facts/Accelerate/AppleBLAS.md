# Apple's CBLAS extension, the geadd of iOS 8.0

`appleblas_sgeadd` and `appleblas_dgeadd` are Apple's two additions to the CBLAS interface, and they arrived in iOS 8.0: the release's
own armv7 caches for 4.3, 5.1.1, 6.0, 6.1.3, 7.0 and 7.1.2 name neither, and 8.0 names both. They compute

    C = alpha * op(A) + beta * op(B)

for matrices m x n, with either operand optionally transposed, where m and n are the rows and columns of the *result*. CBLAS 3.x has
no extended-precision geadd, and neither does the release's vecLib (measured: 148 `cblas_*` names on 6.1.3, none of them a geadd),
so this is the one operation of the two that is written here rather than called; it is written over the same element access CBLAS
itself uses, in the caller's own layout, and the release's own `cblas_xerbla` is what reports a bad parameter.

Source: the host's own Accelerate, held against the port case by case by `tests/backports/host/appleblas`, which runs the port's
`AppleBLAS8.m` and the host's Accelerate over the same inputs; the header of iOS 16.4 for the declarations.

## What was measured

Row-major, m = 2, n = 3, A = [[1,2,3],[4,5,6]] and B = [[10,20,30],[40,50,60]]: `alpha` 2 and `beta` 1 gives
[[12,24,36],[48,60,72]] written in place over B, and a `ldc` of 4 with the padding left alone gives the same. `transA` with m = 3
and n = 2 adds A^T = [[1,4],[2,5],[3,6]] to B read as 3x2 with `ldb` 2, giving [[11,24],[32,45],[53,66]]; `transB` with m = 2 and
n = 3 gives A + B^T = [[11,32,53],[24,45,66]]. An `alpha` of 0 with A = NULL gives B and a `beta` of 0 with B = NULL gives A, both
untouched at the other operand, as the header says. Both zero with both operands NULL gives C = 0. An m of 0 leaves every element of C
as it was. In place over A, over B, and over both at once for a square matrix, the answer is right. `appleblas_dgeadd` with
alpha = 3 and beta = 0.5 over [[1,2],[3,4]] and [[10,20],[30,40]] gives [8 16 24 32].

An invalid parameter ends the process: `lda` of 1 with m = 2 prints a BLAS error and exits with status 255 (measured, in a child
process). The port reports through the release's own `cblas_xerbla`, which every band this port supports exports (measured: 4.3,
5.1.1, 6.0, 6.1.3, 7.0, 7.1.2 and 8.0), so the message and the ending are the release's own rather than a copy of them. The wording
differs from the private handler inside Apple's accelerated BLAS on a later release - "Parameter number 8 passed to appleblas_sgeadd
had an invalid value" against "Parameter lda passed to appleblas_sgeadd was 1, which is invalid." - because those are two different
functions; both name the parameter and the routine and both exit 255.

Parameters are checked in the order they are declared, which is the order the reference BLAS checks them in and the number
`cblas_xerbla` is given. A leading dimension is the distance between two consecutive rows in a row-major layout and between two
consecutive columns in a column-major one, so what it must cover is the number of columns in the first case and the number of rows in
the second, of the operand's own shape - which is the other of m and n when the operand is transposed.

## What is reasoned rather than measured

A negative m or n, a `ldc` too small, a NULL C and a transpose outside the four values are refused through `cblas_xerbla` in the same
way a short leading dimension is; the host was not asked for each, because on the host every one of them ends the process and each
case needs a child process of its own. The order of the checks follows the declaration order of the header, which is what the
reference BLAS's xerbla numbers.
