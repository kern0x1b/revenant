# Third-party components

## Bundled in the tree

| Component | Version | License | Copyright | Where |
| --- | --- | --- | --- | --- |
| Umbra | this project's own core | 0BSD | see its `LICENSE` | `external/umbra`, a submodule |
| Boost libraries | 1.81.0, trimmed | BSL-1.0 | the Boost authors | `external/ext-boost`, a submodule |
| Vulkan Memory Allocator | 3.4.0 | MIT | 2017 - 2026 Advanced Micro Devices, Inc. | `external/vulkan-memory-allocator`, unmodified single header |

Umbra vendors libraries of its own, listed in its `THIRD-PARTY.md`. Each vendored
tree keeps its license file and notices; do not edit them in place.

## Linked, not bundled

OpenSSL, libpng, libjpeg-turbo and libplist are linked; SDL2 and FFmpeg are
optional. When Shade is built through Charon these come from Charon's own packages,
which carry their licenses.

A binary built from this tree carries the notices above with it; the MIT,
BSD-3-Clause and BSL texts require that. `NOTICE` is the summary to ship.
