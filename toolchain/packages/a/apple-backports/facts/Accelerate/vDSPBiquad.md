# The multiple-biquad filter of vDSP, from iOS 7.0 to 16.0

Twenty entry points in five files, and every answer on this page is the host's own vDSP measured case by case by
`tests/backports/host/vdspbiquad` and recorded here: the port's five files and the host's `libvDSP` over the same inputs, comparing every
element either of them wrote. The release ladder is measured from the release's own armv7 caches, so each file holds the API of
exactly one release:

| file | rows | first release that exports them |
| --- | --- | --- |
| `Accelerate/vDSPBiquadm7.m` | 5 | iOS 7.0 (`_CreateSetup`, `_DestroySetup`, `vDSP_biquadm`, `_ResetState`, `_CopyState`) |
| `Accelerate/vDSPBiquadm8.m` | 5 | iOS 8.0 (the five in double) |
| `Accelerate/vDSPBiquadm9.m` | 5 | 10.3.4 (`_SetActiveFilters`, `_SetCoefficientsSingle`, `_SetCoefficientsDouble`, `_SetTargetsSingle`, `_SetTargetsDouble`) |
| `Accelerate/vDSPBiquadm16.m` | 5 | 16.0 (the same five in their 16.0 form) |
| `Accelerate/vDSPDFT7.m` | 4 | iOS 7.0 (`vDSP_DFT_zop_CreateSetupD`, `_zrop_CreateSetupD`, `_ExecuteD`, `_DestroySetupD`) |

vDSP.h publishes no layout for `struct vDSP_biquadm_SetupStruct` or its double twin, saying only that the contents may change from
release to release and that a caller should go through the setup and setter routines, so `Accelerate/CharonBiquad.h` defines both
and every caller only ever passes the pointer around.

## What the filter is

M sections over N channels, and the five numbers of a section are in the order **b0, b1, b2, a1, a2** - the order
`vDSP.h`'s own pseudocode uses - with the section the difference equation that pseudocode prints:
`y[n] = b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2]`. Measured: the coefficients `{0.1, 0.2, 0.3, 0.4, 0.5}` over an
impulse answer 0.1, 0.16, 0.186, -0.1544, and `{1, 0, 0, 0.5, 0}` answer 1, -0.5, 0.25, -0.125 (the sign on a1 is the minus).

**The caller's coefficients are section-major and channel-minor**: the block for section `s` and channel `c` begins at
`(s * N + c) * 5`. Measured with one section and two channels over the coefficients 1..10: channel 0 has a b0 of 1 and channel 1 a
b0 of 6.

**The order of a cascade does not matter, and saying so is the measurement.** A cascade of linear time-invariant sections
commutes, and the release's own API gives nothing to tell the order apart with: putting the `a1` on section 0 or on section 1
gives `1 -0.5 0.25 -0.125 0.0625` both times, and walking this port's cascade in reverse leaves the whole differential at 74 checks
and 0 failures. The port walks section 0 first, which is one of the two orders that answer the same.

**The delay is two doubles per section and channel**, which is the section in transposed direct form II - the two-value form that
carries the last two samples' input and output history, and which a direct-form reading of the header's pseudocode would need four
values for. An impulse on channel 0 of a one-section two-channel setup leaves channel 1 silent, and silent on the next call too, so
the delay is per section *and* channel and not shared.

**IX and IY are element strides.** Measured: an impulse at index 1 of an input read with a stride of two comes out at index 1, and a
length of 0 leaves the output alone.

## The setters

**`SetActiveFilters` takes one bool per section**, not per section and channel: two sections of one channel answer 2 with both active
and 1 with the second inactive, from an array of two. An inactive section is skipped whole - its input passes through and its delay
is left as it was (measured: a two-section setup with the second inactive answers a constant input as the input itself, and answers
the fresh response of that section when it is made active again). **The two precisions differ on one case**: with *every* section of
a two-section setup inactive and the input 1, 2, 3, 4, `vDSP_biquadm` answers 1, 2, 3, 4 and `vDSP_biquadmD` answers 0, 0, 0, 0.

**`SetCoefficients` takes a window of its own**, packed `nsec` by `nchn` - the five values of its (section, channel) begin at
`(section * nchn + channel) * 5` - and places it in the setup at `(start_sec, start_chn)`. A window of one section and one channel
cannot decide that, because with `nsec = nchn = 1` the two candidate strides are the same expression; what decides it is a window
with `nsec >= 2` and a setup whose own `N` differs from the window's `nchn`. Measured on the host over a 2-section 4-channel setup
of pure gains, where a channel's answer is the product of its two b0s:

| window | the host's per-channel products | what it fixes |
| --- | --- | --- |
| `(nsec=2, nchn=4)` at `(0,0)` | 12 21 32 45 | blocks 0..7, the window's own `nchn` as the stride |
| `(1, 4)` at `(0,0)` | 2 3 4 5 | section 1 alone, four blocks |
| `(2, 1)` at `(0,0)` | 6 1 1 1 | blocks 0 and 1, the channels after it untouched |
| `(2, 3)` at `(0,0)` | 10 18 28 1 | six blocks, section 1 using 3, 4, 5 |
| `(2, 2)` at `(0,1)` | 1 8 15 1 | placed at `start_chn + c` |

All five and a sixth at `(1, 2)` go through both sides on the reviewer instrument and the port matches the host element for
element, so the code is right. **They are not in `tests/backports/host/vdspbiquad` yet**: the host's own
`vDSP_biquadm_DestroySetup` stops the process on the buffer shapes those cases need, so putting them in the suite needs a
setup whose destruction the host survives. Until then a change to the stride would not be caught by the suite, which is the
one thing about this pair the record should not leave open. The elements are read in the element type the
declaration names, in both the 9.0 pair and the 16.0 pair (measured: each of `SetCoefficientsSingleD` and `SetCoefficientsDoubleD` was
handed a float array of 9 and a double array of 9, and each of them read its own).

**`SetTargets` is where the two precisions part company, and the difference is in the record rather than in the code.**

- On a **single-precision** setup the coefficients approach their targets **one sample at a time**: the sample is filtered with the
  coefficient as it stands, and the coefficient then moves by `(target - coefficient) * (1 - interp_rate)` - the rate is the fraction
  of the distance *left*, not the fraction travelled - and lands exactly on the target when what is left is at most
  `interp_threshold`. Measured with a pure gain (a1 = 0) and a constant input, where the output at each sample *is* the coefficient
  that sample was filtered with, a b0 going from 1 to 9 with a threshold of 0.25 and

  | rate | the samples of one call of eight answer |
  | --- | --- |
  | 0.5 | 1, 5, 7, 8, 8.5, 9, 9, 9 |
  | 0.1 | 1, 8.2, 9, 9, 9, 9, 9, 9 |
  | 0.9 | 1, 1.8, 2.52, 3.168, 3.751, 4.276, ... |

  and the target is in place before the first sample - 9 in front of every sample - when the rate is 0, when the threshold is 0, or
  when the threshold is at or above the distance (measured: a rate of 0.5 with thresholds of 0 and of 100 over that same b0).
- On a **double-precision** setup the target is in place before the first sample **whatever** the rate and the threshold are: the
  same four parameter sets answer 9, 9, 9, 9 where the single-precision setup of the first two answers 1, 5, 7 and 1, 8.2, 9. So the
  `interp_rate` and `interp_threshold` of `vDSP_biquadm_SetTargetsSingleD` and `vDSP_biquadm_SetTargetsDoubleD` are recorded with the
  target and change no answer. That is a difference from the header's wording and the registry entries for those two functions say so.

**And the walk in a cascade is not the isolated one: the snap travels backwards through the sections.** A section's
coefficient lands on its target when what is left of the distance is at most `interp_threshold` **and every section after it has
landed as well**. So the last section lands as soon as its own distance is within the threshold and one before it waits for
that, which is what a one-section measurement cannot see.

Measured on this machine, over a two-section setup whose sections go 2 -> 4 and 5 -> 10 with a rate of 0.5 and a
threshold of 0.25, the host answers

```
10  22.5  30.625  35.1562  37.5391  40  40  40
```

The first section's own distance reaches the threshold at the third sample - 0.25 from 4 - and it does *not* land there,
because the second section's is still 0.625. The two land together at the fifth, where the first's is 0.125 and the second's
0.15625. Without the deferral the same setup answers 10, 22.5, 30.625, **37.5**, **38.75**, 40 - 7% high at the peak of the
transition, which is an audible level bump in the middle of a filter change.

The rule is fitted over eleven cases on the host - rates of 0.25, 0.5 and 0.75, thresholds from 0.1 to 0.5, and two
targets chosen so the walk never lands on a round number - and the port answers every one of them element for element. The
case that no rule of this shape gets right is a rate of 0.75, where neither section reaches its threshold inside eight
samples and the answer is the plain geometric walk; that is one of the eleven. A section on its own is the same rule with
nothing after it, which is the isolated walk the single-section cases measure, and a two-section setup whose two walks are
identical agrees with any deferral - which is why the one-section checks here never saw this and why all eleven are now in
`tests/backports/host/vdspbiquad`. Removing the deferral fails ten of that suite's checks.

## What the setup calls answer

`CreateSetup` answers NULL for no coefficients at all and for a count that would overflow, and a setup for everything else -
**no sections and no channels are not refusals**: the host answers a setup for both, and a call over `M = 0` passes the input
through unchanged (measured, 1, 2, 3, 4) while a call over `N = 0` writes nothing at all (measured, the output left as it was).

**Two cases the host cannot be asked about, and the port's own answers are what they are.** A NULL coefficient array reaches a
`memmove` inside the host's own `CreateSetup` and stops the process, so the port's NULL there is a refusal the differential cannot
compare. The same is true of `DestroySetup(NULL)`: the header does not declare that argument nullable and the host reads through it,
so the port takes it and does nothing - a difference in care rather than of behaviour, and one the differential records as the port's
answer alone. A third is a **window that names channels the setup does not have**: the release answers it on some shapes and
stops the process on others, so the differential asserts the port's own answer there, which is the one the review measured on a
shape the host survives - the cells the window covers change, the rest of the setup is left alone, and nothing is written past
the block. That case is placed so an unclamped index would land on a cell the setup *does* have, which is what gives it teeth
on a band with no AddressSanitizer: a two-section two-channel setup and a one-section four-channel window at channel one, and
the two answers are 10 and 140 with the guard and 8 and 63 without it.

## The single-section setters of 15.0: vDSP_biquad_SetCoefficientsDouble and _Single

Two rows the ledger carried as `missing`, and `facts/Accelerate/vDSPPlacement.md` recorded as **blocked for
want of a guest probe**, on the grounds that "a port cannot construct one [a `vDSP_biquad_Setup`], so the host
differential has nothing to call it on". That reasoning does not hold and this section is the measurement that
shows it: **each side builds its own setup with its own `vDSP_biquad_CreateSetup` and reads the change back
through its own `vDSP_biquad`. Nothing crosses, so nothing needs a layout the two sides agree on.** The setup
is never read on either side - vDSP.h declares `struct vDSP_biquad_SetupStruct` with no published layout and
says the contents are to be touched only through the setup routines - and that is what the case in
`tests/backports/host/vdspbiquad15` does. No guest probe was needed and none is pending.

What they do, measured against the host with three runs of the same input over the same saved delay:

| run | what it is |
| --- | --- |
| `after` | the setup the setter ran on, over the delay a first run with the old coefficients left |
| `fresh` | a setup made from the window's blocks in the old ones' places, over that same delay |
| `old` | the same setup with no setter at all, over that same delay |

`after` equals `fresh` on both sides and differs from `old`, so **the setter replaces the five coefficients of
each section the window names and touches nothing else**: the caller's delay is the filter's state and this
single-section form keeps none of its own. Over setups of one, two and three sections and every window inside
them - 20 windows per precision, both precisions - the port matches the host element for element, and the
mutant that also cleared the delay (`fresh` over a zero delay) is required to differ from the rule first.

`vDSP_biquad_SetCoefficientsSingle` takes the caller's five as floats and a setup made from the same five as
doubles answers the same, so the values are widened once on the way in, which is what the declaration's
element type says and what the case asks of both sides.

**A window that reaches past the setup is not asked of the host.** It reads and writes outside its own object,
and what comes back depends on the window: over one section, `start_sec` 1 answers coefficients the setup never
had and `nsec` 4 answers values out of uninitialised memory; over two sections, `start_sec` 1 with `nsec` 2
ends the process with a trap (rc 133) and `start_sec` 2 ends it with a segfault (rc 139) - five windows, one
call per process. The port's answer is the rule the multiple-biquad setters of this package already answer for
a cell outside the window (measured on the 9.0 rows, "The setters" above): **the sections the window names and
the setup has change, and the ones it does not have do not**, so a window that names nothing writes nothing.
The case asserts that against a setup the port made from the coefficients the window should leave behind, so it
is the port against itself with the arithmetic spelled out, and it says which of the two each window is.

A NULL setup and a NULL array are undefined by the declaration's `__nonnull`; both are asked of the port alone,
each in a child process so that a port writing through either ends a process the case reports, and the NULL
array is asked again in this process, where the case says the coefficients did not move.

A setup of **no** sections is not asked of either setter: the port's own `vDSP_biquad_CreateSetup` answers NULL
for `M = 0`, which is that row's answer and not this one's, and the host answers a setup and writes no output
at all for a cascade of no sections. The case says so rather than inventing a setup to ask about.

`gates: coordinator`. The differential is `75 checks, 0 failures`, clean under AddressSanitizer with
`SAN=1`, and the mutation proof is one line of `vDSPBiquad15.m` - `into[1] = into[0]` after the copy, which
puts b0 in b1's place - giving `75 checks, 43 failures`, every one of them a window case. Reverted
byte-identically: `75 checks, 0 failures`.

## What has not been run

The device test for this group is `tests/backports/device/vdspbiquad.m`, and it has not been run: no device or emulator
call test has happened for Accelerate in this port at all. Every answer on this page is a host measurement and a device-unverified
one, which the port's own contract accepts as a floor and not as the bar.
