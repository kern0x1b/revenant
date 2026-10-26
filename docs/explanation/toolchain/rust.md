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

The measured program is a staticlib that uses `std::thread`, `HashMap` (random seeds), `SystemTime`, `Instant`, a `thread_local!`, and `sin` and `cos`, linked into a C `main` for armv7 iOS 6.0. Checked against the iOS 6.0 armv7 dyld cache (`.cache/dyld/6.0`), 13 non-weak imports are missing:

| Symbol | First release | Shim |
| --- | --- | --- |
| `clock_gettime` | iOS 10.0 | the apple-compat shim, now also under its plain name |
| `openat`, `fstatat`, `unlinkat`, `fdopendir` | iOS 8.0 | the apple-compat shims, now also under their plain names; a descriptor names the folder a call works in, pinned for that call |
| `linkat`, `mkdirat`, `renameat` | iOS 8.0 | new: a descriptor, `AT_FDCWD` and absolute paths; two folders in one call pin one and rebuild the other's path, and `linkat` refuses a symbolic link unless `AT_SYMLINK_FOLLOW` |
| `CCRandomGenerateBytes` | iOS 8.0 | new: `arc4random_buf`, which iOS 4.3 has |
| `renamex_np` | iOS 10.0 | new: `rename` for no flags; `RENAME_EXCL` and the other flags answer `ENOTSUP` |
| `fclonefileat` | iOS 10.0 | new: `ENOTSUP`, so std copies with `fcopyfile` |
| `sysdir_start_search_path_enumeration`, `sysdir_get_next_search_path_enumeration` | iOS 10.0 | new: the user domain's directories, from the SDK's `sysdir.h` |

The first release was measured from the caches under `.cache/dyld`: a symbol the 7.1.2 cache lacks and the 8.0 cache exports is an iOS 8 symbol, and the same for iOS 10 between 9.3.6 and 10.2.1. The SDK's availability macros agree for `sysdir_*` and `fclonefileat`.

The shims keep to what the release can do. iOS 6 has no descriptor-relative system call, and rebuilding a path from the descriptor (`F_GETPATH`) is not race-safe: a folder renamed between the two steps is followed. iOS 6 does have a per-thread working directory: `__pthread_fchdir` (system call 349) pins a descriptor's folder for the calling thread alone, and `__pthread_fchdir(-1)` returns that thread to the process's working directory. The stubs in `libsystem_kernel` of iOS 6.0 and 6.1.3 (armv7) and 6.1.4 (armv7s) make system calls 348 and 349, the 6.1.6 image exports the same names, and `libSystem` exports them too. So a call that takes a descriptor pins that folder for its one system call, runs with the name relative to it, and unpins. The folder stays the one the descriptor names even when it is renamed during the call, other threads keep the process's working directory, and no lock is held. The plain names and the `revenant_*` names share that code, `fdopendir` lists the folder the descriptor holds, and `remove_dir_all` of std works. Two different folders in one call (`renameat`, `linkat`) pin one of them, and the other folder's path is rebuilt before the call: from `F_GETPATH` for a descriptor, or from the process's working directory for `AT_FDCWD`. That leaves a race on the second folder only, since a path is followed. `AT_FDCWD` and absolute paths are direct calls. `linkat` with `AT_SYMLINK_FOLLOW` links the path it resolved, which is racy between resolving and linking, because `link()` takes no descriptor on this release. `linkat` without `AT_SYMLINK_FOLLOW` refuses a symbolic link, because `link()` on this release follows it and would make a different link. The emulator's system-call dispatch has no entry for 348 or 349, so a descriptor call under the emulator fails until it gains them.

`renamex_np` with `RENAME_EXCL` is not atomic on iOS 6, so it answers `ENOTSUP`, which is the signal std's `rename_noreplace` uses to link and unlink instead. `fclonefileat` answers `ENOTSUP`, which std's `fs::copy` takes as the cue to use `fcopyfile`. The `sysdir` pair answers only the user domain, which is the only one std asks for, and it answers the documented paths (`~/Documents`, `~/Library/Caches`, and so on); a kind the user domain does not have answers nothing. A port that asks another domain gets no path, and that is the limit of the shim. The plain-name definitions are hidden, so an image exports no libc name it lacks, and each is linked only into images whose deployment target is below its release.

The host test `toolchain/tests/addon/compat/named.c` runs the shims on the host and compares the answers with the documented behaviour; the same test run against the host's own libc fails in exactly the places the shims are meant to differ. `at-race.c` renames the folder a descriptor names between the calls and checks that each call still works in that folder, and it fails on the path-rebuilding shims. Its second thread resolves a relative path while those calls run, and that path must stay in the process's working directory; it fails on the shims that changed the working directory for the whole process. `remove-tree.c` empties a nested tree through descriptors, as `remove_dir_all` does, and fails on the `ENOTSUP` shims. The `named_failures` check in `compat_test` compiles each for armv7 iOS 6 and checks that it is a hidden definition that calls nothing by its own name.

## The minimum stamped in the objects

rustc raises the iOS deployment target to a floor of 10.0 for armv7, and the floor cannot be lowered. The source of this nightly (`rustc-nightly-src`, from `static.rust-lang.org/dist/2026-10-22`) says why:

- `apple_deployment_target()` in `rustc_session` takes the `IPHONEOS_DEPLOYMENT_TARGET` value and returns `version.max(min)`. `min` is `minimum_deployment_target(target)`, which for an iOS target that is not arm64 falls through to `os_minimum_deployment_target`, 10.0. Setting the variable to 6.0 only prints the warning `minimum supported by rustc is 10.0`; the version used is 10.0.
- The LLVM triple is `versioned_llvm_target`, which appends that version to the spec's `llvm-target`. `add_version_to_llvm_target` asserts that the spec's triple is unversioned, so a spec cannot carry `armv7-apple-ios6.0.0`: rustc refuses it with `LLVM target must not already be versioned`.

So neither the target spec nor the environment can set an object's minimum below 10.0, and no linker argument can either, since the objects are compiled before linking. The measured archives agree: with `IPHONEOS_DEPLOYMENT_TARGET=6.0` set, each Rust object of tlottie, mtproto and wallet still records `LC_VERSION_MIN_IPHONEOS 10.0` (21, 50 and 127 members), and the linker prints `built for newer iOS version (10.0) than being linked (6.0)` twice per member. The binary records 6.0.

Lifting it would take a change to rustc. Rewriting each member's `LC_VERSION_MIN` after the build (for example with `ld -r -platform_version`) would make the objects say 6.0 while LLVM compiled them for the 10.0 triple, which is the claim this page refuses to make; it is not done. The warnings stay visible; they are not silenced.

This matters in two places. dyld does not check the minimum of an object, only of the image, so the image runs where its own minimum says it does. LLVM chooses some library calls by the triple's version, so a call it emits for iOS 10 is an import the check sees, and the check names it when iOS 6 lacks it. The Telegram crates do emit one: tlottie imports `__sincosf_stret`, which iOS 7 introduced, and apple-compat's table already shims it. The check does not see a codegen difference that uses no import; none was found in the measured programs, and none is verified on a device.

## Embedded bitcode and LTO

A crate's own profile can enable LTO: tlottie sets `lto = "fat"`, the mtproto workspace `lto = "thin"`. With LTO on, rustc keeps LLVM bitcode in the archive's objects, and the linker of this toolchain rejected one of them, the mtproto archive's `mtproto_engine` member, with `is not mach-o or llvm bitcode file`. The rule's contract is machine-code archives, so it does not rely on bitcode members. rustc also refuses `-C embed-bitcode=no` together with LTO (`options -C embed-bitcode=no and -C lto are incompatible`). Telegram's Bazel build never links these archives with LTO, since rules_rust does not read the profile and LTO would duplicate std across the archives, so the rule passes `--config profile.release.lto=false` and `-Cembed-bitcode=no` for every crate. With both set, the archives hold only Mach-O members.

## Other measurements

- `rust_addf` and `rust_mulf` compiled by rustc for this spec and `c_addf` and `c_mulf` by clang for `armv7-apple-ios6.0` have the same argument registers and the same instructions.
- The no_std and std staticlibs link into the armv7 program with `-lhello` and pass the import check against the 6.0 cache, after the 13 shims are linked.
- The link stage passes `measure: ... record iOS 6.0` for the program, and the rebased-pointer check passes.
- Not measured: running the program on an iPhone 4S or in the emulator. The Rust crate has not been run on iOS 6.

## Telegram's Rust engines

The app links three Rust archives, each through a Bazel `rust_static_library` in Telegram-iOS 13.0.0: `tlottie` (`submodules/tlottie`, features `cpu`, `std`, `c-api`), `mtproto_engine_ffi` (the `mtproto-ffi` package of the mtproto workspace) and `wallet_engine` (`third-party/wallet-engine`). They were built from their own folders in the reference tree through a symlink, read-only, with `--locked`; nothing in that tree was written. Each archive was force-loaded into an armv7 iOS 6.0 program, so the imports are those of every member, and checked against the 6.0 cache.

| Crate | Built | Missing non-weak imports before apple-compat | After apple-compat |
| --- | --- | --- | --- |
| `tlottie` | yes, 21 members | 14: the 13 of the `hello` measurement, and `__sincosf_stret` (iOS 7) | none |
| `mtproto_engine_ffi` | yes, 50 members | 13 | none |
| `wallet_engine` | yes, 127 members | 13, and `CFRelease` from `iana-time-zone`, which needs the CoreFoundation framework the app links | none, with CoreFoundation |

Every one of those symbols is already in apple-compat, so the crates needed no new shim. The weak symbols the probes list are `___isOSVersionAtLeast` and `___isPlatformVersionAtLeast`, the compiler-rt availability checks, which the programs define in their own text rather than import. Nothing has run on iOS 6: the programs link and pass the import check, which is the static part of the claim.

## Thread-locals and other OS-dependent parts

The 10.0 floor could make LLVM emit native thread-locals, which iOS 6's dyld cannot load. The three Telegram archives and the probes built from them were checked: none has a `__thread_vars`, `__thread_data` or `__thread_bss` section, and none imports `__tlv_bootstrap` or `_tlv_bootstrap`. The spec already has `has-thread-local` false, and std's `thread_local!` resolves to `sys::thread_local::key::unix`, which uses pthread keys. So the spec needed no change.

The sections in the archives and probes are the ordinary ones: `__text`, `__const`, `__cstring`, the literal pools, the lazy and non-lazy pointer tables, `__data`, `__bss`, `__common`, `__stub_helper` and `__picsymbolstub4`. None of them depends on the OS.

The undefined symbols that need an OS above 6.0 are the table's entries: the 13 above and `__sincosf_stret` in tlottie, each provided by apple-compat. `___chkstk_darwin`, the `os_unfair_lock` family and the `__ulock` calls are not imported. The weak symbols are the compiler-rt availability checks described above.

## Packaging

The rule and package are `@addon/revenant/rust` and `revenant@rust`. The rule builds the crate with the package's cargo, through `REVENANT_RUST_BIN` and `REVENANT_RUST_CARGO_HOME`, which the package exports, and it takes C flags and the deployment target from the apple-ios toolchain, so cargo's build scripts compile for the device with the same clang. The crate's sources are tracked through a stamp of their hashes, because xmake's own Rust language support tries to find `rustc` on the path for `.rs` files. The package's test runs `rustc --print cfg` on the spec under the pinned nightly.
