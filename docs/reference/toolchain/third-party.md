# Third-party code, and where each piece stands

This repository contains almost no third-party source. Every dependency below is
declared by a package under `packages/` that names the upstream it fetches
and the version it pins; nothing external is vendored into the tree except the sources
listed under *Vendored in the tree*. Each package copies its upstream license file
under `licenses/` when it installs.

The point of this file is that a reader can tell, without building anything,
exactly what a port built with the toolchain links against, what builds it, and under
what terms. Versions and licenses here are taken from the package definitions, and
package paths are relative to the checkout's root. The packages are described in
[packages](packages.md).

## Libraries a port links

Fetched by the package named beside each, built for the target architecture, and
carried into the program that ships to the device.

| Component | Version | License | Package |
| --- | --- | --- | --- |
| libc++, libc++abi | 23.1.1 | Apache-2.0 WITH LLVM-exception | `packages/l/libcxx` |
| The Swift runtime and standard library, with the system-framework overlays | 6.4.0 | Apache-2.0 WITH Swift-exception | `packages/s/swift-runtime` |
| Combine — a `Combine` module for platforms without Apple's framework: OpenCombine, below, with our patches | 2026.10.19 | MIT (the upstream MIT copyright is installed with the package) | `packages/c/combine` |
| SwiftUI — a `SwiftUI` module on the UIKit of iOS 6 | the checkout | MIT | our own code, not third-party: the target `SwiftUI` of [`frameworks/SwiftUI`](https://github.com/kern0x1b/revenant/tree/main/frameworks/SwiftUI) |
| [OpenCombine](https://github.com/OpenCombine/OpenCombine) — a `Combine` module for platforms without Apple's framework | `1c6f02c7ed8140c0ba7a783aaddb6e0685a0037b` (its `0.14.0` is `8576f0d579b27020beccbccc3ea6844f3ddfc2c2`) | MIT, Copyright (c) 2019 Sergej Jaskiewicz; the licence is installed with the package under `licenses/LICENSE` | `packages/c/combine` |
| Combine's patches to OpenCombine: its three modules compiled as one named `Combine`, the adaptations iOS 6 needs, and what Apple declares and OpenCombine lacks | 2026.10.19, listed in `packages/c/combine/xmake.lua` | MIT, under OpenCombine's copyright; no new licence is claimed over Sergej Jaskiewicz's work | `packages/c/combine` |
| [lzfse](https://github.com/lzfse/lzfse) — the LZFSE and LZVN codec behind `COMPRESSION_LZFSE` in the Compression backport, unmodified, built with its symbols hidden | `88e2d2788b4021d0b2eb9fe2d97352ae9190f128` (tag `lzfse-1.0`) | BSD-3-Clause; the licence is installed with the package under `licenses/LICENSE` | `packages/l/lzfse` |
| [zlib](https://github.com/madler/zlib) — the raw deflate codec behind `COMPRESSION_ZLIB` in the Compression backport, unmodified, built as `libzcodec.a` so the system `libz` is not linked | `v1.3.2` (`da607da739fa6047df13e66a2af6b8bec7c2a498`) | Zlib; the licence is installed with the package under `licenses/LICENSE` | `packages/z/zlib` |
| [LZ4](https://github.com/lz4/lz4) — the block codec behind `COMPRESSION_LZ4_RAW` and the blocks of `COMPRESSION_LZ4` in the Compression backport, `lib/` only, unmodified, built with its symbols hidden | `v1.9.2` (`fdf2ef5809ca875c454510610764d9125ef2ebbd`) | BSD-2-Clause; the licence is installed with the package under `licenses/LICENSE` | `packages/l/lz4` |
| [xz](https://github.com/tukaani-project/xz) — the liblzma subset behind `COMPRESSION_LZMA` in the Compression backport (the LZMA1 and LZMA2 coders, the xz container, the CRC32, CRC64 and SHA-256 checks), unmodified sources, built with its symbols hidden and a configuration header of this repository (`packages/x/xz/port/config.h`, derived from the upstream's `dos/config.h`) | `v5.8.4` (`d3e650e63c110e830fd5391e7f8b45df0b91d3da`) | 0BSD; the licence is installed with the package under `licenses/COPYING.0BSD` | `packages/x/xz` |

## The compiler, linker, signer and SDK

These run on the build machine. The compiler and its runtime reach the device;
the linker, signer and SDK stubs do not.

| Component | Version | License | Package |
| --- | --- | --- | --- |
| Swift compiler | 6.4.0 | Apache-2.0 WITH Swift-exception | `packages/s/swift`, `packages/s/swift-bootstrap` |
| LLVM / clang: the `clang-c` headers, the C API the declaration extractor reads the SDK through (`include/clang-c` of the clang 21.1.0 release, nothing else) | 21.1.0 | Apache-2.0 WITH LLVM-exception | `packages/l/llvm-clang-c` |
| LLVM / clang | 23.1.3 | Apache-2.0 WITH LLVM-exception | `packages/l/llvm` |
| ld64, from cctools-port (with apple-libtapi to read the SDK's `.tbd` stubs) | 956.6 | APSL-2.0; libtapi is Apache-2.0 WITH LLVM-exception plus NCSA | `packages/l/ld64` |
| ldid | 2.1.5-procursus7+23.gaf86971 | AGPL-3.0-or-later (build-time signer; linked into nothing that ships) | `packages/l/ldid` |
| iPhone OS SDK | 16.4 | Apple SDK license terms (from [`theos/sdks`](https://github.com/theos/sdks)) | `packages/i/iphoneos-sdk` |
| iPhone OS SDK (opt-in per project, `apple_sdk`) | 26.2 | Apple SDK license terms (from [`xybp888/iOS-SDKs`](https://github.com/xybp888/iOS-SDKs)) | `packages/i/iphoneos-sdk` |

## The emulator, the signer, and their libraries

Used to sign, run and test binaries on the build machine; none of it is linked
into the port binary that ships to a device.

| Component | Version | License | Package |
| --- | --- | --- | --- |
| The emulator — Revenant's ARM/iOS userland emulator | this checkout's `emulator/` | MPL-2.0 (notices in [its notice](../emulator/notice.md)) | `packages/e/emulator`, built from [`emulator/`](https://github.com/kern0x1b/revenant/tree/main/emulator) of the checkout |
| SwiftShader | 2026.09.16 | Apache-2.0 | `packages/s/swiftshader` |
| libplist | 2.7.0 | LGPL-2.1-or-later | `packages/l/libplist` — read/write plist for the ldid signer and the emulator |
| OpenSSL | 4.0.2 | Apache-2.0 | `packages/o/openssl` — used by the ldid signer and the emulator |

## Vendored in the tree

The Core ML model schema, which the `createml` package's Swift codec follows, is not held in
this repository. Nothing from it is linked into a port.

| Component | Version | License | Where |
| --- | --- | --- | --- |

## First-party

`packages/a/apple-compat`, `frameworks/Backports`, `packages/e/emulator-guest`
and `packages/f/firmware-tools` are Revenant's own (MIT); they are not third-party and are not listed here.
