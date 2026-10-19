# SPAngle functions (iOS 16.0)

Four functions of the iOS 16 Spatial API, in `Spatial/Spatial16.m` of `libSpatialBackports.dylib` (config `spatial`).
Their declarations are the generator's (`spec/Spatial/declarations.tsv`, the rows `SPAngleMakeWithDegrees`,
`SPAngleMakeWithRadians`, `SPAngleGetDegrees`, `SPAngleEqualToAngle`, all `introduced` 16.0 by the SDK's availability).
The struct is `SPAngle { double radians; }`. Declared in `Spatial/RevenantSpatial.h`.

## Why these bodies are the port's own

The SDK declares every Spatial function `static inline`, with its body in the same header, so no release exports
them and the port cannot carry Apple's bodies. The port writes its own, and the expression of each was chosen by
measurement against the host's Spatial, not taken from the SDK's text.

## The measurements

Oracle: the host's own Spatial, from the macOS SDK on this machine (`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`,
macOS 26 target, arm64), compiled into `tests/backports/host/spatial-angle/oracle.c`. The inputs are every edge value
(0, -0, +-1, 45, 90, 180, 360, +-1e300, 1e-300, the smallest subnormal, +-infinity, NaN, 1/3, pi, 2 pi, DBL_MAX,
DBL_MIN, the double above 1, 0.5) plus one million random bit patterns from a fixed generator.

- `SPAngleMakeWithDegrees(d)` is `d / 180.0 * M_PI`. Bit-for-bit with the host on all 1,000,024 inputs. Two other
  orderings were measured and rejected in an earlier scratch probe, not committed, over 1,000,016 inputs (the same
  random generator and a 16-value edge list): `d * (M_PI / 180.0)` differs on 292,487 of them and `d * M_PI / 180.0`
  on 359,315. The committed `d / 180.0 * M_PI` was the one of the three with no difference in that probe.
- `SPAngleGetDegrees(a)` is `a.radians * 180.0 / M_PI`. Bit-for-bit on all 1,000,024 inputs. The rejected
  `a.radians * (180.0 / M_PI)` differs on 270,418 of 1,000,016 (the control of the test does exactly this and fails,
  270,274 of 1,000,024 in the committed run), and `a.radians / M_PI * 180.0` on 360,360.
- `SPAngleMakeWithRadians(r)` stores `r`. The value is unchanged, bit for bit.
- `SPAngleEqualToAngle(a, b)` is `a.radians == b.radians`, exact, with no tolerance. Measured: `0` equals `-0`; NaN
  equals nothing, not even itself; `+inf` equals `+inf` and not `-inf`; `1` is not equal to the next double above it,
  nor to `1 + 1e-9` or `1 + 1e-12`; `0` is not equal to `2 pi`, and `pi` equals `2 pi - pi`.
- NaN and infinity pass through every conversion: `GetDegrees(NaN)` is NaN and `GetDegrees(inf)` is inf.

## The test

`tests/backports/host/spatial-angle/run.sh` links the port's object into `differential.c` and compares each function
against the oracle over the inputs above. A double is equal when its bits are equal, or both are NaN; a bool when it is
the same bool. A control is built from a copy of `Spatial16.m` with the `GetDegrees` expression written in the other
ordering, and the run fails unless that control is caught. The committed run: the port prints `ok` for all four
functions (2,000,623 equality cases, 1,000,024 for each conversion), and the control prints `FAIL SPAngleGetDegrees`.

## What is not measured

- **The port's object was compiled and run for the host (arm64), not for armv7.** The iPhone 4S runs armv7 under iOS
  6.1.3; the same C source compiled for that target may round differently. This is device-unverified until a run on
  the device or the emulator exists for the armv7 object.
- NaN payloads are not compared (both sides must be NaN).
- Only these four functions. The rest of the SPAngle surface (`Acos`, `Sin`, `Normalize` and the other iOS 17 names in
  `ios170.json`; the `SPAngleFloat` family and `SPAngleMake` in `ios260.json`) is owed and not in this library.
