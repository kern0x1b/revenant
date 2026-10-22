# Prebuilt packages

Status: on in CI. The `checks`, `backports` and `swift` jobs of `.github/workflows/check.yml` set
`REVENANT_PREBUILT=kern0x1b/revenant`, and the recipes wired to the module (below) take the package of their key from its
release. Releases exist for `llvm`, `swift` and `ld64`. None exists yet for `libcxx` or `swift-runtime`, which the swift job
requires by name, so that job stops at its configure until one is released.

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
nothing is built from source. The jobs of `check.yml` set it (the swift job also names `swift-runtime` and `libcxx`), so a
build there can never fall back to LLVM, Swift or ld64. It changes no key.

The `llvm`, `swift`, `ld64`, `swift-runtime` and `libcxx` recipes are wired. To wire another recipe, call
`prebuilt.fetch(package)` at the top of its `on_download`, `prebuilt.install(package)` in its `on_install` and
`prebuilt.pack(package)` at its end. `swift-runtime` sets its environment and data before the install call, since an
early return would skip them. Doing that changes the recipe, and so the key, once.
The `shared` configs of `swift-runtime` and `libcxx` are not wired: they stage packages that an early return would
skip, so those builds come from source. The Backports targets are not packages, so they are not affected.

A recipe is archived only when it calls `prebuilt.pack`, so a job that builds one has nothing to release unless
its recipe is wired. The prebuilt workflow configures the iOS Swift component before it requires `swift-runtime` or
`libcxx`, so the released key is the one the swift job looks up.

## On CI

`.github/workflows/prebuilt.yml` runs only when someone starts it (`workflow_dispatch`): there is no push,
schedule or pull request trigger. It runs on `macos-26`, which is arm64, and builds one package per run, chosen by its
`package` input: `llvm`, `llvm-libraries` (`llvm` with its `libraries` config), `swift`, `swift-runtime`, `libcxx` or `ld64`:

1. `./xmakew` builds the pinned xmake.
2. `./xmakew require -P . -y revenant@<package>` runs with `REVENANT_PREBUILT` set to the repository, so a
   key that is released already is downloaded and not built, and with `REVENANT_PREBUILT_OUT`, so
   `prebuilt.pack` writes the archive, its checksum and its release tag.
3. For each tag that has no release yet, `gh release create` makes a prerelease with the archive.

`prebuilt.pack` refuses an install that names its own install folder in a file or a symbolic link, since
that archive would not work under another one.

## What CI cannot use, or uses differently

| Input | On CI | Consequence |
| --- | --- | --- |
| The iPhoneOS SDK (`iphoneos-sdk`) | downloaded from the same GitHub releases as on a machine | works; the SDK itself is never put in an archive, since Apple's licence does not allow that |
| Firmware and `~/.revenant/dyld` (`frameworks/Backports`) | not there; `firmware.ensure` would fetch and decrypt gigabytes of firmware | the Backports targets, and `swift-runtime` with `backports`, are not built on CI |
| The host Xcode or Command Line Tools | the runner's Xcode, not this machine's | not part of the key: an archive built with another host clang is used under the same key. LLVM and Swift do not link against the host's C++ library in a way a newer macOS breaks, but that is not verified |
| Time and disk | a GitHub-hosted job ends after 6 hours, and the runner has a fixed number of cores and a fixed disk | not measured on `macos-26`: Swift's ten source checkouts and its build may need more disk or time than a hosted runner has, and then need a larger runner or a self-hosted one; LLVM with two targets may fit |
| `~/.revenant/cache` | empty on each run | the pinned xmake and the store are built again on each run; `actions/cache` could keep them |

## Releasing a package

The owner releases a package by starting the workflow for it from the Actions tab, with its `package` input. Each run
builds one key and makes its release. Every later run and machine that sets `REVENANT_PREBUILT` and has the same key
downloads that release, so the key is never built twice. Wiring another recipe changes its key once (see "On a machine").

Verified: the workflow has run and released `llvm`, `swift` and `ld64`, and the checks job downloads them on each CI run.
Not yet verified: a release of `libcxx` or `swift-runtime`, which the swift job waits for, and which runner LLVM and Swift fit on.

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
- **The text of the swift-runtime overlay patch.** `packages/s/swift-runtime/patches/overlays/` holds a patch whose
  description names `coordination/crutches.md`, a folder that no longer exists. Changing the text changes the patch's
  `sha256`, which the swift-runtime recipe checks, and so the key. The text is corrected in the same rebuild.
