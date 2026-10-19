# The elementwise vDSP of Accelerate, iOS 7.0 and 8.0

Fifty-four functions of the corpus's vDSP rows arrived after iOS 6.1, and they fall in four groups by the release that
first exports them. This file is the first two groups and the elementwise half of each: the 24-bit conversions, the integer
add and the single-precision complex products of 7.0, and the sums, the ramps, the sliding window maxima, the dot products
and the double-precision complex products of 8.0. The rest of 7.0 is the multiple-biquad filter and the double-precision
DFT; 9.3 and 16.0 are that filter's own coefficient, target and active-filter setters.

Measured from the release's own armv7 caches, and the release is what each file answers to:

| first held release | names | file |
| --- | --- | --- |
| 7.0 | `vDSP_vaddi`, `vDSP_vflt24`, `vDSP_vfltu24`, `vDSP_vfltsm24`, `vDSP_vfltsmu24`, `vDSP_vsmfix24`, `vDSP_vsmfixu24`, `vDSP_zvma`, `vDSP_zvmmaa` | `Accelerate/vDSPFixed7.m` |
| 8.0 | `vDSP_vaddsub`, `vDSP_vaddsubD`, `vDSP_vrampmulD`, `vDSP_vrampmul2D`, `vDSP_vrampmuladdD`, `vDSP_vrampmuladd2D`, `vDSP_vswmax`, `vDSP_vswmaxD`, `vDSP_vsmsmaD`, `vDSP_dotpr2D`, `vDSP_distancesqD`, `vDSP_zvmaD`, `vDSP_zvmmaaD` | `Accelerate/vDSPElementwise8.m` |

4.3, 5.1.1, 6.0 and 6.1.3 name none of the twenty-two and 7.1.2 names only the nine of 7.0, which is why the two files
hold one release each and why both are carried from 4.3 on.

Source: the host's own vDSP, held against the port case by case by `tests/backports/host/vdsp` — 59 checks, every element
both sides wrote compared — and the header of iOS 16.4 for the declarations.

## Nothing is built beside the release's vDSP

The release carries the whole of vDSP from 4.0 and 415 vDSP entry points by 6.1.3 (measured from its Accelerate image).
These twenty-two are the ones later releases added, and they are arithmetic over the release's own types: a 24-bit value is
`struct { uint8_t bytes[3]; }`, a split complex is two pointers, a stride is a `long`. So there is no vector library here,
only the twenty-two functions the release does not have.

The two split-complex products exist in one precision in 7.0 and in the other in 8.0, and they are one body written once
and generated per scalar type in `Accelerate/CharonVDSPKernel.c`, so the two precisions and the two releases cannot drift
apart. That file exports nothing: the names a caller reaches are the twenty-two above, and a name beginning with `charon_`
is the port's own and is not weighed against a release (modules/apple/backports.lua, `internal_symbol`).

## The twenty-two, each against the header's own formula

Every one of the twenty-two entry points in this group was read against the map block vDSP.h prints under its
declaration, formula by formula, and the port now answers all twenty-two of them. One did not, and the audit is
what found it: `vDSP_vsmsmaD` had `C[n] * D[n]` where the map block says `C[n] * D[0]`. The other stride-less
parameter in the group, `B` in the four 24-bit scaling forms, is read at `[0]` in all four, and the ramps, the add
and subtract, the sliding window, the two dot products, the distance and the four split-complex products agree
with their map blocks as they stand.

Two comments in Apple's own header are transposed, which is worth knowing before the next reader trusts one of
them: the block above `vDSP_vsmfix24` says "24-bit **unsigned** integer" and the one above `vDSP_vsmfixu24` says
"24-bit integer", while the declarations say `vDSP_int24 *C` and `vDSP_uint24 *C` respectively. The declarations
are the API and the host agrees with them (measured: `vDSP_vsmfix24` clamps to [-8388608, 8388607] and
`vDSP_vsmfixu24` to [0, 16777215]), so the port follows the declarations and the two comment blocks are each one
function out of step - the same offset-by-one that the ramps' `*Start` and `vDSP_vaddsub`'s second output sit in.

## What was measured

**The 24-bit readers.** A value is three bytes least significant first. The signed reader sign-extends from bit 23 and the
unsigned one does not: `vDSP_vflt24` of 0, 1, -1, 8388607, -8388608 and -12345 answers those six, and `vDSP_vfltu24` of the
same six as unsigned answers 0, 1, 8388607, 8388608, 16777215 and 12345. Measured with a stride of two on the input and on
the output as well.

**The scaling forms take a scalar, not a vector.** `vDSP_vfltsm24` and `vDSP_vfltsmu24` have no stride for B, so `B[0]` is
the whole of it: `C[n] = B[0] * (float)A[n]`. With a scale of 2 over the six signed values the host answers
0 2 -2 16777214 -16777216 -24690; over the six unsigned values, 0 2 16777214 16777216 33554430 24690. With a scale of -1
over the unsigned range the host answers -0 -1 -8388607 -8388608 -16777215 -12345, so the scale is applied as it stands
and nothing is clamped. With a scale of 0 over a negative value the answer is -0, so the multiply is the answer and not an
assignment of a positive zero.

**The two clamps.** `vDSP_vsmfix24` is `C[n] = trunc(A[n] * B[0])` clamped to [-8388608, 8388607], and `vDSP_vsmfixu24` the
same clamped to [0, 16777215]. With a scale of 8388608 over 1, -1, 0.5, -0.5, 2/3 and 100 the signed reader answers
8388607 -8388608 4194304 -4194304 5592405 8388607: a positive overflow stops at 8388607, a negative one reaches
-8388608 exactly, and 2/3 truncates down. The unsigned reader over the same six answers 8388608 0 4194304 0 5592405
16777215, so a negative result becomes 0 rather than wrapping. Negative inputs at a scale of one are in the differential for
both.

**`vDSP_vaddi`** is `C[n] = A[n] + B[n]` with a stride for each of the three; measured over 1 -2 3 -4 5 -6 and
10 20 -30 40 -50 60 it answers 11 18 -27 36 -45 54, and with a stride of two on the first, 11 23 -25.

**`vDSP_vaddsub`'s second output is the second operand minus the first.** Over [1..6] and [0.5,-0.5,1,-1,2,-2] the host
answers 1.5 1.5 4 3 7 4 and **-0.5** -2.5 -2 -5 -3 -8, and -0.5 is 0.5 - 1. `vDSP_vaddsubD` over [1,2,3,4] and
[0.25,-0.25,0.5,-0.5] answers 1.25 1.75 3.5 3.5 and -0.75 -2.25 -2.5 -4.5, which is the same. The name reads either way and
the measurement decides.

**The ramps leave the start at the end of the ramp, not at the last value they used.** Over [1..5] with a start of 1 and a
step of 2, `vDSP_vrampmulD` answers 1 6 15 28 45 and leaves `*Start` at **11**, which is 1 + 5*2 and not 9. The two-output
form walks one ramp across two inputs and leaves the start the same way; measured with the same vector in both inputs it
answers 10 15 24 37 54 in both. The `add` forms accumulate into the buffer the caller named: into one already holding
1 6 15 28 45 with a start of 1 and a step of 2, `vDSP_vrampmuladdD` answers 2 12 30 56 90.

**`vDSP_vsmsmaD`'s B and D are both scalars.** Neither has a stride parameter, which is the header saying that
one element is the whole of it, and its own pseudocode prints `E[n] = A[n]*B[0] + C[n]*D[0]`. Measured with an
operand that tells the two readings apart: over A = [1,2,3,4], B = [2,7,7,7], C = [10,20,30,40] and
D = [0.5,99,99,99] the host answers **7 14 21 28**, which is A * 2 + C * 0.5. Reading either operand as a vector
would answer 7 16 27 40 for B and 7 1994 2991 3988 for D, and the one element each the header tells a caller to
pass would be read out of bounds - measured, the port's answer was -19753076 at element 1 where the host says 14.
A constant D cannot see this at all, which is why the differential uses a D that is not constant and a second
case with the one element the header prescribes. The single-precision `vDSP_vsmsma` of iOS 6.0 is on the
release already.

**The sliding window maximum runs forward from n.** `vDSP_vswmax`'s header says `C[n]` is the greatest of the
`WindowLength` elements of A that *begin* at n, and says what the buffers must hold: **A must contain N + WindowLength - 1
elements and C must have room for N + WindowLength - 1**, of which the first N are the answers, A and C may not overlap,
and the window must be positive. Measured over [3,1,4,1,5,9,2] with a window of 3 and nine elements — the nine the header
requires — the host answers 4 4 5 9 9 9 9; with a window of 1 it answers the input itself; with a window of 4 and N = 4 it
answers 4 5 9 9. A first measurement of this function with a seven-element buffer answered 4 4 5 9 9 9 and then read
uninitialised memory for the seventh element, which is the header's requirement and not a different window.

**`vDSP_dotpr2D`** is two dot products over one vector: over A0 = [1,2,3,4], A1 = [1,0,0,1] and B = [5,6,7,8] the host answers
70 and 13. **`vDSP_distancesqD`** is the sum of the squares of the differences: over [1,2,3] and [4,6,3] it answers 25, whose
differences are -3, -4 and 0.

**The split-complex products put the accumulator last.** `vDSP_zvma` of A = (1+5i), B = (2+0i) and C = (1+1i) answers
3 + 11i, which is `A*B + C` and neither `A + B*C` nor `A + C*B`. `vDSP_zvmmaa` of the six vectors of the differential answers
`A*B + C*D + E`: with A = (1+4i), B = (1+0i), C = (2+5i), D = (1+1i) and E = (10+40i) that is 8 + 51i, and
`A + B*C + D*E` would be -27 + 59i.

## What is reasoned rather than measured

`vDSP_vswmax` with a window of 0 is refused by nothing here: the header says a window must be positive and does not say
what a zero window answers, so the port's inner loop simply answers the first element of each window, which is what a window
of one answers and the nearest defined thing to a window of none. It is the only case in these twenty-two not posed to the
host, and the differential does not cover it.

## What has not been run

`tests/backports/device/vdsp.m` calls all twenty-two on the device against the answers above. **The run has not happened**:
the test is written and compiles for `armv7-apple-ios6.1.3` and `armv7-apple-ios4.3` against the SDK this port builds
with, and until it is run on an emulated 6.1.3 or on an iPad 2 every answer on this page is a host measurement and a
device-unverified one.
