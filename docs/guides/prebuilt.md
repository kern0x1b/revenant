# Prebuilt packages

Status: the shared store at `~/.revenant/store` is the reuse path. A recipe whose key is already installed there is
taken from the store; a package whose key moved is built once locally under `nice -n 15` and then reused from the store.
The releases named below are the earlier archives for `llvm`, `swift`, `ld64`, `libcxx` and `swift-runtime`; the owner
forbids publishing new builds to GitHub releases (2026-11-23), so no new release is made for a moved key.

## What it is for

LLVM and Swift are slow to build from source, and every machine and every change to their recipes would build
them again. Measured for LLVM (the `libraries` configuration, clang for ARM and AArch64, 12 cores): ninja took 8.9
minutes on 2026-11-02 and 9.0 on 2026-11-03 with nothing else running (125 CPU-minutes), and the same build on a Mac
that other builds share takes a multiple of that (the load average was 30 to 40 on 2026-11-19). A prebuilt archive is
built once for a key, on this Mac (there is no CI: `prebuilt.yml` was removed on 2026-11-03 with the other workflows),
and kept in the shared store under that key. A later run whose recipe gives the same key takes that install instead of
building. An existing release of the key is downloaded once into that store; it is not the only way to fill it. A kept build tree does not make a rebuild incremental across a change of the
host's compiler: the kept tree of 2026-11-02 was built with Apple clang 21.0.0.21000334 (the tree of 2026-11-03 records
the same), and with the host's 21.0.0.21000401 ninja planned 2709 steps for it after one patched file, and its
precompiled headers were refused (`built from a different branch`).

## The key

`toolchain/modules/prebuilt.lua` computes it from:

- the name, the version, the platform and the architecture;
- the package's build hash: its configs, including the readonly digest configs (`recipe`, `sources`),
  which change exactly when the files that make the output change, and its toolchain names;
- the name and build hash of each library dependency, since a library built against another build of a
  dependency is another library.

An earlier release is named `prebuilt-<name>-<key>`, and its asset is `<name>-<key>-<plat>-<arch>.tar.xz` with a
`.sha256` beside it. A changed recipe or patch is a new key and so a new store entry; an unchanged one is
never built twice.

## On a machine

With `REVENANT_PREBUILT=<owner>/<repository>` set, a recipe wired to the module does this:

1. `on_download` asks for the release of its key. If the release exists, the archive and its checksum are
   downloaded into the package's cache folder, the checksum is checked, and the source checkout is skipped. xmake
   still enters the package's `source` folder before `on_install` for a package with a url, so that folder is made,
   empty, at this point.
2. `on_install` unpacks the archive into the install folder and returns. If there is no release, it
   prints so and builds from source as it does today.

Without `REVENANT_PREBUILT`, the module does nothing, and the recipes build exactly as before.

With `REVENANT_PREBUILT_ONLY` naming the package (a comma list, or `1` for all), a missing release is an error instead: `fetch` raises and names the key, and
nothing is built from source. Set it to keep a build from falling back to LLVM, Swift or ld64. It changes no key.

The `llvm`, `swift`, `ld64`, `swift-runtime`, `libcxx` and `webkit-engine` recipes are wired. The `webkit-engine` recipe
hashes its own file, so its key changed with the hook: the release of the earlier key does not serve it, and a configure that
requires it under `REVENANT_PREBUILT_ONLY` stops at the fetch with the key, before anything is built. A release of the new key
is not made: there is no CI, so a package whose key moved is built locally.
To wire another recipe, call
`prebuilt.fetch(package)` at the top of its `on_download`, `prebuilt.install(package)` in its `on_install` and
`prebuilt.pack(package)` at its end. `swift-runtime` sets its environment and data before the install call, since an
early return would skip them. Doing that changes the recipe, and so the key, once.
The `shared` config of `swift-runtime` and the `packaged` config of `libcxx` are not wired: they stage packages that
an early return would skip, so those builds come from source. The Backports targets are not packages, so they are not affected.

A recipe is archived only when it calls `prebuilt.pack`, so a build of one has nothing to publish unless
its recipe is wired.

## Store and the earlier releases

There is no CI, and the owner forbids publishing new builds to GitHub releases (2026-11-23). A release that already exists is fetched into the store when `REVENANT_PREBUILT` is set and the key matches; a package whose key moved is built once locally into the store and reused from there by every worktree. `prebuilt.pack` refuses an install that names its own install folder in a file or a symbolic link, since that archive would not work under another one.

To fill the store for a moved key, configure as the consumer does first, then require the package:
`./xmakew f -P . -p iphoneos -a arm64 -y -c` and `nice -n 15 ./xmakew require -P . -y revenant@<name>`, where the project's
`add_requires` names the same configs (for the recompiler's guest, `library_evolution = true`). A build that takes longer than
20 minutes is stopped and reported; it does not run detached. `ld64` 956.6 is an example of an older release (key e912c374,
0.8 MB; built from source it took about 2.5 minutes with cmake and ninja, from the release 18 s).

The recompiler's library mode needs an arm64 runtime for `iphoneos` (`XL_SWIFTOBJC_LIBS`, see `docs/guides/recompiler/build-and-translate.md`):
`revenant@swift-runtime` with `library_evolution = true` and the unpackaged `revenant@libcxx`. Earlier releases for them exist
(2026-11-17, packed from main 77f70ac58): `prebuilt-swift-runtime-14437d78891c0cb1296ebd08a16dcda1` (10 MB) and
`prebuilt-libcxx-b1b707cd98355ab2321b90340d496643` (1.5 MB). Built from source the two took about 14 minutes together on a busy host.
`swift-crypto` and `network` are not wired for `prebuilt.pack`, so a cold cache builds them from source. The
swift-runtime key moves with its recipe and `frameworks/Backports/tools/lowered-members.txt`, a recipe input
(`toolchain/modules/digest.lua`): a change to either stops the old store entry from serving until the new key is built once.

The libcxx the Backports gate requires is the `packaged = true` one (`xmake.lua`, line 36), which is not wired, so it
is built from source on every cold cache (about 10 minutes on 2026-11-16) although releases of the unpackaged one exist.

## The official LLVM release instead of the `libraries` build

`LLVM-23.1.3-macOS-ARM64.tar.zst` (871 MB; 1.57 GB as `.tar.xz`) was read for what the `libraries` config
of `llvm` installs. It does not replace it:

| Needed | In the official archive |
| --- | --- |
| `libLLVM.dylib`, which `xlate` and `rellume` link (`add_links("LLVM")`) | missing: `llvm-config --shared-mode` answers `static`, and `--link-shared` fails with `libLLVM-23.dylib is missing`; LLVM comes as 213 static `libLLVM*.a` |
| `libclang-cpp.dylib`, which `xlgen` links with `LLVM` | present (112 MB, `@rpath/libclang-cpp.23.1.dylib`), with its own copy of LLVM linked in: linking it together with the static LLVM libraries puts two copies of LLVM's global registries in one process |
| the headers, `llvm-config`, `llvm-extract`, `llvm-split`, `llvm-dis` | present |
| no RTTI, as the consumers build with `-fno-rtti` | `LLVM_ENABLE_RTTI OFF`, `llvm-config --has-rtti` is `NO`: fits |
| release, no assertions | `RELEASE`, assertions `OFF`: fits |
| the clang patches (emulated TLS, atomic calls) | not there; `xlgen` only parses, so it would not need them |

It also builds every target (20 of them, against `ARM;AArch64` here) and needs macOS 14. Using it would mean
relinking `xlate` and `rellume` against the static libraries and `xlgen` against `libclang-cpp` alone, so
the `libraries` build stays.

## The next rebuild batch

Each change below moves a prebuilt key, so each waits for the next local build of llvm, swift or swift-runtime.
Until that build fills the store, the old key stays as the old store entry has it.

- **The byte-order sort in the buildhash is done** (xmake patch 0025, [decision 0017](../explanation/decisions/0017-build-hash-sorts-by-byte.md)):
  every key moved with it, `xmakew` no longer pins `LC_COLLATE`, and the releases of llvm, swift, ld64, libcxx and
  swift-runtime of the earlier keys do not serve any more.
- **The llvm package has no libLTO.** Neither llvm configuration installs `libLTO.dylib`: the default installs clang
  alone, and the `libraries` configuration's distribution components do not list LTO. A link with `-flto=thin` then
  fails, because the linker cannot load the library for the bitcode objects it reads, so every LTO link fails. The
  recipe now installs `libLTO.dylib` in both configurations, and its key takes the iPhoneOS SDK's recipe digest too,
  since the iOS builtins are compiled against that SDK. Both changes are one llvm key move, and the released llvm key
  is the one before them. Until that rebuild the engine's configure fails its compiler check, and nothing strips the
  flag to work around it.
