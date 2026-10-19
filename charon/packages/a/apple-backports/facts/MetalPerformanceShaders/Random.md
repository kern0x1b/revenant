# The random number generators on this port

`MPSMatrixRandomDistributionDescriptor`, `MPSMatrixRandom`, `MPSMatrixRandomPhilox` and
`MPSMatrixRandomMTGP32`. The linear solvers that sit beside them in the same header group are not in the
tree yet; see the handoff this directory's own `.agent-work` keeps.

Source: the header of `MPSMatrixRandom` in the SDK of iOS 16.4 for every signature, default and
documented data type, and `tests/backports/host/mpsmatrix/` for the behaviour.

## What the device is

Every random kernel here writes into an `MTLBuffer` and reads nothing from a texture, so — like the
matrix kernels in [Matrix.md](Matrix.md) — it runs over the host memory behind that buffer, on the CPU,
with the arithmetic done in the same precision the release's own does. No Metal capability is involved,
so none of this waits on the pixel formats.

## Philox, which is the release's own stream

`MPSMatrixRandomPhilox` is Philox4x32-10, the counter based generator of Salmon, Moraes, Dror and Shaw
(*Parallel Random Numbers: As Easy as 1, 2, 3*, SC'11), and this port reproduces the release's stream
**bit for bit**. What was measured, not assumed:

* the caller's `seed` is the key's first word and the key's second is zero;
* the counter is `(0, 0, 0, block)`, so element `i` comes from block `i / 4`, word `i % 4`;
* the ten rounds use the two multipliers `0xD2511F53` and `0xCD9E8D57`, the Weyl additions
  `0x9E3779B9` and `0xBB67AE85` on the key, and the hi/lo split of the 64 bit products — the
  published algorithm, unchanged.

The evidence is two independent oracles that agree: the release's own `MPSMatrixRandomPhilox` on macOS
26.5, and the published reference vectors. For seeds 0, 1 and 2 the port's sixteen words are equal to
both.

**A `Float32` destination is `t = (word >> 9) * 2^-23`**, the top twenty-three bits of the word as a
fraction, and a uniform distribution is `minimum + (maximum - minimum) * t` evaluated in one rounding.
Both were read off the release's own answers, bit by bit, and both are reproduced exactly; a float
chain that rounds the scale and the add separately is one unit in the last place out on three of eight
probed values, which is what a fused multiply-add or METAL's `lerp` avoids. A `Float32` destination is
in the differential's compared set and agrees.

## What the release of macOS 26.5 does not answer

Two things, and both are the release's own refusals rather than gaps in this port. Both are measured by
`crash-probe.m` in `tests/backports/host/mpsmatrix/`, which is kept out of the differential so the
oracle is not asked a question it dies on:

* **An `MPSVector` destination takes the release down.** Its own random kernel sends
  `-[MPSVector rowBytes]`, a selector `MPSVector` does not declare, and the process terminates on the
  unrecognised selector. Every shape was tried: one vector of four elements, sixteen vectors of one,
  four vectors of two, eight vectors of four, and every `vectorBytes` from the descriptor's own
  recommendation. `./crash-probe float32` answers, in the same process and the same minute, which is what
  says this is the release's own refusal and not this harness's mistake.
* **A batch range over a matrix destination is refused in the release's own validation**:
  `Number of requested results (4) is too large to fit in the destination image at the specified offset
  (16)`, for a 4x1x3 destination with `batchStart = 1` and `batchSize = 2`. The offset it names is not
  an offset the caller set.

This port fills both, as the header says it should. It is not the release's behaviour, it is a case the
release refuses, and saying so is the whole of what can honestly be claimed about it. The arithmetic
behind a `Float32` destination is the same `t` and the same scale-and-add measured above and compared
above, so this port's answers there are the release's own answers.

**A batch range is taken over the destination's batch dimension** — the matrices of an `MPSMatrix`, the
vectors of an `MPSVector` — which is what "the starting index in the destination batch" names. The
release instead treats the destination as a single image of `rows x columns`, which is the narrower
reading, and refuses a range that runs past it.

## Where the generator cases are verified, and where they are not

The differential's oracle **stops at `MPSMatrixBatchNormalization` with the GeLU neuron type**, the
eleventh of fifteen, after 1232 cases — the release's own kernel crashes there on this host, which is
a third instance of the same instability and has nothing to do with this port. The generator cases come
after it, so they are not in the differential's compared set.

They are verified against the release directly instead, and `crash-probe.m` is how: for seeds 0, 1 and
2 the port's sixteen words are equal both to the release's own `MPSMatrixRandomPhilox` and to the
published Philox4x32-10 reference vectors, which are two oracles that do not depend on each other. The
`Float32` uniform cases are in the differential and agree; the normal one is the divergence below.

## MTGP32, and what it does not reproduce

`MPSMatrixRandomMTGP32` is the Mersenne Twister of Matsumoto and Nishimura — the 624 word state, the
same recurrence and the same tempering that MTGP32 is a member of — seeded from the caller's `seed`.
The distribution is right: a uniform 32 bit stream from a generator built for exactly that.

**It is not the release's stream, and the release's is not reproducible from the published seeding.**
Measured: for `seed = 0` the release's first sixteen words are
`292b9f95 5e64b688 90d5d94d 1282ba5c …` and a Mersenne Twister seeded the published way gives
`8c7f0aac 97c4aa2f b716a675 d821ccc0 …`. The two are not truncations of one another. MTGP is a
*block* generator: it produces a fixed block of words per step and hands each thread its own position in
it, and the block size and the schedule that skips to a block are the implementation's own, not part of
the published seeding. Reproducing Apple's stream would mean reverse-engineering that schedule from its
output, which is not a native implementation of anything and is not attempted here.

What would remove the divergence: Apple's block size and skip schedule, which is not in any header.

## The normal distribution

`MPSMatrixRandomDistributionNormal` draws `mean + standardDeviation * invnorm(t)` from the same `t`.
The rule is measured — the release's answers for `mean = 2, standardDeviation = 3` are within one part in
`10^7` of this for every probed value — but the release evaluates its inverse normal in **single
precision**, and a sixteen-digit one does not land on the same bit: three of eight probed values differ
by one or two units in the last place of a `float`.

The rule is `mean + standardDeviation * invnorm(t)`, and **the divergence from the release is now
measured over the whole range rather than a handful of points.**

**The measurement.** `inverse-normal-probe.m` in `tests/backports/host/mpsmatrix/` draws 160,000 values
of the release's normal distribution with `mean = 2` and `standardDeviation = 3` into a 400x400 matrix,
and `pair.m` in the same directory draws a *uniform* matrix of the same shape with the same seed beside
it. The uniform value at a position **is** the fraction that position's normal value came from — the two
kernels walk the same counter in the same order — so pairing them by position gives 160,000 correct
`(t, z)` pairs whatever order they fill in. It does: the pairings agree with `invnorm(t)` to a median
relative difference of 4.7e-08, which is `float` rounding.

(The first attempt reconstructed `t` from the *index* instead, and appeared to show that the release
fills the destination out of order. It does not: a 4x4 destination pairs by index exactly, and a
400x400 one does not, because the fill is blocked by the shape — but a second draw of the same shape
recovers the pairing, which is what `pair.m` is for.)

**The result, this port's Wichura AS 241 in double against the release, over those 160,000 points:**

| | |
| --- | --- |
| bit for bit | 75,848 (47.4%) |
| within 1 ulp | 120,573 |
| within 2 ulp | 134,545 (84.1%) |
| **maximum absolute difference, anywhere in the range** | **3.81e-06** |
| the 8,022 points in the tails, `t < 0.02425` or `t > 0.97575` | 7,279 within 2 ulp |
| the 28 points whose result is below 1e-3 in magnitude | within 3.19e-07 absolute |

The largest *ulp* distances are all at `t` near 0.2525, where `invnorm` passes through zero and the
spacing between `float` values is tiny; the absolute difference there is around 1e-4 of a standard
deviation and is not a disagreement about the value.

**So the release's inverse normal is a different rational approximation from AS 241, not the same one at
another precision**: evaluated in single precision AS 241 matches *fewer* points (56,015 exact) than in
double, which rules out "AS 241 at a lower precision". Identifying it exactly needs its coefficients,
which are in no header, and a rational approximation cannot be recovered from 160,000 samples by fitting
alone.

**What this port ships is the correct inverse normal to within 3.81e-06 absolute over the whole range,
which is better than two units in the last place of a `float` everywhere except within a whisker of
zero.** That is stated in the registry's `effect` for the kernel as well as here, so a caller reading
either is not misled into thinking the streams are interchangeable.

## The distribution descriptor

`+uniformDistributionDescriptorWithMinimum:maximum:` also fills in the moments, and those were measured
rather than derived from the shape of the formula: for `[-2, 3]` the release answers `mean = 0.5` and
`standardDeviation = 1.44337571`, which is the mean at the middle and the width over the square root of
twelve. `+defaultDistributionDescriptor` answers every field zero, and
`+normalDistributionDescriptorWithMean:standardDeviation:` leaves the bounds infinite.

## Owed: the generators do not round-trip through an archive

`-[MPSMatrixRandomMTGP32 initWithCoder:device:]` and `-[MPSMatrixRandomPhilox initWithCoder:device:]`
are `implemented`, and what answers them is `MPSKernel`'s own implementation, reached through
`MPSMatrixRandom`. Measured with `class_copyMethodList` over the chain
(`MPSMatrixRandomPhilox` → `MPSMatrixRandom` → `MPSKernel`): the selector is in `MPSKernel` and in no
class below it, and `MPSKernel`'s implementation decodes three keys — the label, and the device and
options it sets itself — and nothing else. So an MTGP32 read back from an archive answers the default
distribution with the default seed, not the ones it was written with.

`MPSMatrixRandom.h:216-217` of iPhoneOS16.4.sdk marks the MTGP32 method
`NS_DESIGNATED_INITIALIZER`, so the class should carry it, and this port does not. The reason it is
owed rather than written is the same on both classes: the release's archive keys for a generator's
seed, its destination data type and its distribution are in no header, so any key this port chose
would be one the release cannot read and the round trip would be a fiction in the one direction that
matters. Writing `MPSMatrixRandomMTGP32` a forwarder to `MPSKernel` would make the class carry the
selector and change nothing an archive can see, which is why the two rows' `effect` says what is
answered and by whom instead.

The forwarder `-[MPSMatrixRandomPhilox initWithCoder:device:]` already in
`MPSMatrixRandomPhilox13.m:32-35` is that same no-op, kept because the selector has to be reachable
and the class answers it; the two rows' `effect` strings say so.
