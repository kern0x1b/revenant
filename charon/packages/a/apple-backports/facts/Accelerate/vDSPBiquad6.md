# The single-section biquad of vDSP, iOS 6.0 - in progress, and not carried

`vDSP_biquad`, `vDSP_biquadD`, `vDSP_biquad_CreateSetup`, `_CreateSetupD`, `_DestroySetup`, `_DestroySetupD`
in `Accelerate/vDSPBiquad6.m`, measured against the host's own vDSP in `tests/backports/host/vdspbiquad6`.

**None of the six is in the registry, and the page says exactly why.** The kernel implements the header's
printed pseudocode in the caller's precision and is held against the host on everything the host's answer is
a function of - the delay's layout, each coefficient's slot, its sign and its width, the refusals, the setup
lifecycle - and `sh tests/backports/host/vdspbiquad6/run.sh` is green at `11 checks, 0 failures`. What it
cannot be held on is the value of a whole run: **the host's answer is not a function of its inputs**, which
is measured below and is why the six rows wait for the 6.1.3 armv7 release rather than for a tolerance.

## What the host's answer depends on, and this is the finding

`alignment_survey` in the differential hands the host the same coefficients, the same input and a zero
delay on every pass and moves only where in memory the caller's three buffers sit, in steps of one float.
Measured, on the stable filter over 32 samples:

```
   the host's float answer takes 13 distinct values over the 16 offsets, moving by at most 20 ULPs
   the host's double answer takes 9 distinct values over the same offsets, moving by at most 5 ULPs
   the port's answer is the same at every offset, in float and in double
```

and the same shape on the unstable filter. **Thirteen different answers to the same question.** There is no
one value here for a port to be equal to, so a bit-exact comparison against this host has no expectation to
name - not because the port is wrong, and not because the arithmetic is unknown, but because there is
nothing on the other side of the equals sign.

That is why the four stable cases are recorded rather than gating, and it is a weakening of what this
differential gates and it is said here rather than dressed up. What still gates is the port's own half of
the same statement - its answer does not move with the offset - plus the delay layout, the coefficient
widths, the refusals and the setup lifecycle, which is what the four demoted cases could not see anyway:
with a whole filter running every term is non-zero, so a swapped pair or a wrong sign showed only as the
same few ULPs the host itself moves.

Corroboration, from outside the tree and not needed by it: the host's answer also moves with the **build of
the caller**. One probe source compiled at `-O0` and at `-O1` and calling `vDSP_biquad` identically gets
`0xbe0f24e3` at sample 2 of the stable filter under `-O0` and `0xbe0f24e4` under `-O1`, and every optimisation
level from `-O1` up agrees with `-O1`. Nothing in the caller changed but the flags.

## The search, and the defect that had been hiding in it

`brute_report` enumerates every binary tree over the five labelled leaves the header's recurrence prints -
**1680 of them, plus the printed form seeded in front of them as variant 0** - and for each one every way of
combining its four internal nodes into a plain add or a fused multiply-add, which is 26896 variants, each run
as a whole 32-sample recurrence with its own answer fed back as the next sample's state.

**It was not enumerating anything.** When a bipartition put leaves on both sides, the right subtree's nodes
were copied to their new offsets but their references *into their own array* were not moved with them, so
every tree that spans a split reads the left half a second time. On the stable filter's own coefficients the
unfixed file printed

```
    CONTROL 2 FAILED: 39936 variants do not give b0 * x[0] at sample 0 with a zero delay
```

and with the two lines that move those references it prints

```
    control 2 passed: all 26896 variants give b0 * x[0] at sample 0 with a zero delay
```

**The expectation was right the whole time**, which is the correction this page owes the reader of the
previous version: `fma(m, 0, a)` is exactly `a` and `a + 0` is exactly `a`, so a fused node reduces to
`b0 * x[0]` exactly as a plain one does, and no variant of this space can fail that check. The 39936 were
broken trees, not a wrong expectation. (One figure in the commit message that carried this fix says "39936 of
the 54272 variants"; the 54272 came from a separate copy of the enumerator and the differential's own array
was the smaller of the two, so the count to quote is the 39936 the file printed and the zero it prints now.)

The enumeration also visited one bipartition out of each complementary pair, which throws away half the fused
space, and sized its array for 14 trees while building 1680. **The page's earlier claim of "105 binary trees
over five labelled leaves" is withdrawn**: 7!! = 105 counts the associations of five labelled terms up to
commutativity, which is not what this code does, and the code builds 1680.

Control 1 asked whether variant 0 reproduces the port, which holds on a build with contraction off and cannot
hold on one with it - the port's own association is a property of the flags. It now asks the whole space and
prints what it found:

```
    control 1 passed: variant 12 of the space reproduces the port bit for bit (tree 903, and the
      combines fma(t4, +(t3, fma(t1, +(t0, t2)))))
```

with `FPC=off`, variant 0 - the printed form, left to right and unfused. **That is the measurement of the
port's arithmetic**, and it is a comment in `vDSPBiquad6.m` that used to claim the expression was "the one
measured against the host bit for bit"; the claim was never checked and is withdrawn.

**No variant reproduces the host over a whole run**, and the one that survives longest is the printed form
left to right and unfused, which first differs at sample 3 of 32 on the stable filter and sample 8 on the
unstable one. Given the thirteen answers above, that is what a non-deterministic oracle looks like from the
other side, and it is why this page does not name an association for the host.

## The delay layout and the coefficient widths, measured one term at a time

The header's pseudocode says `Delay[2s]` holds `x[s][N-2]`, `Delay[2s+1]` holds `x[s][N-1]` and a section's
own `y[n-1]`, `y[n-2]` sit one row on. A header is not a measurement, and this differential could not check
it, so `delay_layout` asks it directly: one coefficient at a time, one delay slot at a time, each slot its own
number. Measured, and both sides agree on every cell in both precisions:

```
     coef\slot D[0]=2      D[1]=3      D[2]=5      D[3]=7
     b0 * x             1           1           1           1
     b1                 0           3           0           0
     b2                 2           0           0           0
     a1                 0           0           0          -7
     a2                 0           0          -5           0
```

Two samples, not one: the port answers nothing for a call of a single sample - its own `N < 2` rule, which
the section below records as measured against the release - while this host does write `y[0]` for one, so a
one-sample call is not a case the two can be compared on at all. And a delay buffer per call, because both
forms write `Delay` back and handing the host's own buffer to the port measures what the host left in it.

The grid runs again with the caller's own doubles, and each cell where the coefficient lands is compared with
the product this program computes for it. **The host narrows every coefficient to float in the float form**
- its `b0` is `0.0674551204` where the caller sent `0.0674551234` - **and does not in the double form**,
which reads `0.0674551234`. Both grids are in the run's log.

## The kernel

The port is the header's printed form, left to right in the caller's type, with the state in the caller's
`Delay` and no working rows: one register per section for the current sample, shifted into the caller's
buffer once the whole sample has run. Two things in the pseudocode are easy to get wrong and both were, in
this file's own history: the inclusive row count, and the fact that a cascade's delay pairs must be shifted
**after** the whole sample - updating each pair inside the section loop hands section 2 section 1's value
*at n* where it needs section 1's value *at n-1*.

**The kernel is not changed to chase this host.** It is the header's own recurrence in the caller's
precision, which is what an armv7 target without a fused multiply-add computes, and that is the
implementation these rows exist for; a chain chosen from a macOS arm64 host's answers would be a worse fit to
it, not a better one.

## What is measured and stands, and is not re-measured here

**The ladder puts all six at 6.0** - inherited from the earlier pass, which ran `release-split.lua` over the
object from the real caches:

```
vDSPBiquad6.o  _vDSP_biquad  6.0      _vDSP_biquad_CreateSetup   6.0
vDSPBiquad6.o  _vDSP_biquadD 6.0      _vDSP_biquad_CreateSetupD  6.0
vDSPBiquad6.o  _vDSP_biquad_DestroySetup  6.0   _vDSP_biquad_DestroySetupD  6.0
release-split: clean, every object file's symbols first-appear in one release (23 files, 177 symbols, 50 releases)
```

So 4.3 does not have them, the file is needed, and the rows carry `minimum: 4.3` - the convention every one of
the 171 implemented Accelerate rows follows, whatever its `introduced`. **The 4.3 build exports all six**,
measured then with `nm -gU` on the gate's `libAccelerateBackports.dylib`, whose 177 exports are exactly the
object set's 177 symbols.

**The delay buffer is 2(M+1) elements, not 2M.** The pseudocode's loop is `for (s = 0; s <= S; ++s)` -
*inclusive* - so M sections are M+1 rows of two. A first version of the differential passed a one-element
`float` delay and the host wrote 2M floats straight over the test's own `sections`, which is what produced a
`SIGSEGV` and a run with no summary line. The `<=` is the whole of that difference.

**A cascade of no sections is a setup, not a refusal, on both creates.** Asked of the host:
`vDSP_biquad_CreateSetup(coeffs, 0)`, `vDSP_biquad_CreateSetupD(coeffs, 0)` and
`vDSP_biquadm_CreateSetup(coeffs, 0, 1)` each answer a setup, and so does the m-form at one section and no
channels. `CharonBiquadCreate` already agrees - it refuses only on no coefficients or an overflow - so the
shared create needed no change and the gated `vDSP_biquadm*` rows are untouched.

**The port's saved `Delay` matches the host's own dump** on the layout, which the grid above now pins term by
term rather than by inference:

```
    Delay after the call, the host: 1.25 0.25 0.465946406 0.488799572
    Delay after the call, the port: 1.25 0.25 0.465946376 0.488799483
```

The input's last two samples are `1.25 0.25`, so `Delay[2s] = x[s][N-2]` and `Delay[2s+1] = x[s][N-1]` - the
header is right. **A claim in an earlier version of this page said the host's layout was the opposite, and it
was wrong**: it was read off a probe whose own indexing was broken, and the host's dumped `Delay` disproves
it, as the grid above does now on both sides and both precisions.

## N = 1 answers 0, on the target

**A call of one sample writes nothing, and the release and the port agree bit for bit** that both answers are
`0x0000000000000000` - measured on the 6.1.3 armv7 guest with `b0 * x[0]` by hand at `-0.0674551204` beside
it. A single-section biquad has no history without two samples, so there is nothing to carry from a
one-sample call, and the release does not invent a state for it. The port gets this right from an `__N < 2`
early return that was written as a guard, not as a rule, and it happens to be the rule.

**This host does not share it**: measured above, `vDSP_biquad` writes `y[0]` for a one-sample call, and the
port writes nothing. So a one-sample call is a case the two sides answer differently by construction, and the
differential's own layout case uses two samples for that reason rather than by preference.

## The oracle, and the open item

**This host is the macOS arm64 vDSP, and it is not what these rows must match.** They are native on 6.0
armv7, and that is the implementation a 4.3-5.x application calls. armv7 VFP before VFPv4 has no fused
multiply-add, so an answer only a fused combine can produce is one the real target cannot give - and this
macOS host has one. On top of that, and measured above, this host's answer is not a function of its inputs.
Until the 6.0 armv7 implementation is run through the emulator, this shape cannot be gated bit-exact. **That
emulator run is now done** - and its answer is below.

## The guest run, and the verdict that carries the three float rows

`sh tests/backports/device/vdsp-probe/run.sh`, through `heavy.sh`, on the emulated **iPhone3,1 6.1.3
(10B329)** guest. The image is checked against the binary before the run, by LC_UUID, and both were
`934B806B-7089-3CD0-A36C-D89E94774EDF`:

```
    the two carry the same LC_UUID, so the image holds this build
    HASHES MATCH
    probe: minimum = Version 6.1.3 (Build 10B329)
    ok the stable filter, 1 sections, stride 1, call 0 - the samples, bit for bit
    ok the stable filter, 1 sections, call 0 - the Delay the call left behind, bit for bit
    ... 20 float cases (one and four sections, a strided one, two calls each on one setup),
        8 double cases, a NaN and signed zeroes by bit pattern
    the port differs from the release at 0 of 32 samples, by at most 0 ULP
    probe: 35 checks, 0 failures
```

**The float form is the release's, bit for bit, on this guest, and the association is the printed one.** The
search over 1681 trees and 26896 combine choices answers **variant 0**, `(((t0 + t1) + t2) + t3) + t4`, the
left-to-right unfused form, and reports 0 of 32 samples differing at 0 ULP on both the well-conditioned and
the amplifying filter. So the earlier finding - that the release's float answer differed by one ULP - was an
artefact of the probe's comparison, and the three float rows' `inert` reason ("the release's float answer
differs from the port's by 1 ULP, and the cause is being measured on the guest") is withdrawn.

And note what the guest settled about the comment at the top of this section: on armv7 **with NEON** the
machine is VFPv3 and has `VFMA.f32`, so a fused answer was never impossible here - but the association the
release actually computes is the unfused printed form, which is the one the port writes.

### The ten red cases were the comparison, and the fix is at the cause

An earlier run of this same probe reported ten failures, all of the float `the samples, bit for bit` case.
`run_float` declares `host_y[SAMPLES * 4]` because the strided case reads four times as far into `x`, calls
each side with `N = 32`, and compared `sizeof host_y` - 128 floats. Ninety-six per side were never written,
they are uninitialised stack, and they differ between the two arrays. What said so, at the time:

- every comparison sized exactly to what the call writes passed, including all ten Delay comparisons;
- the search's own per-sample comparison over exactly the 32 written samples reported 0 of 32 differing.

The probe now zeroes both answers before every call, compares `SAMPLES * sizeof(float)`, and `report` prints
the first differing index **in elements** with both values at it, always - it printed a byte only when the two
sides were the same length and at most 64 bytes, which for two 512-byte arrays meant it could not say where
anything was.

**The red control** is `VDSPPROBE_PLANT_ULP=<n>`: it moves the port's float answer at sample `n` by one unit
in the last place, after the call and before the comparison, so the float case has to go red and name that
index. It is the comparison's sensitivity and not the port's arithmetic - the bytes the port wrote are
untouched and the plant moves them in the probe's own copy. Measured on this Mac:

```
    $ VDSPPROBE_PLANT_ULP=7 .agent-work/runs/probe-host2/probe
    probe: the red control's plant is on: sample 7 of the port's float answer is moved by one ULP before it is compared
    FAIL the stable filter, 1 sections, stride 1, call 0 - the samples, bit for bit
         first differs at index 7: the release 0x3efa43ed, the port 0x3efa43ee
         the red control's plant moved the port's sample 7 by one ULP before this comparison
```

and the same index named on every float case, exit 1; unplanted, the same binary is `35 checks, 0 failures`.

## The band's floor, measured on the object

`vDSPBiquad6.m` compiled at `armv7-apple-ios4.3` has four undefined symbols and no others:

```
    _calloc _free _malloc _memcpy
```

All four are libSystem's, and each is read out of that release's own armv7 export trie with
`tools/image-exports.lua`: `_malloc` and `_calloc` in `/usr/lib/libSystem.B.dylib`'s 4155 exports, `_memcpy`
and `_free` in the same image. No import the 4.3 release lacks, and nothing from a later SDK.

## How to run this

```
sh tests/backports/host/vdspbiquad6/run.sh              # the differential
SAN=1 sh tests/backports/host/vdspbiquad6/run.sh        # the same, under AddressSanitizer
FPC=off sh tests/backports/host/vdspbiquad6/run.sh      # the same, with contraction off on both sides
```

`SAN=1` and `FPC=off` are in `run.sh`'s own flags on purpose: the renamed `_charon_host_*` objects have to be
built the way the plain run builds them, or the comparison is between two different builds. An ad-hoc command
that renames differently builds different objects and says nothing - which cost this shape a day.

`FPC=off` is now also the run that shows the port's own arithmetic most plainly: variant 0 is the printed
form there, so the search's control 1 names it without having to read a fused chain.