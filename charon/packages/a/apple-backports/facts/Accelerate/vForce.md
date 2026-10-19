# vForce's cube root, iOS 8.0

Two entry points in `Accelerate/vForce8.m`: `vvcbrt` and `vvcbrtf`. Measured from the release's own armv7 caches, 8.0 is
the first held release that exports the two, so the file holds the API of exactly one release. The rest of vForce's elementwise
family - the square roots, the reciprocal roots, the divide - are 4.0 and 5.0 APIs the release already has, which is why they
are not rows here.

Every answer is the host's own vForce, measured case by case by `tests/backports/host/vforce` over the values that decide a
cube root: zero and its negative, the perfect cubes and their two neighbours either side, the smallest normal, the denormals
below it, the extremes, and a geometric spread of ordinary magnitudes.

## What the family says about itself, and what that costs the comparison

`vForce.h` says of the whole family that it "may treat some or all denormal numbers as zero", that it "does not guarantee to
set floating point flags correctly", and that a developer "should assume that the exact value returned and treatment of
denormal values will vary across different microarchitectures and versions of the operating system". So the port answers the
number the header's own pseudocode computes - libm's `cbrt`, and `cbrtf` for the single-precision form - and the host
differential compares with a tolerance rather than exactly.

The tolerance is 1e-6 of the value, relative, and it is a measured size: over the 32 values above the two agree to the last
place a double has in every case, and the two infinities agree as themselves (a cube root of an infinity is that infinity, and
the difference of two of them is a NaN, so the comparison treats them as equal rather than subtracting them).

A length of zero writes nothing on either side and a length of one answers 3 for 27 on both, which is the shape the family is
usually called in - the length is a pointer and the caller names the count there, not in an argument.

## What is not carried, and why

`quadrature_integrate` (iOS 10.0, first exported at 10.0.1) is **not** in this group. It is a port of four QUADPACK routines -
the non-adaptive QNG, the adaptive QAG and the QAGS with Peter Wynn's epsilon extrapolation, and the infinite-bound transform
- each with its own Gauss-Kronrod rule and its own published abscissa and weight table, over a caller-provided workspace whose
per-interval size the header fixes at 32 and 152 bytes. It is one row and the largest piece of arithmetic in vForce, and it is
named here rather than left to be found: the next session should take it with the QUADPACK source (netlib, and the BSD-licensed
`quadpack` in the same terms as any other port of it) as the reference and the host as the oracle, which means the decision
tree in `Quadrature/Integration.h` and the four integrators measured one at a time.

## What has not been run

No device or emulator call test has been run for Accelerate in this port at all, so every answer on this page is a host
measurement and a device-unverified one.
