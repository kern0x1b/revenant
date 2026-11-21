# 0017: xmake's build hash sorts by byte

Status: accepted. Supersedes [0010](0010-collation-of-xmake.md).

## Context

A package's build hash sorts the strings it hashes (its configuration strings, the hashes of its sources, its
toolchain names and the addons a project pins) with `table.sort`, and Lua compares strings with `strcoll`, so the
order, and with it the hash, depended on the process locale. `backports` and `backports_uikit` sorted one way under
`en_US.UTF-8` and the other under `C.UTF-8`. Decision 0010 pinned `LC_COLLATE` in `./xmakew` so that every machine
computed the keys the releases were made with, and kept the pin until the sort itself was fixed. A process that ran
xmake without `./xmakew`, or an environment with another locale, still computed a key that nobody had released.

## Decision

xmake patch `0025-Sort-the-strings-of-a-build-hash-by-byte-not-by-collation.patch` sorts those strings with a
comparison of their bytes, which is the same in every locale. The pin is removed from `./xmakew`. The patch declares
`Changes-build-output: yes`, so it moves the patch set digest and with it every package key once; the keys of the
prebuilt releases made before it are replaced by new ones (llvm, swift, ld64, libcxx, swift-runtime).

## Consequences

- A machine computes the same key under any locale, with or without `./xmakew`.
- Every key moved at once, in the same change as the next rebuild of llvm, swift and swift-runtime, so the releases
  were rebuilt once and not twice.
- A recipe or a test of ours that sorts strings with `table.sort` for something that is hashed or compared across
  machines has the same locale dependence: `table.sort(list, function (a, b) return a < b end)` is not byte order
  either, since `<` on strings is `strcoll`.

## Enforced by

`toolchain/tests/addon/patch_set_test.lua` keys one fixture package, whose configs sort differently under
`en_US.UTF-8` and `C`, under four locales and requires one hash. `repository/layout` requires that `xmakew` pins no
collation.

## Not enforced

The sorts of xmake outside the build hash, and the sorts in our own modules.
