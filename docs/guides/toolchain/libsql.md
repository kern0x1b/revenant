# libsql for armv7 iOS 6

The `revenant@libsql` package provides the libSQL Rust crate built as a static library for armv7-apple-ios6. libSQL is a fork of SQLite designed for embedded use with support for replication, encryption, and remote access via HTTP.

## Requirements

- armv7-apple-ios6 toolchain (nightly-2026-10-22 with -Zbuild-std)
- iOS 6.0 deployment target
- The `apple-compat` package for missing libc shims

## Usage

```lua
add_requires("revenant@libsql 0.5.0", {alias = "libsql"})
```

Then link it in your target:

```lua
target("myapp")
    add_rules("@addon/revenant/app")
    add_deps("libsql")
    add_packages("apple-compat")
```

The package exports `liblibsql.a` and its include path.

## Features

The default feature set is `core`, which includes the local SQLite engine with basic SQL support. Additional features can be enabled:

```lua
add_requires("revenant@libsql 0.5.0", {configs = {features = "core,replication,remote"}})
```

Available features from the libsql crate:
- `core` - Local SQLite engine (default)
- `replication` - Database replication support
- `remote` - Remote database access via HTTP (libsql-hrana)
- `hrana` - Hrana protocol support
- `encryption` - Database encryption
- `parser` - SQL parser
- `stream` - Async stream support

## Building

The package uses the revenant Rust toolchain (nightly-2026-10-22) with `-Zbuild-std=core,alloc,std,panic_abort` to compile the standard library for the armv7-apple-ios6 target.

```bash
./xmakew f -p iphoneos -a armv7
./xmakew require libsql
```

## Testing

The package includes a test that:
1. Opens an in-memory database
2. Creates a table
3. Inserts and reads data
4. Verifies all imports against the iOS 6.0 dyld cache

Run the test with:
```bash
./xmakew test -P . libsql_test
```

## Import Verification

The built `liblibsql.a` is verified against the iOS 6.0 armv7 dyld cache. All undefined symbols are provided by `apple-compat` shims:

- `clock_gettime` (iOS 10) → shim
- `*at` syscalls (iOS 8) → descriptor-pinning shims
- `CCRandomGenerateBytes` (iOS 8) → `arc4random_buf` shim
- `renamex_np` (iOS 10) → `rename` fallback shim
- `fclonefileat` (iOS 10) → `fcopyfile` fallback shim
- `sysdir_*` (iOS 10) → user-domain-only shim

The static library's object files carry LC_VERSION_MIN_IPHONEOS 10.0 due to rustc's minimum, but the final linked binary records 6.0.