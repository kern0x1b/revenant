---
name: xmake-packages
description: Reference for the dependencies of an old-iOS app built with Charon and xmake 3.1.1 — how the tag pair splits into the addon and the package repository, requiring charon@ packages under an alias with configs, which packages the repository carries at the pin, inspecting what the project resolves with xmake require --info and xmake where, the lock files and moving to a new tag with xmake require --upgrade, a C library Charon does not carry through a project recipe that calls Charon's CMake or sources bridge (and the revision config that gives a changed recipe a new install path), and what decides an install path in the shared store. Use when adding, inspecting or upgrading a dependency, writing a recipe for a third-party library, or when a package fails to install or resolves differently than expected.
---

Derived from the `xmake-packages` and `xmake-addons` skills of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# Packages and the Charon pin

Two things come from Charon's repository at one release: the **addon** (`v<X>`: toolchain, rules,
checks, commands), installed once per machine under `~/.xmake/addons/charon/<version>/`, and the
**package repository** (`charon-repo-<X>`: the `charon@…` recipes), cloned into the project's
`.xmake/`. Packages are built once per distinct set of inputs into the shared store
`~/.xmake/packages` and reused by every project. Read `PROJECT.md` first: the language and the
backports it lists decide which packages the app needs.

The pin itself (finding `<X>`, the two lines, checking the addon in use, the lock naming another
version) is the skill `install`'s (steps 3–6 and its first trap) and the skill `build`'s ("The
addon in use is not the one pinned"). The first-build cost is the skill `install`'s (step 6).

## 1. Require a Charon package

```
add_requires("charon@<package>", {alias = "<package>", configs = {…}})
```

and on the target `add_packages("<package>")`. Always give the alias: the target, values such as
`charon.libraries`, and Charon's own lookups name a package by it. For the backports the alias is
exactly `apple-backports`, and their configs are the skill `backports`'s.

At `charon-repo-0.8.10` the repository has 18 packages. What a project requires itself, by
purpose: `apple-backports` (newer API), `apple-compat` (functions the release lacks, linked
hidden into the image), `libcxx` (the C++ runtime an app bundles), `openssl` (TLS and crypto,
also built for the device), `swift-runtime` and `swift-embedded` (Swift), `styx` (Combine, skill `combine`). The
rest come with Charon's includes or as their dependencies: `llvm`, `ld64`, `ldid`, `libplist`,
`iphoneos-sdk`, `firmware-tools` (the toolchain), `swift`, `swift-bootstrap` (the Swift compiler),
`shade`, `swiftshader`, `emulator-guest` (the emulator). There is no SwiftUI package at
this pin: say so to the user rather than looking for one (skill `swiftui`). List them in the project's clone:
`ls .xmake/macosx/arm64/repositories/charon/packages/*/`.

## 2. Inspect what the project resolves

```
xmake require -y --info 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > .logs/require-info.log
grep -n '^require(' .logs/require-info.log
xmake where <package>
```

- With no package named, `--info` describes the project's own requires, with the project's
  configs, one `require(<the require string>):` block each: `description`, `version`, `repo`
  (with the tag), `deps`, `cachedir`, `installdir`, then the package's `configs` with each
  default and allowed values. A package named on the command line is resolved alone and may not be
  the one the project uses (the skill `install`, step 5, shows how to test an `installdir`).
- `xmake where <package>` takes the name or alias the project requires and prints its install
  folder; any other name is refused with `the project requires no package named <name>; it
  requires <list>`.

How to know it worked: `xmake f -y > .logs/configure.log 2>&1` has no `install failed`; with
`-v`, a build prints for each target `<Name>: N objects and M archive members record iOS
<release>` — every static archive a target links records the release it builds for, and one that
does not is refused (`a link input of <Name> was not built for this target: …`).

## 3. Lock files and a new tag

`set_policy("package.requires_lock", true)` writes `xmake-requires.lock`: for each `plat|arch`,
every require with its version and the repository URL and commit it came from. xmake writes
`xmake-addons.lock` itself for a project with `add_addons`. Commit both (skill `project`).

Moving to a new release `<Y>` is the user's decision (skill `install`, step 3). Then change both
tags to `<Y>` and:

```
xmake require -y -v --upgrade > .logs/upgrade.log 2>&1
xmake f -c -p iphoneos -a armv7 -y > .logs/configure.log 2>&1
```

`--upgrade` with no package named resolves the project's requires past the lock, pulls the
repository, and writes the lock again. Then run the checks of the skill `install` (step 6). A lock
left from the older tag stops the toolchain with `the iphoneos-sdk package has no <path>:
xmake-requires.lock pins a Charon package repository older than this addon; delete the lock, or
run xmake require --upgrade, after moving add_addons to a new tag`. A new tag may install new
builds of the compiler when its recipe changed; that is expected.

## 4. A library Charon does not carry

xmake's own recipes build their CMake projects through `package.tools.cmake`, which does not pass
a custom compiler for `iphoneos`; Charon's `apple-ios` toolchain is not theirs. Write a recipe for
the library in the project's `xmake.lua` (a `package("<name>")` block) whose install script calls
Charon's bridge:

- a CMake project, one call inside `on_install("iphoneos", function (package) … end)`:
  `import("@addon.charon.apple.cmake").install(package, {"-D<OPTION>=OFF"})`. It writes a CMake
  toolchain file from the `apple-ios` toolchain (the `llvm` package's clang, `-target`,
  `-isysroot`, ld64, the SDK) and configures, builds and installs with Ninja. A third argument
  takes `cflags`, `cxxflags`, `ldflags`, `deps`, `targets`, `prune`, `licenses` and more (Charon's
  README, the paragraph on the CMake bridge). The bridge passes `-DBUILD_SHARED_LIBS=OFF`, but a
  project may install a shared library anyway (zlib 1.3.1 installs `libz.a` and `libz.1.dylib`);
  the program then links the `.dylib` and the build refuses it: `(loads @rpath/libz.1.dylib, which
  neither the device nor this build provides)`. Keep the static library:
  `install(package, {…}, {prune = {"lib/*.dylib"}})`;
- a plain list of sources: `import("@addon.charon.apple.sources").static(package, {files = {…}})`
  compiles them into `lib<name>.a` with the toolchain's flags;
- a script that runs make or autoconf itself: pass
  `import("@addon.charon.apple.envs").build(package, …)` as its envs and end with
  `import("@addon.charon.apple.install").finish(package, {…})`.

The recipe names its source with `add_urls` and `add_versions("<version>", "<sha256>")`; take
the digest from the project's release page, or compute it from an archive you downloaded and
checked. Then `add_requires("<name> <version>")` and `add_packages("<name>")`.

When you change the recipe's script, raise a revision it carries:
`add_configs("revision", {default = "2", readonly = true})`. An install path is decided by the
platform, architecture, configs (a read-only one too), the source digests and the toolchain,
under the version's folder; the script itself is not part of it, so without a new revision the
changed script never runs against the old install. Measured: with `revision` raised, the next
`xmake f -c -y -v` printed `=> install <name> <version> .. ok` again.

How to know it worked: the configure log has `=> install <name> <version> .. ok`, and a `-v`
build counts the library's members among the archive members that `record iOS <release>`
(`<Name>: 1 objects and 15 archive members record iOS 6.0` for a daemon on zlib), then the
`imports:` line and `build ok`.

## 5. The shared store

A changed input is a new install path beside the old one: nothing is rebuilt in place, and nothing
in the store is ever forced or deleted (the rules for every step, skill `psychopomp`). A cached
resolution does not see a change in the package repository or in a require's configs:
`xmake f -c` with every choice given (skill `xmake-basics`, step 3) resolves again.

## Traps

- A package from xmake's own repository required for the device (`add_requires("zlib")`) → a
  project recipe through Charon's bridge (§4). Reason: xmake's recipe does not build with Charon's
  toolchain; the configure log shows `error: toolchain(apple-ios) needs the SDK and llvm packages
  and apple_minimum; includes("@addon/charon/apple-ios") provides them` and `=> install zlib
  <version> .. failed`.
- Naming `charon@<package>` in `add_packages`, `charon.libraries` or `xmake where` → the alias.
  Reason: the project knows the package by the alias its require gave it.
- `xmake require --info <package>` to see what the project uses → `xmake require -y --info` with
  no name. Reason: a named package is resolved alone, without the project's configs.
- Editing a project recipe's script and expecting a rebuild → raise its `revision` config.
  Reason: the script is not part of the install path.
- Moving one of the two tags, or pinning two different `<X>` → both, together. Reason: the
  `charon-repo-<X>` tag is the one that lists `v<X>` (skill `install`, step 3), and a package
  repository older than the addon is refused by its toolchain (§3).
