# Third-party components

## Bundled in the tree

| Component | Version | License | Copyright | Where |
| --- | --- | --- | --- | --- |
| Vulkan Memory Allocator | 3.4.0 | MIT | 2017 - 2026 Advanced Micro Devices, Inc. | `external/vulkan-memory-allocator`, unmodified single header |

Each vendored tree keeps its license file and notices; do not edit them in place.

## Pinned, not bundled

| Component | Version | License | Copyright | Pin |
| --- | --- | --- | --- | --- |
| Dynarmic | MC-XiaoXiao/dynarmic at the pinned commit, with our patches | 0BSD | MerryMage and contributors (`LICENSE.txt` in its tree) | `../third_party/dynarmic` |
| Boost libraries | 1.81.0 release | BSL-1.0 | the Boost authors | `../third_party/boost` |

Their sources are prepared under `../.deps/` from the pins; Dynarmic vendors libraries of its own
in its `externals/`, each with its license.

## Linked, not bundled

OpenSSL, libpng, libjpeg-turbo and libplist are linked; SDL2 and FFmpeg are
optional. When Shade is built through Charon these come from Charon's own packages,
which carry their licenses.

A binary built from this tree carries the notices above with it; the MIT,
BSD-3-Clause and BSL texts require that. `NOTICE` is the summary to ship.
