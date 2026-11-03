# Prebuilt packages

Status: with `REVENANT_PREBUILT=kern0x1b/revenant` set, the recipes wired to the module (below) take the package of their
key from its release. Releases exist for `llvm`, `swift`, `ld64`, `libcxx` and `swift-runtime`.

## What it is for

LLVM and Swift take hours to build from source, and every machine and every change to their recipes builds
them again. A prebuilt archive is built once for a key, on a GitHub runner, and attached to a release named
by that key. A machine whose recipe gives the same key downloads the archive instead of building.

## The key

`toolchain/modules/prebuilt.lua` computes it from:

- the name, the version, the platform and the architecture;
- the package's build hash: its configs, including the readonly digest configs (`recipe`, `sources`),
  which change exactly when the files that make the output change, and its toolchain names;
- the name and build hash of each library dependency, since a library built against another build of a
  dependency is another library.

The release is named `prebuilt-<name>-<key>`, and its asset is `<name>-<key>-<plat>-<arch>.tar.xz` with a
`.sha256` beside it. A changed recipe or patch is a new key and so a new release; an unchanged one is
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

A recipe is archived only when it calls `prebuilt.pack`, so a job that builds one has nothing to release unless
its recipe is wired.

## Releases

There is no CI, so nothing makes a new release. A release that exists is fetched when `REVENANT_PREBUILT` is set and the key matches; a package whose key moved is built locally. `prebuilt.pack` refuses an install that names its own install folder in a file or a symbolic link, since that archive would not work under another one.

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

Each change below moves a prebuilt key, so each waits for the next planned rebuild of llvm, swift or swift-runtime,
when the releases are rebuilt anyway. Until then the key stays as the release has it.

- **A byte-order sort in the buildhash.** xmake sorts a package's configuration strings with `table.sort`, which
  compares with the locale's collation. `xmakew` pins `LC_COLLATE` to `en_US.UTF-8` so that every machine hashes as the
  released keys did. The change is to sort those strings byte by byte, which removes the pin. The orders differ for
  some names, so the keys move, and the pin is removed in the same commit as the rebuild.
- **The llvm package has no libLTO.** Neither llvm configuration installs `libLTO.dylib`: the default installs clang
  alone, and the `libraries` configuration's distribution components do not list LTO. A link with `-flto=thin` then
  fails, because the linker cannot load the library for the bitcode objects it reads, so every LTO link fails. The
  recipe now installs `libLTO.dylib` in both configurations, and its key takes the iPhoneOS SDK's recipe digest too,
  since the iOS builtins are compiled against that SDK. Both changes are one llvm key move, and the released llvm key
  is the one before them. Until that rebuild the engine's configure fails its compiler check, and nothing strips the
  flag to work around it.
