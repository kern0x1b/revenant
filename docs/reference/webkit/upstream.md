# What belongs upstream, not here

Every fix this port carries that is not about iOS 6 is a fix it will carry
forever unless it goes back to WebKit. This file is the list of those, kept as
they are found, so they can be sent as one batch rather than remembered.

The test is simple: **would this be a bug for someone with no interest in iOS 6?**
If yes, it is upstream's.

## Open

### `PAS_BMALLOC` is forced on for 32-bit CMake builds

- **Where:** `Source/bmalloc/CMakeLists.txt`, `add_definitions(-DPAS_BMALLOC=1)`,
  unconditional. Still unconditional on `main` as of 2026-09-11.
- **What is wrong:** `Source/bmalloc/bmalloc/BPlatform.h` enables libpas, and
  defines `PAS_BMALLOC` with it, only when `BCPU(ADDRESS64)`. A 32-bit CMake
  build therefore compiles bmalloc with the header saying libpas is off and the
  command line saying the bmalloc-replacement macro is on.
- **Symptom:** the process aborts during startup, before it can print anything.
- **Who it affects:** anyone building a CMake port for 32-bit. WebKitGTK and WPE
  still build for 32-bit ARM, so this is not a museum case.
- **Fix, one line:** wrap it in `if (CMAKE_SIZEOF_VOID_P EQUAL 8)`, which is the
  same gate the header uses.
- **Carried here as:** `e59f29120a11` on this fork's `main`.

### libpas is compiled for 32-bit targets, and cannot be

- **Where:** `Source/bmalloc/CMakeLists.txt` lists every `libpas/src/libpas/*.c`
  unconditionally.
- **What is wrong:** libpas is 64-bit only - `pas_utils.h` uses `__uint128_t`,
  which a 32-bit compiler does not have - and `BPlatform.h` says as much by
  gating `BENABLE(LIBPAS)` on `BCPU(ADDRESS64)`. The source list does not.
- **Symptom:** `error: unknown type name '__uint128_t'` in `pas_mte.c`, before
  anything else is built. `USE_SYSTEM_MALLOC=ON` does not avoid it: the sources
  are compiled either way.
- **Fix:** wrap the `libpas` entries in `if (CMAKE_SIZEOF_VOID_P EQUAL 8)`, the
  same gate the header uses. Same family as the `PAS_BMALLOC` item above and
  probably the same patch.

## Not upstream's, though it looks like it

### `DFGSpeculativeJIT32_64.cpp` missing `#include "JSSet.h"`

Real, and fixed here, but there is nowhere to send it: `main` deleted that file
along with the rest of the 32-bit JIT on 2026-08-01. It exists only on the
`webkitglib` series and in forks like this one.
