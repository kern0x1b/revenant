# 0020: A package's key follows how its strict dependencies differ from their defaults

Status: accepted.

## Context

xmake's build hash holds a package's own configuration, sources, patches and toolchain, and nothing about its
dependencies. A dependency with the policy `package.strict_compatibility`, which our libraries set, makes what depends
on it be installed again when it changes, into the same folder. A project that asks `libcxx` to be `packaged`
(`add_requireconfs("**.libcxx", ...)`) therefore rewrote `boringssl`, `folly` and every other dependent of `libcxx`
in the shared store under the key another project reads, and a build could read a package compiled against the other
variant of the library. The two projects reinstalled each other's packages by turns.

## Decision

xmake patch `0026-Put-how-a-package-s-strict-dependencies-differ-into-its-hash.patch` adds a term to the hash of a
dependent. For each of its library dependencies the term holds the configurations of a strict one that differ from
their declared defaults, and the term that dependency has itself, so the difference travels up the chain. Three things
add nothing:

- a configuration the dependent asks of the dependency in its own `add_deps`, which its recipe and its own
  configuration already stand for;
- a configuration the dependency inherited from the dependent's own configuration;
- a configuration with no declared default (`apple_sdk`), which a project always names and which therefore differs
  from nothing.

A package whose dependencies are built as it asks keeps the key it had, so no key of a project that overrides nothing
moves. The patch declares `Changes-build-output: no`, which keeps it out of the patch set digest.

## Consequences

- Under `whole`, where the root project asks `libcxx` to be `packaged`, every dependent of `libcxx` gets a key of its
  own and is built once.
- Two projects that name different iPhoneOS SDKs still share the keys of what depends on `apple-compat` and reinstall
  it by turns, because `apple_sdk` has no default.
- The hash is computed again after the dependencies are loaded, which is after `on_load`. A recipe that reads
  `package:buildhash()` or `package:installdir()` in `on_load` sees the value without the term; `swift-runtime` takes
  its link mark there, so a runtime built against another `libcxx` than it asks for carries the mark of the plain one.

## Enforced by

`toolchain/tests/addon/dependency_keys_test.lua` installs fixture packages for projects that differ in one
configuration of a strict dependency and requires separate keys for the dependents, unchanged keys where nothing
differs, and a build that reads the variant its project asked for.

## Not enforced

That a new recipe does not read its key or its folder in `on_load`.
