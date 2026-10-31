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
| [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) — QR and PDF417 detection behind `VNDetectBarcodesRequest`, with the old QR/PDF417 writers enabled only for generated tests | `v3.1.1` (`287c85df6f961c8efbfb5ffd736cd9457b8b890e`) | Apache-2.0; the licence is installed with the package under `licenses/LICENSE` | `packages/z/zxing-cpp` |
| [LZ4](https://github.com/lz4/lz4) — the block codec behind `COMPRESSION_LZ4_RAW` and the blocks of `COMPRESSION_LZ4` in the Compression backport, `lib/` only, unmodified, built with its symbols hidden | `v1.9.2` (`fdf2ef5809ca875c454510610764d9125ef2ebbd`) | BSD-2-Clause; the licence is installed with the package under `licenses/LICENSE` | `packages/l/lz4` |
| [xz](https://github.com/tukaani-project/xz) — the liblzma subset behind `COMPRESSION_LZMA` in the Compression backport (the LZMA1 and LZMA2 coders, the xz container, the CRC32, CRC64 and SHA-256 checks), unmodified sources, built with its symbols hidden and a configuration header of this repository (`packages/x/xz/port/config.h`, derived from the upstream's `dos/config.h`) | `v5.8.4` (`d3e650e63c110e830fd5391e7f8b45df0b91d3da`) | 0BSD; the licence is installed with the package under `licenses/COPYING.0BSD` | `packages/x/xz` |
| [mozjpeg](https://github.com/mozilla/mozjpeg) — the JPEG encoder Telegram writes its photos with, as static `libjpeg` and `libturbojpeg`, built for armv7 | `61e03cc6b25ea506085dce1ee93ddd1f4b6588e6` (master, 4.1.4 plus 22 commits: the snapshot Telegram's tree holds, every file identical) | BSD-3-Clause | `packages/m/mozjpeg` |
| [libvpx](https://github.com/webmproject/libvpx) — the VP8 and VP9 codec, as static `libvpx`, built for armv7 with its NEON assembly (see below) | `e7bfd8b6c230a6824e7fd1efa2378a7322986128` (master, 1.13.0 plus 435 commits: the snapshot Telegram's tree holds, every file identical bar its `.git` file) | BSD-3-Clause | `packages/v/vpx` |
| [dav1d](https://code.videolan.org/videolan/dav1d) — the AV1 decoder, as static `libdav1d`, built for armv7 with its ARM assembly (see below) | `330e20672e85f9de1678dccd6957845898ef57a1` (1.5.0 plus 23 commits: the snapshot Telegram's tree holds, every file identical bar its `.git` file) | BSD-2-Clause | `packages/d/dav1d` |
| [TDLib](https://github.com/tdlib/td) — `tde2e` and `tdutils`, the end-to-end encryption and utilities of secret chats, as static libraries | `e894536b2f46caad93f997448d2daff9431b19dd` (v1.8.0 plus 7675 commits: the snapshot Telegram's tree holds, identical bar its `.git` file and the line endings of three Windows scripts) | BSL-1.0 | `packages/t/td` |
| [folly](https://github.com/facebook/folly) — the RCT-Folly subset React Native 0.86 builds (its Default and Fabric subspecs), with the flags it compiles them with, as static `libfolly`, built for armv7 | `0660ead5b610047a279cc291129e98e3f2a1fc37` (`v2024.11.18.00`, the tag React Native pins; the file `folly/detail/Demangle.cpp` that its podspec lists is not in the tag, so it is not compiled) | Apache-2.0; the licence is installed with the package under `licenses/LICENSE` | `packages/f/folly` |
| [glog](https://github.com/google/glog) — the logging library folly writes its diagnostics with, as static `libglog`, built without gflags as React Native builds it | `a6a166db069520dbbd653c97c2e5b12e08a8bb26` (`v0.3.5`) | BSD-3-Clause; the licence is installed with the package under `licenses/COPYING` | `packages/g/glog` |
| [fmt](https://github.com/fmtlib/fmt) — the formatting library folly and glog format with, as static `libfmt` | `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f` (`12.1.0`) | MIT; the licence is installed with the package under `licenses/LICENSE` | `packages/f/fmt` |
| [double-conversion](https://github.com/google/double-conversion) — the binary-decimal conversions folly parses and prints doubles with, as static `libdouble-conversion` | `361924fb61c043627d4179e941a102d543f6efa0` (`v1.1.6`) | BSD-3-Clause; the licence is installed with the package under `licenses/LICENSE` | `packages/d/double-conversion` |
| [fast_float](https://github.com/fastfloat/fast_float) — the header-only number parser folly's conversions use | `77cc847c842c49e7e3477c1e95da2b6540166d66` (`v8.0.0`) | MIT, or Apache-2.0 or BSL-1.0 at the licensee's choice; the three licence files are installed with the package under `licenses/` | `packages/f/fast_float` |
| [Boost](https://github.com/react-native-community/boost-for-react-native) — the headers React Native 0.86 includes, as a headers-only package beside the release archive that dynarmic takes | `59ed9e589e222fb6d54b3e0a81d510190801b1d9` (the `react-native` source of `packages/b/boost` at `v1.84.0`, the subset React Native ships) | BSL-1.0; the licence is installed with the package under `licenses/LICENSE_1_0.txt` | `packages/b/boost` |
| [SocketRocket](https://github.com/facebook/SocketRocket) — the RFC 6455 WebSocket client React Native 0.86 pins through its CocoaPods helpers, as static `libSocketRocket`, built with ARC for armv7 | `21ac000390781823dd4bd87fdc419976e05dd7a6` (`0.7.1`) | BSD-3-Clause with the Additional Grant of Patent Rights; the licence and the patent grant are installed with the package under `licenses/` | `packages/s/socketrocket` |
| [Yoga](https://github.com/facebook/react-native/tree/v0.86.3/packages/react-native/ReactCommon/yoga) — the flexbox layout engine React Native 0.86 ships in `ReactCommon/yoga`, as static `libyoga`, built for armv7 | `04e0ef4284ef9e2fb94075b0f98c6371d12ea1b31c2e42540a900a1e86ea46f5` (sha256 of the `react-native` 0.86.3 npm tarball, whose `ReactCommon/yoga` is tree `02a0dfd0b4d0a8fc265c620e45b45f7d3a8f65fd` of the `v0.86.3` tag, `95cffbff2e071e278987c7d7cd51fbc970dd5622`; no commit of `facebook/yoga` has that tree) | MIT; the licence is installed with the package under `licenses/LICENSE` | `packages/y/yoga` |

The pins are the snapshots Telegram's tree holds, found by comparing every file's content against upstream history:
each is a release plus master commits, not a release tag. Each armv7 build keeps its NEON or ARM assembly, which upstream's
own build tooling produces; revenant's clang assembles it at the 6.0 target, and the archives are checked for NEON objects
and a 6.0 minimum in every member. mozjpeg's own `GNUInstallDirs` resolves a relative `CMAKE_INSTALL_LIBDIR` against the
source tree, so the recipe passes an absolute one, or the archives land in the source directory. Its NEON code is the
intrinsics path, not generic C: `jsimd_neon.S` uses GNU directives (`.fpu`, `.arch`) that clang's integrated assembler
rejects on Mach-O, so CMake's GAS probe selects the intrinsics on its own, and the recipe leaves `NEON_INTRINSICS` at its
default. Assembling the `.S` would need upstream's gas-preprocessor, which is not wired. libvpx's configure would assemble its ARM `.asm` files, after `ads2gas_apple.pl`
(upstream's perl), with Apple's bare `as`, which records iOS 5.0 whatever the target says; so its make runs with `AS` and
`ASFLAGS` set to revenant's clang at the 6.0 target, and with `CC` and `CXX` set to revenant's clang too, since configure's
own `xcrun` lookups would pick the command-line tools. dav1d needs no `gas-preprocessor.pl` for armv7 under clang: meson's
gate for it applies to MSVC only. Neither build has run on a device here. TDLib's `tde2e` and `tdutils` need zlib, OpenSSL
and libc++ at link time; xmake does not pass a package's own dependencies on to its consumers, so each consumer names them.

## The compiler, linker, signer and SDK

These run on the build machine. The compiler and its runtime reach the device;
the linker, signer and SDK stubs do not.

| Component | Version | License | Package |
| --- | --- | --- | --- |
| Swift compiler | 6.4.0 | Apache-2.0 WITH Swift-exception | `packages/s/swift`, `packages/s/swift-bootstrap` |
| LLVM / clang | 23.1.3 | Apache-2.0 WITH LLVM-exception | `packages/l/llvm` |
| ld64, from cctools-port (with apple-libtapi to read the SDK's `.tbd` stubs) | 956.6 | APSL-2.0; libtapi is Apache-2.0 WITH LLVM-exception plus NCSA | `packages/l/ld64` |
| ldid | 2.1.5-procursus7+23.gaf86971 | AGPL-3.0-or-later (build-time signer; linked into nothing that ships) | `packages/l/ldid` |
| iPhone OS SDK (opt-in, `apple_sdk`) | 16.4 | Apple SDK license terms (from [`theos/sdks`](https://github.com/theos/sdks)) | `packages/i/iphoneos-sdk` |
| iPhone OS SDK (default) | 26.2 | Apple SDK license terms (from [`xybp888/iOS-SDKs`](https://github.com/xybp888/iOS-SDKs)) | `packages/i/iphoneos-sdk` |
| Rust toolchain: rustc, cargo, the standard library and its `rust-src`, from the nightly `nightly-2026-10-22`; installed by rustup 1.29.2, whose installer is pinned by checksum | nightly-2026-10-22 (rustc 1.101.0-nightly) | Apache-2.0 OR MIT | `packages/r/rust` |

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
