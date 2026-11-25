# 0020: A package's key follows how its strict dependencies differ from their defaults

Status: accepted.

## Context

xmake's build hash holds a package's own configuration, sources, patches and toolchain, and nothing about its
dependencies. A dependency with the policy `package.strict_compatibility`, which our libraries set, makes what depends
on it be installed again when it changes, into the same folder. A project that asks `libcxx` to be `packaged`
(`add_requireconfs("**.libcxx", ...)`) therefore rewrote `boringssl`, `folly` and every other dependent of `libcxx`
in the shared store under the key another project reads, and a build could read a package compiled against the other
variant of the library. The two projects reinstalled each other's packages by turns.

Not every dependent differs. Built against the plain and the packaged `libcxx`, the object files of the static
libraries are byte for byte the same (`double-conversion`, `fmt`, `glog`, `boringssl`, `zxing-cpp`, `leptonica`,
`tesseract`). What differs is a linked image, which holds the path it loads `libc++` from, and a file that records where
the dependency is (`boringssl`'s `share/revenant/runtime-archives`, which the TLS backport links from).

## Decision

xmake patch `0026-Put-how-a-package-s-strict-dependencies-differ-into-its-hash.patch` adds a term to the hash of a
dependent. For each of its library dependencies the term holds the configurations of a strict one that differ from
their declared defaults, and the term that dependency has itself, so the difference travels up the chain. Three things
add nothing:

- a configuration the dependent asks of the dependency in its own `add_deps`, which its recipe and its own
  configuration already stand for;
- a configuration xmake handed down from the dependent: `runtimes` and `pic` to a dependency that is not shared,
  `lto` and `asan`. A configuration of the same name and value as one of the dependent's is otherwise the project's
  choice and is a part of the term;
- a configuration with no declared default (`apple_sdk`), which a project always names and which therefore differs
  from nothing.

A boolean configuration declared with `images_only = true` matters only to what links an image or records where the
dependency is. `libcxx`'s `packaged` is declared so. It is a part of the key of a binary package, of a package with the
configuration `shared`, and of a package with the policy `package.links_dependencies`, which `boringssl`,
`swift-runtime`, `webkit-engine`, `tesseract` and `zxing-cpp` declare. Every other dependent keeps one key under both
values and is not installed again when only that configuration differs: its manifest records the dependency's key
without such configurations, and a manifest written before that record is accepted under either value.

A package whose dependencies are built as it asks keeps the key it had. The patch declares `Changes-build-output: no`,
which keeps it out of the patch set digest.

## Consequences

- Under `whole`, where the root project asks `libcxx` to be `packaged`, the five packages that declare the policy get
  a key of their own and are built once. The static libraries are shared with the plain configuration.
- `tesseract` and `webkit-engine` hold a digest of their own recipe in their configuration, so the line that declares
  the policy moves their keys in the plain configuration too, once. The other keys of a plain project do not move.
- A dependent that does not link keeps `.pc` files, which xmake writes, naming the `libcxx` folder of the install
  that came first. Nothing reads them: xmake takes a package from its manifest, and the one recipe that calls
  `pkg-config` gives it files of its own.
- Two projects that name different iPhoneOS SDKs still share the keys of what depends on `apple-compat` and reinstall
  it by turns, because `apple_sdk` has no default. A machine builds with one SDK today. If a second SDK appears, the
  term takes the configurations with no default as well; that moves the keys of what depends on `apple-compat` once
  (45 of the 189 rows of the key snapshot of 2026-11-25).
- The hash is computed again after the dependencies are loaded, which is after `on_load`. The manifest and the
  environments read before that are read again from the folder of the new key. A recipe that reads
  `package:buildhash()`, `package:installdir()` or `package:manifest_load()` in `on_load` still sees the value without
  the term; `swift-runtime` takes its link mark there, so a runtime built against another `libcxx` than it asks for
  carries the mark of the plain one.

## Enforced by

The patch fails the installation of a package which installs an image that loads a library of a dependency with an
`images_only` configuration and declares nothing.
`toolchain/tests/addon/dependency_keys_test.lua` installs fixture packages for projects that differ in one
configuration of a strict dependency. It requires separate keys for the dependents that differ, one key and no second
install for those that do not, the term of a configuration that shares its name with one of the dependent, the manifest
and the environments of the variant, a build that reads the variant its project asked for, and the failure of an image
that nothing declares.
`toolchain/tests/addon/dependency_images_test.lua` loads the recipes of the repository with the plain and the packaged
`libcxx` and requires the five keys to differ and those of the static libraries to be the same.

## Not enforced

That a new recipe which records a dependency's path in a file, and links no image, declares
`package.links_dependencies`: without it the two configurations share its folder. That a recipe does not read its key,
its folder or its manifest in `on_load`.
