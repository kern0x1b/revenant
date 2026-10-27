# neon

The AArch64-only NEON intrinsics for armv7, so code that calls them builds for the iPhone 4S and iPad 2 unchanged.

`include/arm_neon.h` includes the SDK's `arm_neon.h` with `#include_next` and, on armv7 only, adds
`include/revenant_neon_a64.h`. The toolchain puts this directory on the include path of every armv7 compile
(`toolchain/toolchains/apple-ios/xmake.lua`).

Each intrinsic is built from ARMv7 NEON instructions that give the same bits as the AArch64 one. Out-of-range
table indices give zero, as on AArch64. `tests/a64_compat_test.c` hashes each intrinsic's results over 512
pseudorandom inputs. The arm64 host runs the native intrinsics, the armv7 build runs on the emulator, and the two
outputs must be identical. All 187 lines matched when this was committed.

`vsqrtq_f32` is the exception to the same-bits rule. ARMv7 has no vector square root, so `include/revenant_neon_sqrt.h`
takes the reciprocal square-root estimate (`vrsqrte`), refines it with three Newton steps (`vrsqrts`) and multiplies by x.
Zeros keep their sign, +inf stays +inf, negatives and -inf give NaN. NEON flushes denormals to zero, so a positive
denormal gives +0 and a negative one gives NaN. `tests/vsqrt_test.c` measures it against `sqrtf` on 2^20 random normal
inputs: at most 2 ulp, and correctly rounded for 70% of them. That run is on the arm64 host, with the same estimate and
step instructions the ARMv7 build emits; the armv7 build is compiled and its assembly checked, not run on an emulator.

`vfmaq_f32` is fused: each lane is `a + b * c` rounded once. ARMv7 NEON only has the unfused `vmla`, which rounds the
product, so `include/revenant_neon_fma.h` calls libm `fmaf` once per lane. Its result is exact wherever libm's `fmaf`
is correctly rounded, which is the same bits as AArch64. A NaN result may carry a different payload. `tests/fma_test.c`
compares the shim with the native fused intrinsic on the arm64 host over 2^20 random groups of four lanes and over every
combination of zeros, ones, denormals, infinities, NaN, FLT_MAX and FLT_MIN, and it checks that the product rounds once.
Those host checks do not exercise the armv7 libm `fmaf`, which is not run on a device or an emulator here, and the speed
is not measured. Cortex-A9 has no VFPv4, so this is a library call per lane, not an instruction.

Not implemented, because ARMv7 NEON cannot give the same bits: the AES instructions (`vaes*`, `vaesmcq`), the
double-precision vector intrinsics (`*_f64`, the vector types have no f64 lanes on ARMv7), the 64-bit polynomial multiply
(`vmull_p64`), and the rounding conversions (`vcvtn*`, `vrndm*`). Code that uses them must be compiled out on armv7.

SIMDe (MIT) implements the same names, but its ARMv7 path for these is a scalar loop, not the NEON sequence, so it is
not used.
