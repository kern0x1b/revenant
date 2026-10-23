# neon

The AArch64-only NEON intrinsics for armv7, so code that calls them builds for the iPhone 4S and iPad 2 unchanged.

`include/arm_neon.h` includes the SDK's `arm_neon.h` with `#include_next` and, on armv7 only, adds
`include/revenant_neon_a64.h`. The toolchain puts this directory on the include path of every armv7 compile
(`toolchain/toolchains/apple-ios/xmake.lua`).

Each intrinsic is built from ARMv7 NEON instructions that give the same bits as the AArch64 one. Out-of-range
table indices give zero, as on AArch64. `tests/a64_compat_test.c` hashes each intrinsic's results over 512
pseudorandom inputs. The arm64 host runs the native intrinsics, the armv7 build runs on the emulator, and the two
outputs must be identical. All 187 lines matched when this was committed.

Not implemented, because ARMv7 NEON cannot give the same bits: the AES instructions (`vaes*`, `vaesmcq`), the
double-precision vector intrinsics (`*_f64`, the vector types have no f64 lanes on ARMv7), the fused multiply-add
`vfmaq_f32` (ARMv7 NEON only has the unfused multiply-add), the 64-bit polynomial multiply (`vmull_p64`), and the
rounding conversions (`vcvtn*`, `vrndm*`). Code that uses them must be compiled out on armv7.

SIMDe (MIT) implements the same names, but its ARMv7 path for these is a scalar loop, not the NEON sequence, so it is
not used.
