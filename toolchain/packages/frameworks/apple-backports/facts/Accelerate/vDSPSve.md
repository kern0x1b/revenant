# vDSP_sve_svesq and vDSP_sve_svesqD, iOS 6.0

Both rows in `Accelerate/vDSPSve7.m`, **carried**, with the release's own vDSP on the emulated
**iPhone2,1 6.1.3 (10B329)** guest as the oracle, not the macOS host.

## Why the guest, and what it changed

The macOS arm64 host says the sum of `{1e30, 1, -1e30, 1, 1e-30, 3}` is **3**, where a left-to-right sum
gives 4, and that looked like a blocked or pairwise order. **On the 6.1.3 armv7 guest the release's own
answer is 4** — the sequential form — and the port agrees with it bit for bit. The macOS host was wrong,
the same inversion it produced for the biquad's one-ULP float difference. A reduction that looked like it
needed a different order was the host, not the port.

## What the guest agreed on, bit for bit

- **The hand-computed control**: 1, 2, 3, 4 sums to 10 and squares to 30, both exact in float, and nothing
  is credited until it passes. A differential whose expected values all come from a host cannot tell a
  correct implementation from one that reproduces the host's mistake; three searches in the biquad shape
  each reported on a function that was not the one being searched, and a control that does not involve
  the host is what catches that.
- The cancellation, the small terms between large ones, the exact sum of 23, and six denormals. All four
  agree with the release, samples and sum of squares, on two rows' worth of precision cases.

## What the arithmetic is, measured

**Everything happens in the caller's own type, and the denormals are what prove it.** Four denormals near
1e-42 give a sum of squares of **exactly zero**, because each square underflows in float; a double
accumulator would have given about 4e-84, which double represents comfortably. The float form's sum of
squares also carries the small offsets in its inputs, and the 1e-310 case in double is the same statement
from the other side. Overflow is the caller's own arithmetic: the top of the range gives `inf` for both,
and nothing saturates.

**N = 0 gives sum 0 and sum of squares 0**, in both precisions — not a refusal and not untouched memory,
and the port agrees without a case of its own because the loop writes both from its initialiser. A NaN
propagates to both answers, and signed zeroes give +0, so the host does not produce −0. Every comparison
is on the **bit pattern**, never `==`.

## The order search, and why it is not evidence

The guest run also tried five candidate orders — sequential, blocked at 2, blocked at 4, pairwise halving
and NEON 4-lane partial sums — and reported that **none** matched every case. **That result is my own
category error and carries no weight**: the candidates were evaluated in double and compared against the
FLOAT release's answer, so the small-terms case compared 3.0000000299999998 against 3 and failed on the
type, not the order. It is the same mistake the earlier macOS probe made, and it is recorded here rather
than quietly dropped.

What the search does establish, once read against the port's own comparison rather than its own: **on the
target the sequential order agrees with the release on all four inputs**, which is the requirement for
carrying the rows. The blocked and pairwise orders also agree on three of four and are not excluded by this
evidence; the sequential form is chosen because it is what the port does and the guest confirms it, not
because the others were ruled out.

## How to run it

    sh tests/backports/host/vdspsve/run.sh                    # the host differential
    SAN=1 sh tests/backports/host/vdspsve/run.sh              # under AddressSanitizer
    sh tests/backports/device/vdsp-probe/run.sh                # the guest, through heavy.sh
