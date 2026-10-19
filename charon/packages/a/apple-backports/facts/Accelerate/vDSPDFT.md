# The double-precision discrete Fourier transform of vDSP, iOS 7.0

Four entry points in `Accelerate/vDSPDFT7.m`, every answer measured case by case by `tests/backports/host/vdspbiquad`, which runs
the port's file and the host's `libvDSP` over the same inputs and compares every element either of them wrote. Measured from the
release's own armv7 caches, iOS 7.0 is the first held release that exports the four and 6.1.3 names none of them, so the file holds
the API of exactly one release. The release's own vecLib has them from 7.0 on, so this is the arithmetic for the bands that do not
reach it and not a second copy of a library for the ones that do.

`vDSP.h` publishes no layout for a `vDSP_DFT_SetupD`, so the setup in the port's file is its own, and a caller only passes the
pointer around.

## Which lengths have an implementation

A setup routine answers NULL for a length with no implementation, which is what the header says NULL means. Measured over 1 to 200,
in both directions and for both kinds of transform:

| kind | the lengths that answer a setup |
| --- | --- |
| complex to complex (`vDSP_DFT_zop_CreateSetupD`) | 1, 2, 4, 8, 16, 24, 32, 40, 48, 64, 80, 96, 120, 128, 160, 192 |
| real to complex (`vDSP_DFT_zrop_CreateSetupD`) | 2, 4, 8, 16, 32, 48, 64, 80, 96, 128, 160, 192 |

A power of two, and 3, 5 or 15 times a power of two from the **third** for the complex kind and from the **fourth** for the real one -
one length fewer at each end, which is what the two lists differ by (24, 40 and 120 have a complex setup and no real one; 48, 80, 96,
160 and 192 have both). The real kind also needs at least two elements: a length of 1 has a complex setup and no real one.

## The transforms, and where they differ from the header's formula

All three are unnormalised, and the sum each one computes is the one the header prints.

**Complex to complex**, forward: `H[k] = sum over j of h[j] * e**(-2*pi*i*j*k/N)` into `Or[k]` and `Oi[k]`, k over the whole length.
Measured: an impulse at 0 answers 1 in every bin and a vector of ones answers N in bin 0 and 0 in the rest. The inverse is the same sum
with the exponent's sign the other way, and it is unnormalised too - measured, a packed input of 1 in `Or[0]` and nothing else answers
1 in every element of both output arrays at N = 4, where a normalised inverse would answer 1/4.

**Real to complex**, forward: the input is the **even-indexed samples in `Ir` and the odd-indexed ones in `Ii`**, N/2 each, and the
output is the packing the header prints under the declaration - `H[0]` in
`Or[0]`, `H[N/2]` in `Oi[0]`, and `H[k]` as `Or[k] + i * Oi[k]` for 1 < k < N/2. **Every packed value is twice the transform's
own**, which the header does not say. Measured as the linear map on the four basis inputs at N = 4 and N = 8: with `Ir[0]` alone set
to 1 at N = 4 the answer is `Or = (2, 2)`, `Oi = (2, 0)`, which is H = (2, 2, 2) where the transform of (1, 0, 0, 0) is (1, 1, 1); with
`Ir[1]` alone set to 1 at N = 8, whose real signal is (0, 0, 1, 0, 0, 0, 0, 0), the answer is `Or = (2, 0, -2, 0)` and
`Oi = (2, -2, 0, 2)`, which is twice that transform's bins. The first four of those basis answers are also what fixes the layout:
`Or[0] = 2 * (the sum of all four input values)` and `Oi[0] = 2 * (the alternating sum)`, which are the DC and the Nyquist bin of
the interleaved signal.

**The inverse** swaps the two layouts, which the header says under the declaration: the packing comes in `Ir` and `Ii` and the even
and the odd samples go out in `Or` and `Oi`. The round trip is what fixes the scaling: a real signal of N = 8 comes back as **16 times
itself**, which is a forward of twice the transform times an unnormalised inverse (measured at the host for N = 2, 4, 8 and 16, where
the factor is 2N every time).

## The tolerance in the differential

The two sides sum the same terms in a different order - the host's is a butterfly and this is the sum the header prints - so the
differential compares an element to 1e-5 of its value, relative, and nothing else. That is the precision of the arithmetic and not a
widened expectation: the packings agree to the last place a double has, and the round trip agrees to about 1e-15.

## What has not been run

No device or emulator call test has been run for Accelerate in this port at all, so every answer on this page is a host measurement
and a device-unverified one.
