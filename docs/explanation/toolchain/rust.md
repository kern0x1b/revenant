# Rust on iOS 6: what the build measures

Modern apps carry Rust static libraries: Telegram's wallet engine, its tlottie renderer and its MTProto FFI. A port for the iPhone 4S (Apple A5, armv7, not armv7s) on iOS 6.1.3 needs those libraries built for that device. This page records what was measured to make that work and why each choice is what it is. The how-to is [build a Rust crate](../../guides/toolchain/rust.md).

## The target

rustc 1.74 removed `armv7-apple-ios`. `armv7s-apple-ios` remains as tier 3 and needs iOS 10, so neither fits. The `armv7-apple-ios6` spec in `toolchain/src/rust/` starts from rustc's own `armv7s-apple-ios` spec and changes what the A5 and iOS 6 need:

- `llvm-target` is `thumbv7-apple-ios`. Apple's clang compiles armv7 as Thumb-2 (`-target armv7-apple-ios` gives `__thumb__`), and the Rust objects are Thumb as well.
- `cpu` is `generic` and the features are `+v7,+vfp3,+neon`, the set clang gives the same triple (`-target-cpu=generic`, VFP3 and NEON).
- The float ABI is soft with VFP instructions, `llvm-floatabi` `soft` and `abi` `eabi`, which is what clang's `-mfloat-abi=soft` produces. A probe confirms it: a float add and a double multiply compiled by Rust and by clang have the same instructions, arguments in `r0`..`r3` and VFP for the arithmetic.
- `has-thread-local` is `false`. iOS 6's dyld does not read thread-local descriptors, so std keeps thread-locals on pthread keys, and no `_tlv_bootstrap` import appears.
- `panic-strategy` is `abort`, and the build uses `-Zbuild-std=core,alloc,std,panic_abort`, so std is compiled for this target from the nightly's source.

Building std with `-Zbuild-std` needs the nightly, because the build-std and JSON target specs are unstable. The stable toolchain with `RUSTC_BOOTSTRAP` is not a documented path, so it is not used.

## The toolchain

The package pins `nightly-2026-10-22`, which is rustc 1.101.0-nightly (1a2c4797e, 2026-10-21), with its `rust-src`. rustup 1.29.2 installs it, and its installer is pinned by checksum (the aarch64 and x86_64 archives). The version is the nightly, not rustup.

Telegram's reference tree (13.0.0) pins stable 1.96.1 for `wallet-engine` and `mtproto-engine`, with `rust-version = "1.96.1"` and edition 2024. `tlottie` is edition 2021. Any compiler at or above 1.96.1 builds all three, and the pinned nightly does. The nearest nightly on the 1.96 line that meets `rust-version` is `nightly-2026-04-21` (rustc 1.97.0-nightly); a port that wants that line changes the package's `channel` and `add_versions` key, and the spec test and the package's on-test run against the new compiler.

## What iOS 6 lacks

The measured program is a staticlib that uses `std::thread`, `HashMap` (random seeds), `SystemTime`, `Instant`, a `thread_local!`, and `sin` and `cos`, linked into a C `main` for armv7 iOS 6.0. Checked against the iOS 6.0 armv7 dyld cache (`~/.revenant/dyld/6.0`), 13 non-weak imports are missing:

| Symbol | First release | Shim |
| --- | --- | --- |
| `clock_gettime` | iOS 10.0 | the apple-compat shim, now also under its plain name |
| `openat`, `fstatat`, `unlinkat`, `fdopendir` | iOS 8.0 | the apple-compat shims, now also under their plain names; a descriptor other than `AT_FDCWD` answers `ENOTSUP` |
| `linkat`, `mkdirat`, `renameat` | iOS 8.0 | new: `AT_FDCWD` and absolute paths; a descriptor answers `ENOTSUP`, and `linkat` refuses a symbolic link unless `AT_SYMLINK_FOLLOW` |
| `CCRandomGenerateBytes` | iOS 8.0 | new: `arc4random_buf`, which iOS 4.3 has |
| `renamex_np` | iOS 10.0 | new: `rename` for no flags; `RENAME_EXCL` and the other flags answer `ENOTSUP` |
| `fclonefileat` | iOS 10.0 | new: `ENOTSUP`, so std copies with `fcopyfile` |
| `sysdir_start_search_path_enumeration`, `sysdir_get_next_search_path_enumeration` | iOS 10.0 | new: the user domain's directories, from the SDK's `sysdir.h` |

The first release was measured from the caches under `~/.revenant/dyld`: a symbol the 7.1.2 cache lacks and the 8.0 cache exports is an iOS 8 symbol, and the same for iOS 10 between 9.3.6 and 10.2.1. The SDK's availability macros agree for `sysdir_*` and `fclonefileat`.

The shims keep to what the release can do. iOS 6 has no descriptor-relative system call, so a shim that rebuilds a path from the descriptor (`F_GETPATH`) is not race-safe: a directory renamed or swapped for a symbolic link between the two steps is followed. Under their plain names, the descriptor-relative calls therefore answer `ENOTSUP` for any descriptor other than `AT_FDCWD`, and `fdopendir` always does; `AT_FDCWD` and absolute paths are exact. The renamed names that C callers reach through the headers keep their path rebuilding, and are not race-safe either. `remove_dir_all` of std recurses by descriptor and has no path-based fallback, so on this release it fails with `ENOTSUP` rather than racing. Fixing that is a decision for std or for a patched standard library, not for a shim. `linkat` without `AT_SYMLINK_FOLLOW` refuses a symbolic link, because `link()` on this release follows it and would make a different link.

`renamex_np` with `RENAME_EXCL` is not atomic on iOS 6, so it answers `ENOTSUP`, which is the signal std's `rename_noreplace` uses to link and unlink instead. `fclonefileat` answers `ENOTSUP`, which std's `fs::copy` takes as the cue to use `fcopyfile`. The `sysdir` pair answers only the user domain, which is the only one std asks for, and it answers the documented paths (`~/Documents`, `~/Library/Caches`, and so on); a kind the user domain does not have answers nothing. A port that asks another domain gets no path, and that is the limit of the shim. The plain-name definitions are hidden, so an image exports no libc name it lacks, and each is linked only into images whose deployment target is below its release.

The host test `toolchain/tests/addon/compat/named.c` runs the shims on the host and compares the answers with the documented behaviour; the same test run against the host's own libc fails in exactly the places the shims are meant to differ. The `named_failures` check in `compat_test` compiles each for armv7 iOS 6 and checks that it is a hidden definition that calls nothing by its own name.

## The minimum stamped in the objects

rustc clamps the iOS deployment target to 10.0. Setting `IPHONEOS_DEPLOYMENT_TARGET=6.0` gives the warning `the minimum supported by rustc is 10.0` and the target is still 10.0. So the LLVM target is `thumbv7-apple-ios10.0.0` and each Rust object of the archive records `LC_VERSION_MIN_IPHONEOS 10.0`: 68 objects in the measured archive. The linked binary records 6.0, and the linker prints one warning per object.

This matters in two places. dyld does not check the minimum of an object, only of the image, so the image runs where its own minimum says it does. LLVM chooses some library calls by the triple's version, so a call it emits for iOS 10 is an import the check sees, and the check names it when iOS 6 lacks it; the measured program imports none of that kind. What the check does not see is a codegen difference that uses no import, and none was found in the measured program. Neither point is verified on a device. The warnings stay visible; they are not silenced.

## Other measurements

- `rust_addf` and `rust_mulf` compiled by rustc for this spec and `c_addf` and `c_mulf` by clang for `armv7-apple-ios6.0` have the same argument registers and the same instructions.
- The no_std and std staticlibs link into the armv7 program with `-lhello` and pass the import check against the 6.0 cache, after the 13 shims are linked.
- The link stage passes `measure: ... record iOS 6.0` for the program, and the rebased-pointer check passes.
- Not measured: running the program on an iPhone 4S or in the emulator. The Rust crate has not been run on iOS 6.

## Packaging

The rule and package are `@addon/revenant/rust` and `revenant@rust`. The rule builds the crate with the package's cargo, through `REVENANT_RUST_BIN` and `REVENANT_RUST_CARGO_HOME`, which the package exports, and it takes C flags and the deployment target from the apple-ios toolchain, so cargo's build scripts compile for the device with the same clang. The crate's sources are tracked through a stamp of their hashes, because xmake's own Rust language support tries to find `rustc` on the path for `.rs` files. The package's test runs `rustc --print cfg` on the spec under the pinned nightly.
