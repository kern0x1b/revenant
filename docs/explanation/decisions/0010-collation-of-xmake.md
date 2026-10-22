# 0010: xmake sorts with the collation `./xmakew` sets

Status: accepted

## Context

xmake's buildhash sorts a package's configuration strings with `table.sort`, and Lua compares strings with
`strcoll`, so the order depends on the process locale. `backports` and `backports_uikit` sort one way under
`en_US.UTF-8` and the other way under `C.UTF-8`. The released keys were computed on macOS runners under
`en_US.UTF-8`, so a shell in `C.UTF-8` computed another swift-runtime buildhash, and so looked for a key nobody
had released.

## Decision

`./xmakew` sets `LC_COLLATE=en_US.UTF-8` before it runs xmake, so every machine that goes through the one entry
point (ADR 0003) sorts the way the released keys were computed.

## Consequences

- A developer's machine and CI compute the same keys for llvm, swift, ld64, libcxx and swift-runtime, so a local
  build fetches the released prebuilts instead of building them.
- A process that runs xmake directly, without `./xmakew`, still sorts by its own locale, and can compute a
  different buildhash. Run xmake through `./xmakew`.
- The pin is a rule until the real fix lands: byte-order sorting in xmake's buildhash (through the xmake patch
  set). That moves every key, so it waits for the next planned rebuild of llvm and swift.
- The pin needs `en_US.UTF-8` on the machine. Without it the sort falls back to the C order without an error.

## Enforced by

Not yet. A repository test that reads `xmakew` and fails when the pin is missing would enforce it; none exists.

## Not enforced

That `xmakew` pins the collation, and that the machine has `en_US.UTF-8`. Both are checkable by running the
prebuilt trace (`REVENANT_PREBUILT_TRACE=1`) and comparing keys with a release.
