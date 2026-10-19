# MPSMatrix solve and decomposition: five classes at 11.0, and the walks that answer for them

`MPSMatrixSolveTriangular`, `MPSMatrixSolveLU`, `MPSMatrixSolveCholesky`, `MPSMatrixDecompositionLU` and
`MPSMatrixDecompositionCholesky`. One object, `MPSMatrixSolve11.m`. `MPSMatrixSolve.h:32` and `:132` and
`MPSMatrixDecomposition.h:63` and `:147`, and the Cholesky solve's own annotation, each put
`MPS_CLASS_AVAILABLE_STARTING(macos(10.13), ios(11.0), macCatalyst(13.0), tvos(11.0))` above the class's
declaration, so the object carries one release and nothing else does.

**The ladder agrees independently**: `first-rung.lua` answers `11.0` for all five class symbols, so the
placement is the release's own cache and not the annotation alone.

## What decided that this is work and not a missing capability

`MPSMatrixUnaryKernel` and `MPSMatrixBinaryKernel` are classes this port already carries (`matrix.json`,
introduced 11.0, **implemented**), and every one of these five encodes takes `MPSMatrix` objects — no
`MTLComputeCommandEncoder`, no dispatch, nothing this host would have to encode to reach. The arithmetic
they name is arithmetic a CPU already does: a triangular substitution, an LU solve against a
factorization, a Cholesky factorization, a Cholesky solve. `MPSMatrixVectorMultiplication11.m` already
walks a matrix through `CharonMPSMatrixViewOf` / `CharonMPSMatrixElement` / `CharonMPSLoad` /
`CharonMPSStore`, and this file reuses that substrate rather than writing a second answer for the same
walk.

## The oracle is a ROUND TRIP, and that is the reason this family is checkable at all

This host's AGX family lacks `computeCommandEncoderWithDispatchType:` and the release's own kernel dies
encoding, so the release is not the oracle and **no number on these rows measures Apple's code**. What
*can* be checked without it is the identity each header states:

- a **factorization** is right when its factors multiply back to the matrix that went in —
  `MPSMatrixDecomposition.h:138-139` `A = L * L**T` or `A = U**T * U`;
- a **solve** is right when its answer multiplied by `A` gives `B` — `MPSMatrixSolve.h:24-26`.

Both are statements about the ANSWER, so neither needs to agree with the release's pivot order or its
rounding. `CharonMPSMatrixSolveReference.h` writes them in plain C and never names the port's class.

**What is deliberately not checked: the pivot INDICES.** `MPSMatrixDecomposition.h:92-94` says the array
holds "an array of size 1xmin(rows, columns) values. Element type must be `MPSDataTypeUInt32`" and says
nothing about *which* row is chosen. Partial pivoting is this port's choice and the rows say so; the
factors do not depend on it, only the order of the rows does, which is exactly why the round trip is the
right check and an index comparison would not be.

## The measurement

    $ sh tests/backports/host/mpsmatrixsolve/run.sh
    compared 53 mismatches 0
    PASS: 53 elements compared, 0 mismatches

53 answers: two Cholesky round trips at 9 each, two LU round trips at 9 each, four status checks (two
non-positive-definite, two singular — checked *as* the header's own values at `:37-40`), and five solves
checked by `A*X == alpha*B` over 3, 3, 3, 6 and 6 elements.

The matrices are chosen so a wrong walk cannot agree by accident: a symmetric positive-definite matrix
whose factor has one **irrational** entry (`L(2,2) = sqrt(5)`), which is why the factors are not compared
entry by entry and the round trip is used instead — the irrationality cancels in the product — and a
rank-deficient matrix that has to answer `Singular` rather than divide by a zero pivot.

`MPSMatrixSolveTriangular` is checked for `A*X == alpha*B` at **`alpha` = 1.0 and at `alpha` = 2.0**,
because `MPSMatrixSolve.h:24` puts `alpha * B` in the system and a kernel that ignored the scale would
answer differently without any other case noticing.

## Five defects the round trip caught, each fixed at the cause

This family produced more real defects than any other in the band, and every one was found by a check
rather than by reading:

1. **`cholesky-order`** — the factorization looped over the whole square and derived `(r,c)` from
   `(row,column)`, which computes `(1,1)` before `(1,0)`. `L(r,c)` depends on `L(r,k)` and `L(c,k)` for
   `k < c`, so at `(1,1)` the entry `L(1,0)` was still the caller's zero, the inner product came out
   empty, and the factor was `sqrt(A(r,r))` instead of `sqrt(A(r,r) - L(r,c-1)^2)`. The factor came out
   `[2 1 1; 0 2.236 0.447; 0 0 2.449]` whose `L*L**T` is `[4 2 2; 2 6 2; 2 2 7.2]` against a source of
   `[4 2 2; 2 5 1; 2 1 6]` — **42 of the run's 62 elements wrong**. Fixed by walking the triangle in
   dependency order.
2. **The triangle mirror appeared at four different index sites** and one of them disagreed with the
   write, so the upper Cholesky's inner products were empty. Fixed by making `CharonMPSCholeskyFactor`
   the *only* place `lower` appears on a read.
3. **`solves-transpose`** — the Cholesky solve substituted through the stored triangle **twice** and
   never its transpose, so it solved a different system: `(1, 0.75, 1.4)` where the solution is
   `(-0.075, 0.75, 1.4)`. The last two rows were right and only the first was wrong, because that is the
   one read after the others overwrote it.
4. **The backward pass was indexed by a `step` running the opposite way from `row`**, so `step 2` named
   `row 0` while its subtraction range was empty. Same symptom, different cause from (3).
5. **`lu-unit-diagonal`** — the LU solve's forward pass **divided** by `L(row,row)`, which is `U`'s value
   there. `L`'s diagonal is all ones, which is what `MPSMatrixSolveTriangular`'s own `unit` parameter
   names (`MPSMatrixSolve.h:50-52`). It also swapped cells of the caller's `b` in place; nothing in the
   header says an encode modifies `b`, so the pivot order now reads `b` and never writes it.

Two more were in the **harness**, and are recorded because a differential that is wrong in the same way
twice is worse than none: it multiplied the *combined* `L|U` matrix by itself instead of splitting it;
it read `UInt32` pivot indices as `float` and saw `1.4e-45` where the bits were `1`; and it reused one
array of right-hand sides for two different coefficient matrices while documenting a third.

## The mutation campaign

    $ sh tests/backports/host/mpsmatrixsolve/mutation.sh
    anchor check: 5 sites compared, 0 not resolving exactly once
    baseline: PASS: 53 elements compared, 0 mismatches
      cholesky-order     FAIL: 3 mismatches over 37 compared
      solves-transpose   FAIL: 6 mismatches over 53 compared
      lu-unit-diagonal   FAIL: 6 mismatches over 53 compared
      lu-singular-status FAIL: 7 mismatches over 59 compared
      cholesky-positive  FAIL: 1 mismatches over 53 compared
    restored: PASS: 53 elements compared, 0 mismatches
    campaign: 5 caught, 0 not caught

A green differential says nothing unless it **can** be red. Each of the five claims above is defended by a
mutation that breaks exactly that claim — and the first version of the `cholesky-order` mutant was
*semantically equivalent* to the original, so it left the run green and the campaign correctly reported
`NOT CAUGHT`. A mutation that cannot fail is not a test; that one was rewritten to walk `c` outer and `r`
downward, which genuinely visits `(2,2)` before `(2,0)`.

## The bound

A factorization of exactly-representable entries is exact, and a solve divides — so a solve's answers are
held to **one whole float32 ulp**, the bound `mps-reference.h` and `CharonNNReduceReference.h` already
state for the other families, not widened here. The Cholesky solve's factor is heap-allocated at the order
it was given, with no fixed ceiling: a limit written into the code would refuse an order the release
factors, and would have to be a second answer for a caller to choose between.