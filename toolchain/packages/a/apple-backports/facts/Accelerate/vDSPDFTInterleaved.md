# vDSP_DFT_Interleaved: what is measured, and what is still not

Six rows at 15.0. This page records what was measured and **retracts the central claim of the port's commit**:
the "bit exact against the host" result was **the port compared with itself**, because the host does not have
these functions. See section 7.

## 0. The accepted-length set, exact, swept 1 to 1024 against the host

**31 of 1024 lengths are accepted, and the set is exactly `f * 2**n` with `f` in {2, 3, 5, 9, 15} and `n >= 2`:**

    8 12 16 20 24 32 36 40 48 60 64 72 80 96 120 128 144 160 192 240 256 288 320 384 480 512 576 640 768 960 1024

`vDSP_DFT_Interleaved_RealtoComplex` and `vDSP_DFT_Interleaved_ComplextoComplex` accept **the same set**, measured
over the whole sweep. And **the header's `5*5 = 25` is not implemented**: 25 itself is refused, and so are
25 * 2**2 = 100, 25 * 2**3 = 200, 25 * 2**4 = 400 and 25 * 2**5 = 800 - every one of which the header's list
admits. `3*5 = 15` is implemented, and 15 * 2**n appears throughout the accepted list.

So the refusal rule the port must use is **`f` in {2, 3, 5, 9, 15}, `n >= 2`**, and the header's list is right
about every factor except `5*5`. That is an exact, host-measured specification for `CreateSetup`, and it is the
first part of this family that needs no error bound at all.

## 1. The supported-length predicate, and where the header is wrong

The header says `Length = f * 2**n, where f is 2, 3, 5, 3*3, 3*5, or 5*5 and n >= 2`, and that zero is returned
if there is no implementation for the requested case. Measured over 1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16, 25, 27,
50, 100, 125, 128 and 0: **8, 12, 16 and 128 are accepted; every other length is NULL.** So the predicate holds
where the small lengths are concerned - 9 and 25 are refused because `n = 0 < 2` - **and it is wrong at 100**,
which is `25 * 2**2` and satisfies it exactly, and which the host refuses.

**So `CreateSetup` must refuse exactly the set the host refuses, measured over a sweep of 1 to 1024, and the
header's predicate is a starting point with at least one known exception rather than the rule.** Length 4, which
is `2 * 2**1` with `n = 1`, is refused - a useful control, since the coordinator's suggested 8-real-sample case
would have used it.

## 2. The inverse is unscaled, and the two directions do not reverse the index

Forward then inverse on `Length = 8`, a single unit bin at each k in turn: **every bin returns at exactly
`8.0` (`0x41000000`) from an input of `1.0`**, and the energy comes back to the *same* bin. So the factor is
the length and not its reciprocal - `1/8 = 0.125` would be the other reading - and there is no index reversal
between the directions.

## 3. The real-to-complex packing - SOLVED, and my check was the wrong part

**The packing is the documented one**, confirmed numerically over 64 random 16-sample real inputs:

    o[0] = (2*X_0, 2*X_8)     both real, by conjugate symmetry
    o[k] = 2*X_k              BOTH parts, for k = 1 .. Length-1

**My first check was wrong, and it was wrong in a way worth recording.** I computed the naive double DFT keeping
only the real part and wrote the imaginary part as zero, on the reasoning that a real input gives a real
spectrum. That holds only for `X_0` and `X_{N/2}`; every other `X_k` is complex. So the prediction was half
wrong - and **the real part matching to about one ULP was the part that was right**, which is what the packing
predicts, and I read it as the host being "close but not doing the real transform" instead of as confirmation.
The coordinator's reading of the same impulse sweep was the correct one: the DFT of an impulse IS a flat
spectrum, and `(2, 2)` and `(2, -2)` at k = 0 are DC and Nyquist packed.

With both parts carried, the imaginary part matches **exactly** and the real part differs by **1 ULP** - the
host's float against a double-precision reference, so the double is the more accurate side. **1 of 64 trials
match bit for bit**, and those are the ones where the float result happens to be exact. This is the same class
of one-ULP as the biquad's float, and it is the reason a bit-exact differential needs the host's own algorithm
rather than a naive float DFT.

## 4. The inverse's factor, measured and not assumed

Forward then inverse on a real signal, through the same packing: **the factor is 32 = 4 * Length**, read on the
positions the probe unpacks correctly. That is the forward's x2 times the inverse's unscaled 2*Length, which is
the coordinator's reading, and it is measured rather than assumed.

## 5. The error bound - and this is the specification, not a tolerance

`vDSP_DFT_Interleaved` is 15.0, **no guest here runs 15.0**, and the host's own FFT cannot be reached
bit-exactly - so for this one place in the band an error bound IS the specification rather than a tolerance,
and both the host and the port are held to the same constant.

    per element:   |out - ref| <= K * log2(N) * FLT_EPSILON * ||x||_2      with  K = 1.538

**K is taken once from the host's own worst case over the 31 accepted lengths**, 24 random real inputs each,
with `ref` a naive double-precision DFT of the `2 * Length` real samples and the packing of section 3. The
worst ratio over the whole sweep is **1.538, at Length 64 element 30** - and it is the *host's* ratio, so the
constant is not chosen to pass the port.

**Getting there found a real fault in the reference, not in the host.** The first attempt gave a worst ratio of
1.6e7 at Length 16 element 0, which is an implied absolute error of about 21 - far too large to be rounding, so
the reference was the broken side. Element 0 is the packed one holding `(2*X_0, 2*X_n)`, and its imaginary part
is the **Nyquist bin, which for a real input is the alternating sum**:

    X_n = sum over the 2*Length real samples of x[j] * (-1)^j      real, since e^(-pi*i*j) = (-1)^j

An earlier version took that term from the same accumulator that produced `X_0`. With it corrected the ratio
falls from 1.6e7 to 1.538, and **the same mistake was what made the host look wrong at element 0** in the
packing check a turn earlier.

**What the bound is for.** The exact parts of this family are the packing layout, the x2 and the 4*Length
factors, and the accepted-length set of section 0 - all reproduced exactly and needing no bound. Everything
else is the transform's arithmetic, and it is held to K. A mutant that puts a twiddle's sign wrong, drops the
x2, or swaps the packing breaks the bound by orders of magnitude rather than by an ULP, which is the test that
the bound is tight enough to be a specification.

## 6. The inverse's unpacking, as a formula, and the obstacle to the differential

**The 16x16 table of impulses gives the unpacking directly** - the inverse is linear, so an impulse in each of
the sixteen scalar inputs of the packed spectrum, read out as the sixteen real samples it produces, IS the
formula. Measured, with N = 8 and j the sample index:

    o[0].real  contributes  1        to every sample
    o[0].imag  contributes  (-1)^j
    o[k].real  contributes  2*cos(2*pi*k*j/(2N))     for k = 1 .. N-1
    o[k].imag  contributes -2*sin(2*pi*k*j/(2N))

Written out and checked on 64 random packed spectra against the bound: **the worst ratio is 0.851, inside
K = 1.538.** So the inverse is specified as well as the forward, and both are held to the bound.

**The obstacle, and it is the house's rename mechanism rather than anything in the rows.** The differential
renames the port's definitions so the port's and the host's can sit in one binary, by compiling the port with
`-DvDSP_DFT_Interleaved_CreateSetup=charon_host_vDSP_DFT_Interleaved_CreateSetup` and so on. **Those three
function names share a prefix with the opaque setup type `vDSP_DFT_Interleaved_Setup`**, and the preprocessor
substitution reaches the header's own declarations of the type, so vDSP.h stops compiling at the family's own
declarations. Every other family in this band renames cleanly because no function name is a prefix of a type
name it also declares.

So the differential needs a different mechanism here - renaming by an explicit per-file list that does not
substitute the type, or compiling the port with a macro rather than `-D` - and **that is not a decision I
should make quietly, because it changes how every subsequent differential in this band is built.** The port
itself compiles clean.

## 7. CORRECTION: the host IS the oracle, and the earlier probes stand

**A retraction in the previous commit was wrong and is withdrawn here.** It claimed the macOS SDK does not
carry this family and that the "bit exact" result was the port compared with itself. The family IS there -
`vDSP.h:7600` declares it and `vecLib.tbd` exports `_vDSP_DFT_Interleaved_Execute` - and the length sweep,
the impulse tables and K = 1.538 all came from the real release.

What actually happened: **the `-D` renames were applied to the differential's translation unit as well**, so
its host calls were renamed to `charon_host_*` too and both call sites reached the port. The port's object
must be compiled with the `-D` list and **the differential's must not**. With that, `nm` shows the two sides
distinct - `_vDSP_DFT_Interleaved_Execute` undefined and binding to Accelerate, `_charon_host_...` defined -
and the comparison is real.

**What the result actually is, corrected: the port is WITHIN the bound, not bit exact.** 17 checks, 0 failures,
worst ratios 0.820 and 1.401 at N = 32 against K = 1.538, over the four accepted lengths in both forms and
both directions and 64 inputs each. The 0.000 in the earlier commit was the tautology; the honest figure is a
ratio inside the bound, which is exactly what the bound is for. Five of six mutants go red by orders of
magnitude; the sixth, the length set, does not, and the gap is recorded in the mutants' README rather than
counted as a pass.

The single-precision rows were **inert** at the time of that paragraph, and section 8 says what changed since. The
mutant gap it names is not closed here.


## 8. The single-precision rows: held to the bound over every accepted length, and the fix that made them pass

The three single-precision rows (`vDSP_DFT_Interleaved_CreateSetup`, `_Execute`, `_DestroySetup`) are `implemented`.
The differential is `tests/backports/host/vdspdft15`: it compares which lengths each side accepts over 1 to 1024
(both forms, 31 lengths accepted by each side, 0 disagreements), and it holds both the host and the port to the
section 5 bound over the 31 accepted lengths, 8 trials each, in complex-to-complex forward and inverse and in
real-to-complex forward. The reference is a naive double-precision transform; the real-to-complex reference is the
packing of section 3.

    stage complex-to-complex forward: worst ratio to the bound: host 0.323, port 0.140   (K = 1.538)
    stage complex-to-complex inverse: worst ratio to the bound: host 0.320, port 0.131
    stage real-to-complex forward:    worst ratio to the bound: host 0.961, port 0.373
    checks=8 failures=0

**Section 5 measured only N up to 32, and the port's first version failed beyond that.** The port summed each
output in float, so its error grew with the number of terms. The differential found it: with the float sums, the
port was 2.17 times the bound in complex-to-complex forward, 2.08 in inverse and 4.61 in real-to-complex, with the
worst cases at N = 480 to 1024 (the host stayed at 0.32 to 0.96 at every length). The fix is in the port, not the
bound: the sums are in double, each element is rounded to float once, and the real-to-complex path keeps its
complex forward in double through the split, because a float Z would put one rounding into every bin. The
failing run is the control: the same differential, against the float version, is the red result above.

**Allocation.** Every buffer the transform needs is allocated by `CreateSetup` (the twiddle table, and for real-to-complex
the packed input and the complex forward) and freed by `DestroySetup`. `Execute` never allocates, so a failed allocation
cannot make it return without writing its output. A failed allocation in `CreateSetup` returns NULL, which is the setup
the header already gives for a refused length. The double-precision file is allocated the same way; its arithmetic was
then changed to compensated sums, measured in section 9.
The behaviour of the release on a failed allocation is not measured (see `coordination/crutches.md`).

**Caveats.** The 6.1.3 guest does not run 15.0, so the rows are `device-unverified` (COORDINATION section 5). The
differential's sweep is 31 lengths; the mutant gap section 7 names is still open. The double-precision rows are held to
the bound of section 9, over the same 31 lengths.

## 9. The double-precision rows: a double-double reference, a host-measured bound, and the port made to meet it

The three double-precision rows (`vDSP_DFT_Interleaved_CreateSetupD`, `_ExecuteD`, `_DestroySetupD`) are `implemented`.
Their differential is `tests/backports/host/vdspdftd15`.

**The reference is double-double, not double.** A double reference would measure itself: its own rounding is the size
of the error being held to. So the reference is computed in a pair of doubles (about 32 significant digits): products
by `fma`, sums by two-sum, and the twiddles `cos` and `sin` of `2*pi*m/M` from a Taylor series in double-double after an
exact reduction of the angle to a quadrant and an eighth. Its own check: `cos^2 + sin^2 = 1` to 1e-30 over every
twiddle of every accepted length, and agreement with libm to 4e-15, which is libm's own error on the argument.

**The bound.** The same form as section 5, with the double epsilon:

    per element:  |out - ref| <= K * log2(N) * DBL_EPSILON * ||x||_2      with K = 2.63

`K` is the host's own worst ratio over the 31 accepted lengths, 24 trials each, across the three stages (complex forward,
complex inverse, real-to-complex forward), which is 2.624, rounded up to 2.63. The host is held to it too.

    stage complex-to-complex forward:  worst ratio: host 0.467, port 0.382   (K = 2.63)
    stage complex-to-complex inverse:  worst ratio: host 0.551, port 0.305
    stage real-to-complex forward:     worst ratio: host 0.998, port 0.646
    checks=9 failures=0

**The port's first version did not meet it, and the fix is in the port.** A plain double sum over N terms has an error
that grows with N, as the single-precision version's did (section 8). Measured against the same reference, the plain
port's worst ratios were 2.83 (complex forward), 3.19 (complex inverse) and 8.32 (real-to-complex forward) with the
bound taken at K = 1. At K = 2.63 that is 1.08, 1.21 and 3.16: outside the bound in all three stages, which is the
control. The fix: each product is taken exactly by `fma`, and the sums are compensated (each addition's rounding error
is kept and added back), so the output is rounded to double once. The real-to-complex path takes its complex forward
through the same sums. The compensated port's worst ratios are 1.005, 0.801 and 1.700 with the bound taken at K = 1,
which is 0.382, 0.305 and 0.646 at K = 2.63 as reported above.

**Caveats.** Device-unverified: no 15.0 guest runs. The differential runs about two and a half minutes, because the
double-double reference is O(N^2) in extended arithmetic; its 24 trials are the sample K was measured from, and it is
not shortened, because a shorter sample would make K a different constant.

## 10. The answer on a failed allocation: measured on the host, and the port's answer

`tests/backports/host/vdspdft-alloc` interposes the allocators (`DYLD_INSERT_LIBRARIES`) and makes the k-th allocation
of one `CreateSetup` call fail. It numbers the host's allocations first (5 to 11 per call, most inside Accelerate's
own setup) and then fails each in turn. 192 rows: 3 lengths (8, 128, 1024) x single and double x complex and real
x forward and inverse, every failing call.

- **The setup's own allocation (call 1), in every case: NULL.** So is every allocation of the real-to-complex single
  precision setups, and the double complex-to-complex setups at every length.
- **Single-precision complex-to-complex at N = 128 and 1024: a working setup for calls 3 to 7.** The setup is returned
  and `Execute` gives output identical to the unfailed call's (measured on the earlier probe: maximum difference 0). The
  host's own allocation plan has buffers it can do without; the port's has none of those, so the port cannot match
  this block. At N = 8 the same calls give NULL.
- **Double real-to-complex: a non-NULL setup from the last allocation** (N = 8, call 8; N = 128 and 1024, call 9). At
  N = 256 that setup crashes in `Execute` (SIGSEGV, measured on the earlier probe). That is a defect of the host. The
  port does not copy it.

**The port's answer is NULL on every failure it hits**, checked by the same probe against the port's objects (run.sh
fails on any setup returned under a failure: 0 of them). The port does not match the host's survival block (above) and
does not copy its crash. So for allocation failures the port's answer is NULL, and the host's is NULL in most cases,
a working setup in one block, and a crashing setup in one place. Creation is probed here, not execution: a setup the
host returns under a failure is not executed by the probe.
