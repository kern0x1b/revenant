# libsql on iOS 6: design and measurements

## Why libsql

The paseo-app React Native application uses `expo-sqlite` which depends on libSQL. libSQL is a fork of SQLite maintained by Turso that adds replication, encryption, and remote access capabilities while maintaining SQLite compatibility.

## Target selection

The armv7-apple-ios6 target is the same as used for other Rust crates in revenant (tlottie, mtproto, wallet). It uses:
- LLVM target: `thumbv7-apple-ios`
- CPU: `generic` with `+v7,+vfp3,+neon`
- Float ABI: soft with VFP instructions (`eabi`)
- Thread-local: false (iOS 6 dyld lacks TLS descriptors)
- Panic strategy: abort

## Build configuration

The package builds the `libsql` crate from the libsql-rs workspace at version 0.5.0 (tag `libsql-rs-v0.5.0`, commit `97652c12fe8bb215fe51b5370b46f27c0bc9d6e1`).

The build uses:
- Rust nightly-2026-10-22 with rust-src component
- `-Zbuild-std=core,alloc,std,panic_abort` to compile std for the target
- `--crate-type staticlib` to produce a static archive
- `--config profile.release.lto=false` and `-Cembed-bitcode=no` to avoid bitcode issues with the revenant linker
- Default features: `core` (local SQLite engine)

## C sqlite amalgamation

The libsql-ffi crate (dependency of libsql) builds SQLite from the amalgamation source. The cc crate compiles it with the apple-ios toolchain's clang, targeting armv7-apple-ios6.0 with the same deployment target. This ensures the C code uses the same shims as the Rust code.

## Dependency handling

The libsql crate has several optional dependencies that are managed through Cargo features:
- `tokio` - async runtime (only `sync` feature used)
- `hyper` - HTTP client for remote access
- `tower` - service middleware
- `rustls` - TLS for remote connections
- `getrandom` - random number generation

For the `core` feature set, most of these are disabled, keeping the binary size minimal.

## iOS 6 compatibility

The same 13 libc shims from `apple-compat` that cover other Rust crates also cover libsql:

| Symbol | First release | Shim |
|--------|---------------|------|
| `clock_gettime` | iOS 10.0 | plain name + `revenant_` |
| `openat`, `fstatat`, `unlinkat`, `fdopendir` | iOS 8.0 | descriptor-pinning |
| `linkat`, `mkdirat`, `renameat` | iOS 8.0 | descriptor-pinning |
| `CCRandomGenerateBytes` | iOS 8.0 | `arc4random_buf` |
| `renamex_np` | iOS 10.0 | `ENOTSUP` for flags |
| `fclonefileat` | iOS 10.0 | `fcopyfile` fallback |
| `sysdir_start_search_path_enumeration` | iOS 10.0 | user domain only |
| `sysdir_get_next_search_path_enumeration` | iOS 10.0 | user domain only |

No new shims were needed for libsql.

## LC_VERSION_MIN handling

rustc enforces a minimum deployment target of iOS 10.0 for armv7 targets. The static library's object files record 10.0, but the final linked binary records 6.0. The linker warns about this mismatch but the binary runs correctly on iOS 6 because dyld only checks the image's minimum, not individual object files.

## Thread-local storage

The target specification has `has-thread-local = false`, so std uses pthread keys for thread-local storage. This avoids `__tlv_bootstrap` imports that iOS 6's dyld cannot resolve.

## Atomic operations

The target has `max-atomic-width = 64`. On armv7, 64-bit atomics use libcalls (`__atomic_load_8`, etc.) which are provided by compiler-rt and work on iOS 6.

## Verification

The package's on_test function:
1. Verifies `liblibsql.a` exists
2. Runs dyld.check against the iOS 6.0 armv7 dyld cache with apple-compat as provider
3. Confirms all non-weak imports are satisfied

## Known limitations

- The `remote` and `hrana` features require TLS (rustls) and async runtime (tokio), which increase binary size and may need additional shims
- Encryption feature requires the `sqlcipher` bundle which is not included
- Running on actual iOS 6 hardware has not been tested; only static verification is performed