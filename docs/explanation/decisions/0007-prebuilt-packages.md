# 0007: Prebuilt packages, and the keys that name them

Status: accepted

## Context

Some packages (llvm, swift, ld64, and the Swift runtime) take hours to build. A machine can fetch them from a
release of a repository instead, if the release was built from the same inputs.

## Decision

With `REVENANT_PREBUILT=<owner/repo>`, a package is fetched from that repository's release before it is built.
The release tag is `prebuilt-<name>-<key>`, and the asset is `<name>-<key>-<plat>-<arch>.tar.xz`.

The key is computed from the package's inputs (`toolchain/modules/prebuilt.lua`, `key()`), so the key changes
exactly when an input does. A package with no release for its key is built from source, unless
`REVENANT_PREBUILT_ONLY` names it, in which case the build stops rather than building. `REVENANT_PREBUILT_TRACE=1`
prints the key of each package, which is how a key is checked.

## Consequences

- A change to a recipe's inputs moves its key; the old release stays where it is.
- A release is made by `.github/workflows/prebuilt.yml`, with the `package` input, on `macos-26`.
- Keys in use are listed in `docs/guides/prebuilt.md`; a package with no release is said so there.
- The keys depend on the collation `./xmakew` sets; see [0010](0010-collation-of-xmake.md).

## Enforced by

`digest_test` (`toolchain/tests/addon/digest_test.lua`) keeps each recipe's `port/digest.lua` equal to what its
sources give, so the digests that feed the key move with the inputs.

## Not enforced

That a published release carries the key the current sources give. `REVENANT_PREBUILT_TRACE=1` shows it when
someone runs it; no test does. The key function itself has no test.
