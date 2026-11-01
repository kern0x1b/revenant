# GLSL ES 3.00 to GLSL ES 1.00: the translator prototype, measured

This page records the first measured run of the translator that expo-gl's ES 3.00 shaders need on the iPhone 4S driver,
which accepts GLSL ES 1.00 only (`docs/reference/backports/opengles-es3.md`). The chain is glslang (front end, GLSL ES
3.00 to SPIR-V), then SPIRV-Cross (back end, SPIR-V to GLSL ES 1.00). Everything here is run on the host, except where
it says otherwise.

## Versions

| Part | Pin | Source checked |
| --- | --- | --- |
| three.js (the corpus) | 0.187.0 | npm tarball `ff540832ded0cfe919764d24a3d88f3e2a05f23303f876423e4f893841e90728`. expo-three 8.0.0 lists three as a peer, so no version is pinned by it |
| glslang (front end) | `b5782e52`, 1.4.335+0 (glslang 16.1.0 by its own numbering) | `6c242598c332050bf3a3619d299594ca2909426935f2c86c69c7356b049347c7`; the emulator's pin |
| SPIRV-Cross (back end) | `2de1265f`, 1.3.268+0 | `3dcd276a804ad4f32543ddd45a88f28ccdaab59c05b51b6a2965f7390ef2d673` |

The packages are `packages/g/glslang` (two patches) and `packages/s/spirv-cross`. The host run also used the Homebrew
glslang 16.6.0 for the first round; its results match the pinned build (see below).

## The corpus

three.js does not write its shaders as one text: `WebGLRenderer` adds a prefix (`#version 300 es`, the `attribute` and
`varying` macros, the fragment output) and expands `#include` chunks. The corpus is what three hands to `gl.shaderSource`,
so it is the real ES 3.00 text, not a copy of its shader files.

The captured text is committed in `frameworks/ReactNative/tests/glsl_translator/corpus/` (six files, 133937 bytes). The
capture itself was a Node script run with three's `WebGLRenderer`, passed a recording WebGL2 stub as its context. The
script is not in the tree, because the repository's layout allows no scripts beside `./xmakew`; it is recorded here and
can be rewritten in Lua if the capture must be repeated. The scene has three programs:

- `meshbasic`: `MeshBasicMaterial`;
- `meshstandard`: `MeshStandardMaterial` with one directional light;
- `instanced-shadermaterial`: a `ShaderMaterial` on an `InstancedMesh` with two instances.

The stub returns the ES 3.00 version strings and compile and link success. Its other answers are zero, so the captured
source depends on the parameters the scene sets, not on a real device.

## Pipeline and results

`./xmakew l -P . frameworks/ReactNative/tools/glsl_translator.lua <spirv-cross> <glslang> <outdir>` runs each committed
stage through:

1. a rename of the user function `average(` to `revenant_average(`, because glslang rejects the name (below);
2. glslang's ES 3.00 validation (`glslangValidator -S <stage>`);
3. a copy with `#version 310 es`, because glslang's SPIR-V path accepts ES only from 3.10;
4. `glslangValidator -G --aml`, the OpenGL SPIR-V output with automatic uniform locations;
5. `spirv-cross --es --version 100`;
6. glslang's ES validation of the ES 1.00 output.

| Program (stage) | ES 3.00 validates | SPIR-V | ES 1.00 bytes | ES 1.00 validates |
| --- | --- | --- | --- | --- |
| meshbasic (vertex) | yes | yes | 472 | yes |
| meshbasic (fragment) | yes | yes | 1464 | yes |
| meshstandard (vertex) | yes | yes | 736 | yes |
| meshstandard (fragment) | yes | yes | 11740 | yes |
| instanced-shadermaterial (vertex) | yes | yes | 457 | yes |
| instanced-shadermaterial (fragment) | yes | yes | 269 | yes |

All six pass on the host with the pinned glslang build. The first round, with the Homebrew glslang 16.6.0, gave the same
byte counts.

## What the measurement found

- **`average` is rejected by glslang.** Both 16.1.0 and 16.6.0 report `'average' : function name is redeclaration of
  existing name` for three's `float average(const in vec3 v)`. The reason in the GLSL specification was not checked, so
  the pipeline renames the identifier, and the rename is the only source change. If it is a glslang bug, the rename
  stays until the front end is fixed.
- **glslang's SPIR-V path accepts ES 3.00 only as 3.10.** The copy is the only text change that is not a rename. ES 3.10
  adds features that three's shaders do not use.
- **Non-opaque uniforms outside a block need explicit locations** unless `--aml` maps them automatically.
- **Vulkan semantics refuse these shaders**, so the OpenGL mode (`-G`) is the one used.
- **The ES 1.00 outputs begin with `#version 100`** and pass glslang's ES 1.00 validation. Their sizes run from 269 bytes
  (the instanced fragment) to 11740 (the standard fragment).

## Building for the iPhone 4S (armv7, iOS 6.0)

Syntax checks against the iPhoneOS 26.2 SDK with `-target armv7-apple-ios6.0` and `-std=c++17`:

- `spirv_glsl.cpp` (SPIRV-Cross): passes.
- glslang: 38 of 39 core files pass (`GenericCodeGen`, `MachineIndependent`, its preprocessor, `SPIRV`, and `ossource.cpp`).
  The 39th is `PoolAlloc.cpp`, which uses `thread_local`, not supported on iOS 6 armv7.
- `InfoSink.h` uses `std::filesystem::absolute`, which the SDK marks iOS 13. Patch 0001 prints the name as given.
  The effect is on the `absolute` diagnostic only: error locations are not absolute paths.
- `PoolAlloc.cpp` with `-DDISABLE_THREAD_SUPPORT` (the package adds it for iOS) returns the address of a stack local
  in its no-thread path. Patch 0002 gives that local static storage, so the pointer outlives the call.
- glslang needs `glslang/build_info.h` from `build_info.h.tmpl`, which CMake writes; the xmake build must generate it.

## Risks the review raised, and what they are

An automated review of the commit flagged three upstream glslang paths. Their status:

- **`PoolAlloc.cpp`, dangling pointer in the no-thread path.** Real, and in upstream code: with `DISABLE_THREAD_SUPPORT`,
  the default allocator was a stack local. Patch 0002 makes it static, which the review's suggested fix matches.
- **`PoolAlloc.cpp`, integer overflow in `allocationSize + headerSkip`.** Real, in upstream code. Patch 0003 makes a
  request over `SIZE_MAX / 4` return nullptr, the allocator's own failure value, before any sum. The unpatched allocator
  segfaults on a request of `SIZE_MAX - 8` (exit 139), and the patched one passes. The test is
  `frameworks/ReactNative/tests/glsl_translator/poolalloc_overflow.cpp`, built with `clang++ -std=c++17` against the
  glslang sources and `PoolAlloc.cpp` with patches 0002 and 0003. The translator also rejects a source over 1 MiB
  (`MAX_SOURCE_BYTES` in `tools/glsl_translator.lua`); an oversized shader is reported, not compiled.
  Patch 0004 covers the typed wrapper `pool_allocator<T>`, which multiplies `n * sizeof(T)` before the allocator sees it:
  a count over `max_size()` now returns nullptr, and the test checks it (the pristine tree segfaults on it, exit 139).
  Caller behavior: glslang's pool `operator new` (`Common.h`) passes the nullptr through unchecked, as it already does on
  out-of-memory. A refused request therefore crashes the caller with a null construction, not a heap overflow. A clean
  error needs a throw or a check at each call site, which is not done here.
- **`InfoSink.h`, `std::filesystem::absolute` can throw.** The calls are reached only with the `absolute` diagnostic
  set. Patch 0001 removes them, and the translator never sets that option. Its only effect is the text of error
  locations.

## Not measured yet

- **The device compiler.** The phone is claimed by another worker, so the ES 1.00 outputs have not been compiled by the
  SGX543 driver. That is the acceptance test for this prototype: the six outputs compile on the phone.
- **The rendered result.** The stub renders nothing, so no output image exists yet.
- **The armv7 build.** The syntax checks pass, but no object files are linked, and the thread-free configuration has not
  run on the device.
- **Skia's output.** Not in the corpus (see `docs/explanation/backports/metal-on-ios6.md`, the run-time MSL gap).
