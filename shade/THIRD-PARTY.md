# Third-party components

Nothing third-party is kept in this tree: every component is an xmake package the build installs.

## Pinned in hades' `third_party` package repository

| Component | Version | License | Copyright | Package |
| --- | --- | --- | --- | --- |
| Dynarmic | MC-XiaoXiao/dynarmic at the pinned commit, with our patches | 0BSD | MerryMage and contributors (`LICENSE.txt` in its tree) | `third_party/packages/d/dynarmic` |
| Boost libraries | 1.81.0 release | BSL-1.0 | the Boost authors | `third_party/packages/b/boost` |

Dynarmic builds libraries of its own from its `externals/` (fmt, mcl, oaknut, robin-map), each with
its license; the package installs them beside it.

## From other package repositories

| Component | Version | License | Copyright | Package |
| --- | --- | --- | --- | --- |
| Vulkan Memory Allocator | 3.4.0 | MIT | 2017 - 2026 Advanced Micro Devices, Inc. | xmake-repo `vulkan-memory-allocator`, unmodified single header |
| SwiftShader | 2026.09.16 | Apache-2.0 | The SwiftShader Authors | charon `swiftshader`, `libvk_swiftshader.dylib` placed beside the program |

OpenSSL and libplist come from charon's packages, libpng, libjpeg-turbo, the Vulkan headers and
loader and the glslang library (the shader compiler of `tools/glsl`) from xmake-repo; SDL2 and FFmpeg are optional. Each package carries its license.

A binary built from this tree carries the notices above with it; the MIT,
BSD-3-Clause and BSL texts require that. `NOTICE` is the summary to ship.
