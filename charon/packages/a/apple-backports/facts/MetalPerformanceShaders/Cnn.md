# The convolutional kernels: the first slice of the CNN family

`MPSCNNConvolution`, `MPSCNNConvolutionDescriptor`, `MPSCNNConvolutionWeightsAndBiasesState`,
`MPSCNNPooling`, `MPSCNNPoolingAverage`, `MPSCNNPoolingMax` and `MPSCNNBatchNormalization`.

The reference is **ncnn** at `c6b351b56fbe32e0381ae00331e3df649b20d7b7` (BSD 3-Clause), read from
`https://github.com/tencent/ncnn` — a fresh clone, not a package cache, which `charon/AGENTS.md` says is
patched. Three things were taken from it, and each is named where it is used.

## The convolution

`Convolution::convolution` (line 157) is the walk this port uses: a `space_ofs` table of the kernel's
taps, computed once for the stride and the dilation, then per output channel and output pixel one
accumulator seeded with that channel's bias, walked over the input channels and the taps, with the
neuron's function applied once to the accumulator. The weights are read in the OHWI layout the release
uses: output, kernel height, kernel width, input channels.

What differs is where the values live — an `MPSImage` is a plane per feature channel, not an `ncnn::Mat`
per channel — and that **a tap outside the image contributes nothing**, rather than reading a bordered
copy of the input, which is what the release's `MPSImageEdgeModeClamp` describes and what
`MPSCNNPadding` will have to say. `groups` other than 1 is refused in the log: it is a different walk
and is not carried yet.

## The pooling divisor, measured

**The divisor is the window's area, always.** A 3x3 window over a 3x3 image, a stride of one, the zero
edge mode, so that the corner windows hang half outside: the top left answers **1.33333**, which is
12/9 — the sum of the four values really there over the whole window — and not 12/4, the count of them.
Setting `zeroPadSize` to one on each side changes nothing, so the pad does not grow the window here.

That is ncnn's rule with `avgpool_count_include_pad` set (`Pooling`, parameter 6): the window is
divided by, and what falls outside is zero rather than skipped. ncnn's other setting, dividing by the
count of the values really there, is the one MPS does not take. Getting this wrong was caught by the
differential, which is what it is for: the port had been growing the window by the pad and dividing by
the grown area.

## The normalisation fold

`BatchNorm::load_model` folds the normalisation once, when the parameters are given, into

    a = beta  - gamma * mean / sqrt(variance + epsilon)
    b = gamma /               sqrt(variance + epsilon)
    value = b * value + a

so the loop that normalises an image is a multiply and an add per value, with no division and no square
root in it, and a zero variance is sanitised to a divisor of 0.0001 the way ncnn sanitises it.

**Epsilon is inside that fold, so changing it has to fold again.** The differential caught this: the
release answers -4.0356 for the first value with epsilon 0.25, which is a fold that used it, and a fold
made when the state was created answers -4.3990, which is a fold that did not. `-setEpsilon:` folds
again.

## The output shape, measured

The release's pooling output is **not cropped to the window arithmetic**. Over a 4x4 source of 1..16, a
2x2 window and a stride of one, the whole destination read back with a 4-wide row stride answers sums
over the window's area of

    1   3   5   7
    6   14  18  22
    14  30  34  38
    22  46  50  54

and every one is **the 2x2 window whose top-left is one row and one column before the output pixel**,
with what lies outside the source counted as zero but still in the divisor: the output is the
source-sized result, shifted a row and a column, its first row and column partial. A 3x3 window over a
3x3 image has the whole image in every interior window, which is why the maximum and the 3x3-average
cases agreed with a cropped walk all along.

**This port answers the same values.** Measured on both sides of a standalone program over a 3x3 source
of 1..9, a 2x2 window, a stride of one, the zero edge mode:

| destination | release | this port |
| --- | --- | --- |
| 2x2 | `0.25  0.75  1.25  3` | `0.25  0.75  1.25  3` |
| 3x3 | `0.25  0.75  1.25  1.25  3  4  2.75  6  7` | `0.25  0.75  1.25  1.25  3  4  2.75  6  7` |

So the window is centred, the divisor is its area, and what falls outside is zero - which is what
`MPSCNNPooling10.m` does, and there is no second, source-sized path to add: one rule answers both
destination sizes the release answers. The stride-1 offset in the table above is the centred one, not a
separate shift; a 2x2 window centred on the first pixel takes the first pixel alone, and a 3x3 one takes
the first three.

## What the host differential says

`tests/backports/host/mpscnn/` compiles `cnn-cases.m` twice - once against the system's MPS, once
against this port's classes with the MPS names mapped to `Charon` names and their selectors prefixed -
and compares with a tolerance written down before the numbers were read: **1e-4 absolute or relative**
for a single-precision result, because a convolution accumulates in a different order on a GPU than on
a CPU, and **exact** for pooling, whose cases are named as such.

**Five of the six cases are bit-identical**, and they are the run's own list: `pooling-max`,
`pooling-average-pad0`, `pooling-average-pad1`, `pooling-average-2x2` and `fresh-image`.
`batch-normalization` is **not** one of them and does not agree bit for bit: eight of its nine elements
do, and the ninth is 8.05928898 on the release against 8.05928993 on this port, which is the largest
distance anywhere in the slice at 1.18e-07 relative. A page that lists a case among the identical ones and
then prints that case's one differing element twelve lines later is a page written from memory; the list
above is the run's, and `tests/backports/host/mpscnn/page-check.py` checks it on every run.

**`fresh-image` is the sixth case and it is here because the other five could not see it.** Every other
case writes its image before it reads it, so none of them can see what a fresh image holds, and a port
that left one with whatever its texture carried would pass all five. `fresh-image` makes no image hold a
written value at all: it builds one and reads it straight back, and both sides must answer zeros.

**The width of the tolerance.** The normalisation case is the one the tolerance is for, and the harness
prints how close each case came to it rather than only how many failed:

    cases: 6, tolerance 0.0001 absolute or relative
    closest to the tolerance, as a fraction of it:
      batch-normalization          0.00118
    differing cases: 0

So the largest distance anywhere in the six cases is 1.18e-07, and the 1e-4 bound is 847 times
wider than the number it is compared against. That is a real margin and it is worth saying out loud
rather than leaving to a reader: six cases back 82 rows, and a wrong answer smaller than 1e-7 would
not be noticed by them. The same comparison run at 1e-7 fails - `differing cases: 1`, and the case
reads `1.18` of the bound - so the bound is the only thing between this slice and a silent small
wrong answer, and it is 847 times wider than the measurement.

**Five of six bit-identical; the normalisation case within 1.18e-07 on one of nine elements.**

Getting there took two defects, and the second was found only because the first had made a measurement
look like a result.

* **The harness was comparing the host with itself.** The port's objects were compiled under a rename
  that covered only the `MPSCNN` names the cases reached, so every other class this library defines was
  registered under the host's names and the port's `MPSKernel` was the host's. The rename now covers
  every class the port defines - derived from `nm -g --defined-only` of its objects, not from the
  sources - and the port link is the whole library, so a superclass pointer resolves to the class that
  is present. Every run prints `class_getImageName` for each compared class under both names.
* **The pooling kernels defaulted their outside taps to clamp.** With no edge mode set, a corner window
  clamped every outside tap to the nearest interior value - the same pixel four times - and answered
  `1` where the release answers `0.25`. The three cases that set `MPSImageEdgeModeZero` explicitly were
  green throughout, which is why only the one case that did not set it exposed this. The release's
  default is zero, measured on that same case, and the kernels now default to it.

The lesson worth keeping, because it happened twice in this family: **a link without the rename does not
measure the port at all** - it measures the host, and agrees with it perfectly. A harness that cannot
show, on its own output, which classes it is talking to will report a false agreement.

## That the comparison can fail

Two mutations of this port, each reverted, each shown red against the release:

* **the pooling kernels' default edge mode back to clamp** - `pooling-average-2x2` goes to
  `system 0.25 port 1`, one case differing. It is the only case that does not set an edge mode, so it is
  the only one that sees the default.
* **the divisor counting only the taps inside the image** - three cases red: `pooling-average-2x2` to
  `system 0.25 port 1`, and `pooling-average-pad0` and `pooling-average-pad1` both to
  `system 1.33333 port 3`, which is 12 over 4 rather than 12 over 9.

The second is the one that matters for the rule in this file: the three 3x3 cases are where the divisor
is the whole window, and a divisor that counted only the values really there would pass the 2x2 case
and fail all three of those. Both mutations are in `git log` as their own commits, and the tree carries
neither.


## The batch-normalisation gradient: the host's zeros, and what the header's formula gives

**The inputs, exactly.** A 4x3 single precision batch, `source` and `incoming` both
`{{1,2,3},{4,5,7},{2,8,1},{9,1,5}}`, `mean = {4, 5, 4}`, `variance = {8, 6, 6}`,
`gamma = {2, 0.75, 1.5}`, `beta = {0.5, -0.5, 1}`, `epsilon = 0.001`, no neuron, no batch,
result vectors prefilled with `0x7f` per element so a buffer the release left alone is
distinguishable from one it filled with zero.

**What the header's formula gives.** `MPSMatrixBatchNormalization.h` documents
`resultGradientForGammaVector` as the gradient with respect to the gamma terms, which is
`sum over feature vectors of dY * xhat`, with `xhat = (x - mean) / sqrt(variance + epsilon)`:

    xhat, channel 0:  -1.06059, 0, -0.707063, 1.76766      (terms 1, 4, 2, 9)
    gamma = -1.0606 - 1.4141 + 15.909 = 13.4342
    gamma = 13.4342, 5.7150, 8.1643        beta = 16, 16, 16

That is computed in the case file by a scalar loop, term by term, and it is what this port answers.

**What the host answers: zeros, from two MPS entry points.**

    MPSMatrixBatchNormalizationGradient   gamma 0, 0, 0    beta 0, 0, 0
    MPSGraph normalizationGradient         gamma 0, 0, 0

with `MTLCommandBufferStatusCommitted` and no error, against the prefilled `0x7f` — so the
release wrote the zeros rather than leaving the buffers alone. The forward
`MPSMatrixBatchNormalization` on the same inputs answers non-zero, so it is specific to the
gradient.

**Two MPS entry points agree on 0; the header's formula gives 13.43.** That is a host
divergence, and this port follows the header.

**The caveat, which is the reason it is written this way:** MPSGraph and
MPSMatrixBatchNormalization are *not* independent oracles. Both are Apple's MPS, both reach the
same internals, and a defect in one shared path would show in both. The two runs establish
that this is MPS's answer and not a usage error in this case — which is what a second entry
point can establish — and not that two independent implementations agree. One implementation,
two doors.

**What it took to get here, since three of the steps were misreadings rather than faults:** the
outputs were memset to zero, so "not written" and "written zero" were the same thing; the
`put` hex is little-endian byte order and `00008041` was read as 4.0 when it is 16.0; and a
pointer print compared the case's C array with the object's buffer, which the comparison never
mixed. Each of those produced a confident wrong number. The case file now prints the values as
text beside the hex, which is what would have caught all three at once.

## Batch normalisation: the family is a rounding difference, and that is now measured

The forward is correct in structure. On the case's own inputs, with the header's formula worked out by
hand, the release, this port and the scalar reference agree on **all twelve elements to the six decimals
printed**:

    y = gamma * (x - mean) / sqrt(variance + epsilon) + beta

    host  -1.090891 -1.418482  0.183571  0.500000 -0.500000  3.449286
          -0.560594  0.418482 -1.449286  3.151485 -1.724643  1.816429
    port  the same
    ref   the same

**What differs is a few units in the last place, and it is not always one.** Measured as the
distance between the two `float` bit patterns, over the nineteen cases that differ:

| case | elements differing | ulp distances |
| --- | --- | --- |
| `batch-normalization 0`, `1` | 2 each | 1, 1 |
| `batch-normalization 2` | 5 | **7**, 2, 1, 1, 1 |
| `batch-normalization 3`, `5` | 6, 5 | all 1 |
| `batch-normalization 4`, `6`, `8` | 1, 2, 4 | all 1 |
| `batch-normalization 7` | 9 | 1, 2, 1, 1, 2, 2, 3, 2 |
| `batch-normalization 9`, `11` | 3, 1 | 1, 1, 2 / 1 |
| `batch-normalization 12` | 8 | **13**, 2, 3, 1, 1, 1, 1, 2 |
| `batch-normalization 13`, `14`, `15` | 6, 4, 10 | 1–2, and 3 and 8 on case 15 |
| `batch-normalization-statistics-result` | 4 | all 1 |
| the three `gradient` cases | 3, 11, 3 | **not rounding at all** — the host writes zeros, so the distance is from zero |

**So "the last bit" was wrong and is corrected here.** Most of the family is 1 ulp, which is a tie-break,
but case 2 is 7 and case 12 is 13, which is a **precision** difference and not a rounding of the same
value. That is what a `float32` evaluation against a `double` one looks like when the argument is
already reduced - and it says the single-precision formulation has to be written in the order the
release evaluates it, not merely narrowed.

The fix is the port's to make: the same single-precision formulation the release uses, `float` from
the multiply onwards. It is the ulp work, and it is the last thing this family's structure is waiting
on.

## The gradient's per-parameter vectors: the host computes the kernel and does not fill them

The three gradient cases come back zeros from the release against real values here, which is not
rounding, so `tests/backports/host/mpsmatrix/fixtures/batchnorm-gradient.m` asks the three questions
that decide it.

**Does the host compute it at all? Yes.** The command buffer reports `MTLCommandBufferStatusCompleted`
with no error, and `resultGradientForDataMatrix` holds real values:

    gradient data:  0.298056 -0.0766294 -0.136185  0 0.306161 0.408554 0.198704 0.688951 ...

**Is the destination a different buffer from the one read back? No.** Every object answers the buffer it
was made from: `out.data == outb`, `gg.data == ggb`, `gbeta.data == gbb`, all true. There is no aliasing
and no second allocation.

**Does the host need a state object from the forward pass? No.** The forward is run and completed first
and its statistics are given to the gradient as the ordinary mean and variance vectors; the gradient
needs nothing the forward left behind.

And the answer to the question that started it: `resultGradientForGammaVector` and
`resultGradientForBetaVector` come back **zero** while the data gradient is real. So the release runs
its gradient kernel, writes one of its three outputs and leaves the other two at whatever they were.

**That is the release's own kernel, so the port's answer there stays unclaimed.** It is not rounding, it
is not a harness artifact, and it is not a driver property to be excused as one — it is what MPS does,
measured, and the port writes the header's formula for those two vectors. The facts say so and the
registry carries the effect; nothing is changed to match zeros.

### And there is no switch: the class dump

`tests/backports/host/mpsmatrix/fixtures/gradient-class.m` walks the host's own class, printing the
accessors it declares, and the answer is closed:

    MPSMatrixBatchNormalizationGradient   super MPSMatrixBinaryKernel
      epsilon  neuronA  neuronB  neuronC  neuronType
      neuronParameterA  neuronParameterB  neuronParameterC
      sourceInputFeatureChannels  sourceNumberOfFeatureVectors
    MPSMatrixBinaryKernel   super MPSKernel
      batchStart  batchSize  primarySourceMatrixOrigin  secondarySourceMatrixOrigin
      resultMatrixOrigin

**No switch, and no flag that could be one.** Note the shape of the difference from the forward, which
*does* declare `computeStatistics`: the gradient has no equivalent, so there is nothing to set.

**And the gamma vector does not have to be passed.** The probe in `batchnorm-gradient.m` passes a
`gammaVector` and still gets zeros, so the "without it the gradient is not computed" reading is closed
from the other side: passing it changes nothing.

**So the system wins, and the port is to write what the host writes.** The per-parameter gradients are
left untouched rather than computed, and the facts say so with the program that shows it.

### The data gradient: the self-check fires, so the port is not changed

Sixteen variants of the data gradient were computed against the host's own answer for
`batch-normalization-gradient-data` — the mean from the given vector or from the batch, the
variance from the given vector or from the batch, with and without gamma, and the aggregation as
means or as sums — and **two of them score identically**:

    0.41152  batch mean, given var, with gamma, mean(dY) and mean(dY*xhat)
    0.41152  given mean, given var, with gamma, mean(dY) and mean(dY*xhat)

That is the self-check's stop condition and **the port is not changed on this**. The tie is not a
coincidence either: for column 0 the given mean and the batch mean are both 4, so every variant that
distinguishes them collapses to the same number here, and this case cannot separate them.

What the variants do show is that the host's answer is not this family at all. The best of the sixteen
matches the host on element 0 exactly — `0.298056` — and then misses the other two of that column
badly:

    row 0   host  0.298056   variant  0.298056
    row 1   host -0.076629   variant  0.000000
    row 2   host -0.136185   variant  0.198704

Row 1 coming out exactly zero is the tell: the variant's mean subtraction is exact there, and the
host's is not. So the host's data gradient is not `(gamma/sqrt(variance+eps)) * (dY - mean(dY) -
xhat * mean(dY*xhat))` under any of the sixteen choices, and the difference is structural rather than
a rounding. The formula needs a probe of its own, on inputs chosen so that each of the sixteen
separates — different given and batch means, and a batch whose variance differs from the one given.

### The separating inputs, designed, and what the self-check can and cannot ask of them

The case the differential uses cannot separate the variants — its given mean and its batch mean are
both 4. The inputs chosen instead, on which every distinction is live:

    source        1  3  7  2  9  4  5  1 11  8  6  2      (four feature vectors by three channels)
    dY            4  2  9  1  7  3  6  3  5  2  8  1
    given mean    2  5  4        against a batch mean of  3.25  5  6
    given var     7  3  9        against a batch var of   3.6875 7  3
    gamma       1.5  0.75 2     epsilon 0.125

**The given and batch statistics are genuinely different now**, where the old case had them equal for
column 0 — which is the whole reason the sixteen collapsed there.

**And the self-check has to be stated carefully, which the design shows.** The family is 64: sixteen of
the standard form and sixteen of the form that is not the standard formula at all, `dX = gamma/sigma *
dY` with no mean terms. On these inputs the **sixteen standard-form variants are all distinct**; the
eighty collisions are all inside the plain form, and they are **structural rather than a fault in the
inputs**: a form with no mean terms cannot depend on which mean or which aggregation was chosen, so
variants differing only in those axes are identical *by construction*. The right check is therefore
two — the standard-form sixteen distinct from each other, and the plain sixteen distinct **from the
standard sixteen** — not sixty-four distinct, which is unaskable.

The host has not been run on these inputs yet: the program was written and did not compile in the
time left, so no fixture is committed and no host answer is claimed. The design and the check are
recorded here so the next turn writes the program against them.

### The separating probe, run: no variant of the family is the host's formula

`tests/backports/host/mpsmatrix/fixtures/gradient-separating.m` runs on inputs where the given and
batch statistics differ, and it **passes its own two-part check first**: the sixteen standard-form
variants are all distinct from each other (0 collisions), and the plain and axis forms are all distinct
from the standard ones (0 collisions). So the family separates and the host is inside the search.

The host's data gradient at element (0, 0) is `0.778845072`, and **none of the sixty-four variants
equals it.** The sixteen standard-form values run from `-3.327` to `1.886`:

     -3.327  mean given, var batch, gamma with,  agg sum,   axis vectors
     -3.007  mean given, var batch, gamma without, agg mean,  axis vectors
     -2.493  mean given, var given, gamma with,  agg sum,   axis vectors
     -2.219  mean given, var given, gamma without, agg sum,  axis vectors
     -2.005  mean given, var given, gamma without, agg mean,  axis vectors
     -1.674  mean given, var batch, gamma with,  agg mean,  axis vectors
     -1.663  mean given, var given, gamma with,  agg sum,   axis vectors
     -1.117  mean given, var given, gamma with,  agg mean,  axis vectors
      0.569  mean batch, var given, gamma without, agg sum,  axis vectors
      0.623  mean batch, var given, gamma without, agg mean,  axis vectors
      0.779  **the host** - no variant
      0.854  mean batch, var batch, gamma without, agg sum,  axis vectors
      0.934  mean batch, var batch, gamma without, agg mean,  axis vectors
      1.121  mean batch, var given, gamma with,    agg sum,   axis vectors
      1.257  mean batch, var given, gamma with,    agg mean,  axis vectors
      1.681  mean batch, var batch, gamma with,    agg sum,   axis vectors
      1.886  mean batch, var batch, gamma with,    agg mean,  axis vectors

So the host's data gradient is not this family at all - not the standard formula under any of the mean,
variance, gamma or aggregation choices, not the same over the other axis, and not the plain
`gamma/sigma * dY` with no mean terms. **The port's `gradient-data` stays unclaimed**, exactly as
the untouched per-parameter vectors do: the port writes the header's formula, the host writes something
else that no variant here reproduces, and no case should be marked matching on a guess. The probe is the
fixture, and it re-runs the whole search and the two-part check in one program.

### The Jacobian, and the axis it answers

`tests/backports/host/mpsmatrix/fixtures/gradient-jacobian.m`, with its output beside it in
`fixtures/gradient-jacobian.txt`. For a fixed source dX is linear in dY, so one run per unit matrix
gives the twelve columns of the Jacobian, and linearity is checked rather than assumed:

    linearity: dY = e_0 + e_1 against the sum of the two columns, largest difference 0 - linear

**The axis is the feature channel.** `dX[0]` has non-zeros only in columns 0, 3 and 9 — the four
elements of dY's channel 0 — and `dX[1]` only in columns 1, 4 and 10, the four of channel 1. So
`dX[r][c]` depends on every element of `dY[·][c]` and on nothing in the other channels. That is the
axis the standard formula has, and it is now measured rather than inferred from a formula that did not
fit.

**And the host fills the whole destination — a correction.** With a `-1.0e30` sentinel in the
destination, **every one of the twelve unit columns comes back with all twelve elements written**
(`(none)` untouched, twelve times). So the `-inf` and the astronomical values in the earlier run were
not unwritten bytes at all: they are what the host's own formula produces on the inputs I chose, a
division by a zero variance or an overflow inside its block. The port writes its twelve elements, and
so does the host. The "partly unwritten" claim this paragraph made last turn is withdrawn, and the
sentinel is what caught it.

So the host's data gradient is **block diagonal on the feature channel** and **linear**, and it writes
every element — and the block is still not the standard form, since the sixteen variants of it did not
fit. The next step is the block alone, one channel at a time, which removes the coupling between
channels and leaves a four by four operator to identify.

### Where the host's `-inf` and its 2.58e26 come from: the gradient's own mean, not the source's

The sentinel showed the host writes every element, so those two values are its own arithmetic. I then
computed the per-channel statistics and found an exact zero in channel 1, and **concluded the block
degenerates when the data is already centred.**

**That conclusion was wrong, and the way it was wrong is worth recording.** The batch normalisation's
statistics are of the **source `x`**, and my table had computed the mean and variance of **`dY`** while
the reasoning talked about the source. Recomputed over `x`:

| quantity | channel 0 | channel 1 | channel 2 |
| --- | --- | --- | --- |
| `x` batch mean | 4.0 | 4.75 | 6.0 |
| `x` batch var | 7.5 | 9.1875 | 11.5 |
| given mean | 2 | 5 | 4 |
| **given mean − `x` batch mean** | −2.0 | **+0.25** | −2.0 |
| given var − `x` batch var | −0.5 | −6.1875 | −2.5 |
| **mean(dY) − given mean** | +1.25 | **0.0** | +0.5 |
| `sum (x − given mean)` | +8 | −1 | +8 |

**There is no exact zero among the source's statistics** — the closest is +0.25 in channel 1. The only
exact zero in the whole table is `mean(dY) − given mean` in channel 1, where `dY`'s mean is 5 and the
given mean is 5.

So the degeneracy is not about the source being centred at all. It is that **the host's block has a
term that divides by, or cancels against, the incoming gradient's own mean minus the given mean** — a
quantity the standard formula has no use for, and which is exactly why none of the sixteen variants
fitted.

The next probe is then not about the source at all: it is the four by four block of channel 1 with
`dY`'s mean moved by ±δ around the given mean, three runs, to see the divergence as a function of that
one quantity.

### The argument orders, and the order is not it either

`tests/backports/host/mpsmatrix/fixtures/gradient-orders.txt`, three runs of one program:

    as declared                        host dX at (0, 0) =   0.778845072
    gradient and source swapped                    =  -1.68092501
    mean and variance vectors swapped              = -34.5620041

**None of the three is a variant of the family, and the swapped orders are not closer than the declared
one** — the closest of the sixteen is `0.0060` from `-1.68` and `0.0752` from `0.779`. So the release is
not reading the gradient and the source the other way round, nor the mean and variance the other way
round. The order is not the explanation.

**And the linearity result rules out the `dY` divisor on its own terms**, which is the correction worth
keeping: I had claimed the block divides by `mean(dY) − given mean`, and a quantity linear in `dY` cannot
sit in a denominator of an operator that is exactly linear in `dY` — `e_0 + e_1` equals the sum of the
columns with a difference of 0. So that claim is wrong independently of the table being wrong.

**Where the case stands.** Four probes now say the same thing from different directions: the
sixteen standard variants do not fit; the plain and axis forms do not fit; the three argument orders do
not fit; and the operator is linear, block diagonal by channel, and writes every element. **`-s`
`batch-normalization-gradient-data` stays unclaimed**, with all of it in this section — the port writes
the header's formula, the host writes something outside the family tried, and nothing is marked matching
on a guess.

### `rsqrtf` is not in Apple's libm, on either side

`rsqrtf` is **not declared in Apple's libm on the host or on the device**, and the error says so where it is
matters:

    MPSMatrixBatchNormalization12.m:172:30: error: call to undeclared function 'rsqrtf';
      ISO C99 and later do not support implicit function declarations

This came from compiling the **host's own** harness, on macOS 26.5, with the system clang and the system
SDK, so it is a fact about the whole Apple libm and not about the iOS SDK this port builds against and not
about a missing include: adding `<math.h>` leaves the call undeclared. The file compiles without the
include, so it does not have one.

**So the ulp search is four candidates, not eight.** The root is taken by division or not taken at all
here, and what remains is `1 x 2 x 2`: the root by division, gamma before or after the divide, and the two
products fused or not. A hand-written Newton step would make the eighth arm build, and it is not wanted: an
inverse root that is not a call the platform makes is a guess wearing a primitive's name. **If the four do
not reach the host, the finding is that the host's root is not reproducible natively here, and the case is
a named divergence** - not that a Newton iteration would have closed it.

This also means the host's rounding, whatever produces it, is not `rsqrtf` as this SDK names it: the
answer has to be found in what the four give, and if none of them is a fit the conclusion stands as
stated rather than as a missing arm.

### The forward's residual is not a rounding choice: the four candidates are value-equal

Scored over the forward's 15 cases, 90 elements, against `cand0/system.txt`:

| candidate | root | gamma | products | total ulp | worst | sign flips |
| --- | --- | --- | --- | --- | --- | --- |
| b0 | division | before the divide | plain | 120 | 26 | 0 |
| b2 | division | after the divide | plain | 120 | 26 | 0 |
| b4 | division | before the divide | fused | 120 | 26 | 0 |
| b6 | division | after the divide | fused | 120 | 26 | 0 |

**All four score the same, which is the stop: two candidates with the same score.** The search is over and
has no winner, so the forward's residual is not a rounding-choice defect.

**And the check that closes it: the four `port.txt` files differ in four lines, all of them addresses.**

    1247c1247
    <   REF-CASE filled  gamma 0x16d2c6a78 beta 0x16d2c6a68 ...
    >   REF-CASE filled  gamma 0x16fa02a78 beta 0x16fa02a68 ...
    1250c1250
    <   REF-CASE put prints array 0x16d2c6a68: 16 16 16
    >   REF-CASE put prints array 0x16fa02a68: 16 16 16

No case value differs. So the scorer's 90 elements are not missing anything, and the two files being
distinct by md5 is not evidence of distinct arithmetic: **gamma's order and the fused products give
bit-identical forward output**, which is stronger than the equal scores and is the same class of ASLR noise
that made three identical host samples hash three ways, now on the port side.

**So `batch-normalization-forward` is a named question, not a search:** the host forms the value in a way
none of the three knobs reaches, and finding it needs a different probe - what the host does to the value
*before* the root - rather than another variant of the last operation.
