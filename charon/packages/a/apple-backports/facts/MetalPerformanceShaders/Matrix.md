# The matrix and vector kernels of Metal Performance Shaders on this port

`MPSMatrix`, `MPSVector` and their descriptors and temporary forms; `MPSMatrixUnaryKernel` and
`MPSMatrixBinaryKernel`; `MPSMatrixMultiplication`, `MPSMatrixVectorMultiplication`, `MPSMatrixCopy`,
`MPSMatrixSoftMax`, `MPSMatrixLogSoftMax`, `MPSMatrixSoftMaxGradient`, `MPSMatrixLogSoftMaxGradient`,
`MPSMatrixFindTopK`, `MPSMatrixSum`, `MPSMatrixNeuron`, `MPSMatrixNeuronGradient`,
`MPSMatrixFullyConnected`, `MPSMatrixFullyConnectedGradient`, `MPSMatrixBatchNormalization` and
`MPSMatrixBatchNormalizationGradient`. The core they stand on is in [Core.md](Core.md).

Source: the headers of `MPSMatrix` and `MPSNeuralNetwork` in the SDK of iOS 16.4, which is the SDK this
package compiles against, for every signature, default and formula — including the formulas
`MPSCNNNeuronType.h` writes next to each of its cases, and the ones `MPSMatrixSum.h`,
`MPSMatrixFullyConnected.h` and `MPSMatrixBatchNormalization.h` write in their own discussions. The
behaviour was measured against the MPS of macOS 26.5 by `tests/backports/host/mpsmatrix/run.sh`, which
compiles the cases twice — once against the system's own MPS, once against this port's classes under
names of their own — and compares the two answers element by element.

**That earlier claim — "1267 cases, identical bit for bit" — was wrong and is withdrawn.** It was made
from a harness that printed the values it was given rather than the values the kernel wrote, and three
defects in the harness have since been found and fixed: the outputs were prefilled with zero, so "not
written" and "written zero" were the same thing; the hex is little-endian byte order and was read in the
wrong order, which turned 16.0 into 4.0; and a pointer print compared the case's C array with the
object's buffer, which the comparison never mixed. A fourth was mine and not the harness's: a `BUILD`
path one level short wrote the results into `tests/` while I read the worktree root's copy, which was
stale for an afternoon.

**What the harness measures now, as of the last run.** The count of differing cases is not the number
any more, because a count cannot tell a one-unit difference from a 94 %-wrong answer: it said 58 before
the SoftPlus fix and 58 after it. `rank.py` grades each case instead — `identical`, `ulp` against a
64-unit bound, or `non-ulp` — and a case that is not bit-identical, not within the bound and not named
with a reason in `tests/backports/host/mpsmatrix/owed.tsv` fails the run. The five "host divergences"
that used to be dropped from the comparison before anything was measured are gone; nothing is exempt
any more.

On macOS 27.0 build 26A428, over `compared: 141 cases`:

    identical: 70   ulp (bound 64): 53   non-ulp: 18

The 18 are named in `owed.tsv`, each with its reason, and the registry rows of the families behind them
carry the same statement in their `effect`. The largest distance among the rounding cases is 26 units
in the last place (`batch-normalization 12`, 2.93e-06 relative); the smallest non-ulp distance is 751
units (`neuron-gradient-data 15`, GeLU). Each run prints the tree it measured and the grader prints its
own counts, so a number cannot outlive its code.

## A named divergence is not an exemption

This was written the other way round and the coordinator was right to correct it. A case may be
*named* in `tests/backports/host/mpsmatrix/owed.tsv`, with its reason, so that the count of what this
port does not reproduce is a number about this port; it may not be *exempted* from being reproduced.
The runner has no exemption list any more: `run.sh` grades every case it compared and one that is not
bit-identical, not within the bound and not named in that file fails the run.

The bar for a genuine host divergence is a proof that the behaviour is the macOS GPU or driver's and
not MPS's own kernel, with that proof in this file. **The cases named in `owed.tsv` are not proved to
be the host's, so the port has work to do on all of them.**

What the last run measured, on macOS 27.0 (build 26A428), every figure below taken from
`rank.py`'s own output and checked against this paragraph by
`tests/backports/host/mpsmatrix/page-check.py`:

    compared: 141 cases over the first 141 of each run
    identical: 70   ulp (bound 64): 53   non-ulp: 18

The largest distance among the cases that are rounding is **29** units in the last place
(`softmax-gradient`, 2.05e-06 relative) and the smallest among those that are not is **751**
(`neuron-gradient-data 15`, 5.65e-05 relative), so the 64-unit bound sits between two populations
three orders of magnitude apart and not inside either. That run is on a **different operating system
from every other measurement in this file**, which was taken against the MPS of macOS 26.5; it says
that the numbers move with the host's version, and that a re-run has to name the macOS it ran on.

The kernel's own parameters settle what the transposed line is. The probe prints them:

    kernel rows 2 columns 3 transpose 0;  result descriptor 3 x 2 rowBytes 12
    kernel rows 2 columns 3 transpose 1;  result descriptor 3 x 2 rowBytes 12

The kernel takes **the same 2 x 3 in both cases**, and the result descriptor is 3 x 2 with a three-float
row stride either way. Under `transpose` the result is the **3 x 2** shape, so the release lays a 3 x 2
answer into a buffer the descriptor calls 2 x 3, and each row's third column is simply not part of the
answer:

    bias 0 0 0     ->  11 44 0 / 22 55 0
    bias 7 7 7     ->  18 51 0 / 29 62 0
    bias 1 10 100  ->  12 45 0 / 32 65 0

`11 44 0` is not "the release writes zero". It is the transposed 2 x 3 answer `11 44 / 22 55` written
in the transposed shape, whose third column the 2 x 3 descriptor never asked for. **This is a question
of the result's dimensions under transpose and the port must reproduce it** — it is MPS's own kernel
behaviour, so there is no host proof available and none is claimed.

## MPSMatrixSum indexes its bias by column, and the port already did

Measured, not read. `tests/backports/host/mpsmatrix/fixtures/bias-indexing.m` sums `A + B` for a 2 x 3
result - `11 22 33 / 44 55 66` - with three bias vectors:

| bias | answer |
| --- | --- |
| `0 0 0` | `11 22 33 44 55 66` |
| `7 7 7` | `18 29 40 51 62 73` |
| `1 10 100` | `12 32 133 45 65 166` |

**The bias is indexed by column.** A constant vector adds that constant to every element, which is what
`broadcast(bias)` in the header's pseudocode means - broadcast across the rows, not one value - and a
vector that differs per position adds its own value per column. The port did that already; the change I
made and reverted was wrong, and the coordinator's reading - that a bias cannot zero an output, so the
edit broke the kernel rather than refuting the header - was the right one.

## The batch range, and how the release reads it

`MPSMatrixMultiplication` has two passes over the batch: one that checks every matrix holds the region
its origin names, and one that computes. Both start at the batch's **first** index, which is what
`batchStart` is - "the index of the first matrix to process" - and `CharonMPSBatch` implements the
header's rule that a `batchSize` of 0 means all of them.

**The release does not.** Measured over three matrices, right-hand side scaled so matrix *i* writes its
own index, so a written matrix is unmistakable:

| `batchStart` | `batchSize` | matrices the release writes |
| --- | --- | --- |
| 0 | 0 | none |
| 1 | 0 | none |
| 0 | 2 | 0, 1, 2 |
| 1 | 2 | 0, 1, 2 |
| 1 | 1 | 0, 1, 2 |
| 2 | 1 | 0, 1, 2 |

**Two divergences from its own header, both measured.** `batchStart` is **ignored** - every combination
writes the same three matrices - and a `batchSize` of 0 processes **none**, where the header says "0 to
process all of them".

This port follows the header: it starts at `batchStart`, and a `batchSize` of 0 processes everything
available. That is the correct reading and it is not changed to match the host, because the host's
behaviour is not a rule that generalises - it is the same answer for every input, which is what a
property that is read and discarded looks like.

## Where the arithmetic happens

`MPSMatrix` and `MPSVector` are an `MTLBuffer` and a shape. On this port an `MTLBuffer` is host memory
the CPU reads and writes directly (`facts/Metal/RenderPath.md`), so a matrix kernel is a loop over that
memory: the address of element `[matrix, row, column]` is
`buffer.contents + offset + matrix * matrixBytes + row * rowBytes + column * elementSize`, which is
the layout `MPSMatrix.h` states. The result is in the buffer when `-encodeToCommandBuffer:` returns,
which is at least as strong as the release's own contract, which is that it is there once the command
buffer completes.

The eight element data types an `MPSMatrix` may hold — `MPSDataTypeFloat32`, `Float16`, `Int8`,
`Int16`, `Int32`, `UInt8`, `UInt16`, `UInt32` — are all read and written exactly. The others
`MPSDataType` names are not matrix element types: `Invalid`, the normalized encodings and `Bool`
describe how a *texture's* values are stored, and a matrix that is given one is refused in the log
rather than stored as something of a different meaning. `Float16` is IEEE 754 binary16 converted in
software in both directions, with round to nearest even on the way in, rather than through the
compiler's `__fp16`: a half load and store is not available on every armv7 core this port targets, and a
conversion the compiler may fold is a conversion nobody measured.

## The descriptors

`+rowBytesForColumns:dataType:` and `+vectorBytesForLength:dataType:` are the recommended strides, and
the rule was measured over all eight data types and seventy column counts rather than guessed: **zero
columns have no stride, one column is one element, a floating point row is rounded up to a multiple of
sixteen bytes and an integer row to a multiple of four elements.** So one float is four bytes, two
floats are sixteen, five floats are thirty-two, one `int8` is one byte and two are four. The
`MPSMatrixDescriptor` built from rows, columns, a stride and a data type holds **one** matrix, and its
`matrixBytes` is `rows * rowBytes` — both fixed when it is made, and not worked out again when `rows`
or `rowBytes` are changed afterwards, which is what the release does too (the differential prints the
descriptor before and after a mutation and the two runs agree).

## The kernels

* **`MPSMatrixMultiplication`** is `C = alpha * op(A) * op(B) + beta * C` over the three shapes its
  initialiser names, with the left, right and result origins and the `batchStart`/`batchSize` range. The
  release requires an origin's `z` to be zero: the batch is the range, and the origin moves the window
  inside each matrix of it. The differential covers all four transposition combinations with
  `alpha = 2` and `beta = 0.5`, half precision, and a two-of-three batch.
* **`MPSMatrixVectorMultiplication`** is `y = alpha * op(A) * x + beta * y`, both orientations.
* **`MPSMatrixCopy`** moves a `copyRows` x `copyColumns` window from each source of a
  `MPSMatrixCopyDescriptor` into its destination, transposing on the way in or out as the kernel's two
  flags say, from the four offsets the descriptor holds. The per-row and per-column permute vectors
  reorder the result: an index names the source position of the destination row or column, and an index
  outside the window is refused in the log. The descriptor's own array initialiser reads its offsets
  from the `MPSVector` given, which is a packed array of `MPSMatrixOffset` from that vector's offset
  plus the byte offset the caller names.
* **`MPSMatrixSoftMax`** normalises each row, taking the exponentials of the row relative to its
  largest value so they cannot overflow; **`MPSMatrixLogSoftMax`** is the same kernel with that
  subtraction kept in logarithms. Their gradients are the formula `MPSMatrixSoftMax.h` states,
  `dL_dX_ij = Y_ij * (dL_dY_ij - sum_k(dL_dY_ik * Y_ik))`, with `Y` the forward kernel's output.
* **`MPSMatrixFindTopK`** writes the k largest values of each row, largest first, and the column each
  came from counted from `indexOffset`. The differential includes a row with its largest value twice,
  so the order a tie is decided in is compared too.
* **`MPSMatrixSum`** is the operation `MPSMatrixSum.h` writes out: the sum over the sources of
  `alpha[i] * B[i]`, with the factors from the scale vector from `startIndex`, each source read from
  where the packed `MPSMatrixOffset` array says and transposed if the kernel was made that way, then
  the bias broadcast across the rows, then the neuron. The release requires at least two matrices to
  sum.
* **`MPSMatrixNeuron`** is `y = neuron(alpha * x + bias)`, the bias indexed by the column, which is the
  channel. **`MPSMatrixNeuronGradient`** is that neuron's own derivative at the intermediate value times
  `alpha`, with the bias gradient the column sums of the incoming gradient. All fifteen neuron types
  `MPSCNNNeuronType.h` names are in the differential, each with the parameters A, B and C, and PReLU
  with a per-channel A through `-setNeuronToPReLUWithParametersA:`. The derivative of each type is the
  value its own formula differentiates to, computed in double so the ratio that decides a `softplus` or
  a `logarithm`'s parameter is not decided by a rounded one.
* **`MPSMatrixFullyConnected`** is `y = neuron(alpha * x * W + bias)`, the weight matrix
  `inputFeatureChannels` x `outputFeatureChannels`; its gradient's two encodes are `dX = alpha * dY * W^T`
  and `dW = alpha * X^T * dY` with the bias gradient the column sums of `dY`.
* **`MPSMatrixBatchNormalization`** is the formula its header gives,
  `y[i,j] = gamma[j] * (x[i,j] - mean(x[:,j])) / (variance(x[:,j]) + epsilon) + beta[j]` — the variance
  added to epsilon, not the square root of it, as the header writes it. `computeStatistics` makes the
  kernel work from the mean and variance of its input and write them back, which is what a training
  pass needs. The gradient is the usual per-channel form, and the differential prints the mean, the
  variance, the result and all three gradients for every neuron type.

`sourceRows`, `sourceColumns`, `sourceNumberOfFeatureVectors`, `sourceInputFeatureChannels` and
`sourceOutputFeatureChannels` all default to `NSUIntegerMax`, which is the header's "take the shape
from the matrix", and at encode time each is the smaller of what the caller asked for and what the
matrix holds from the origin. `MPSMatrixBatchNormalization.epsilon` defaults to the smallest positive
normal single precision value, so a variance of zero does not divide by zero in a caller who has not
chosen one.

## Refusals

Every kernel checks that each matrix holds the region its origins and shapes name, and that the data
types are element types, and refuses in the log — naming the kernel, the batch and the region — rather
than reading or writing past the end. The release asserts in the same cases. An API in this port does
not crash its caller, and a quiet wrong answer would be worse than either; the destination is left as
it was found. The initialisers the headers mark unavailable (`-init` on `MPSMatrix`, `MPSVector`,
`MPSMatrixCopy`, `MPSMatrixSum`, `MPSState`, `MPSCommandBuffer` and `MPSMatrixCopyDescriptor`,
`-initWithDevice:` on the kernels whose shape their initialiser names, and
`-initWithBuffer:descriptor:` on the temporaries) answer nil with a line in the log naming the
initialiser to use.

## What differs

`MPSMatrixNeuronGradient`'s bias gradient and several of the neuron results differ from the release's.
The neuron results are one or two units in the last place of a `float` and are the rounding work. The
bias gradient was a rule this port had wrong, and `bias-probe.m` now reads the release's answer one
element at a time.

**The rule, read from the release.** With the incoming gradient held to one element at a time and
then to a general one, the release writes, for each feature channel `j` and feature vector `i`:

```
    resultGradientForBiasVector[j]  =  sum over i of   dY[i][j] * f'( alpha * x[i][j] + bias[j] )
    resultGradientForDataMatrix[i][j] =  dY[i][j] * f'( alpha * x[i][j] + bias[j] ) * alpha
```

**The two differ by exactly the scale factor**, because `alpha` scales the input and not the bias, and
`f'` is the neuron's own derivative at the intermediate value. This port was writing the plain column
sum of the incoming gradient into the bias vector, which is that formula only when `f'` is one
everywhere — true of the identity and of nothing else.

The evidence, all of it the release's own answers (`bias-probe.m`):

* a single one in the first column, at the intermediate value `0.5 * (-2) + 0.25 = -0.75`, gives 1 for
  the identity, `a = 1.5` for ReLU below zero and for Linear, and `0.217894986` for the sigmoid, which
  is `s(1-s)` at `s = 1/(1+e^0.75)` — each exactly that neuron's derivative there;
* a general incoming gradient reproduces the formula for ReLU (`5, 5.25, 5.125, 8.0625`, which is the
  per-element derivative changing across the column), for the absolute value (`-2.5, 0.25, 5.125,
  -1.9375`, which is the sign of the intermediate), and for the identity, where it collapses back to
  the column sums.

A claim I made in the same round — that the rule "does not extrapolate" to a general incoming gradient
— was wrong, and came from reading a run whose inputs had not been read back out of their buffers. The
four general cases above are the check.

`-[MPSState resourceSize]`, and with it `MPSStateBatchResourceSize`, answer this port's own number of
bytes — what the state's description implies, or the length of a resource the caller supplied. The
release answers a number about its own heap: a state made from a 64 byte buffer is 16384 there and 64
here. `MPSState.h` says of that method that it "is subject to change between different devices and
operating systems", which is the header declining to promise a value, so this is a documented
divergence rather than a wrong answer. The differential prints both numbers side by side on every run
and compares everything else.

`MPSStateBatchIncrementReadCount` returns the **size of the batch**, not a read count. That is what the
release's own answers say — a batch of one, two and three states answers one, two and three whatever
the counts become — so it is what this port answers. The counts themselves move by the amount, stopping
at zero and saturating at the top rather than wrapping, and the differential prints them around the
call so both facts are compared.

## Not carried yet

`MPSMatrixSolveTriangular`, `MPSMatrixSolveLU`, `MPSMatrixSolveCholesky`, `MPSMatrixDecompositionLU`
and `MPSMatrixDecompositionCholesky` are the linear solvers, and they are the next part of this library.
`MPSMatrixCopyToImage` needs `MPSImage`. Nothing in this file depends on them, and nothing above is
affected by their absence.

The random number generators were on this list once and are not any more: `MPSMatrixRandom`,
`MPSMatrixRandomPhilox`, `MPSMatrixRandomMTGP32` and `MPSMatrixRandomDistributionDescriptor` are
carried, in `MPSMatrixRandom13.m`, `MPSMatrixRandomPhilox13.m`, `MPSMatrixRandomMTGP3213.m` and
`MPSMatrixRandomDistributionDescriptor13.m`, registered in `registry/MetalPerformanceShaders/random.json`
with the measured spread, and written up in `facts/MetalPerformanceShaders/Random.md`.
