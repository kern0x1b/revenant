# GLSL ES 3.00 to GLSL ES 1.00: the translator prototype, measured

This page records the first measured run of the translator that expo-gl's ES 3.00 shaders need on the iPhone 4S driver,
which accepts GLSL ES 1.00 only. The ES 3.00 context page (`docs/reference/backports/opengles-es3.md`) is on
`work/rn-media-gles2`, not on this branch. The chain is glslang (front end, GLSL ES
3.00 to SPIR-V), then SPIRV-Cross (back end, SPIR-V to GLSL ES 1.00). Everything here is run on the host, except where
it says otherwise.

## Versions

| Part | Pin | Source checked |
| --- | --- | --- |
| three.js (the corpus) | 0.187.0 | npm tarball `ff540832ded0cfe919764d24a3d88f3e2a05f23303f876423e4f893841e90728`. expo-three 8.0.0 lists three as a peer, so no version is pinned by it |
| glslang (front end) | `b5782e52`, 1.4.335+0 (glslang 16.1.0 by its own numbering) | `6c242598c332050bf3a3619d299594ca2909426935f2c86c69c7356b049347c7`; the emulator's pin |
| SPIRV-Cross (back end) | `2de1265f`, 1.3.268+0 | `3dcd276a804ad4f32543ddd45a88f28ccdaab59c05b51b6a2965f7390ef2d673` |

The packages are `packages/g/glslang` (four patches, 0001 to 0004) and `packages/s/spirv-cross`. The host run also used the Homebrew
glslang 16.6.0 for the first round; its results match the pinned build (see below).

## The corpus

three.js does not write its shaders as one text: `WebGLRenderer` adds a prefix (`#version 300 es`, the `attribute` and
`varying` macros, the fragment output) and expands `#include` chunks. The corpus is what three hands to `gl.shaderSource`,
so it is the real ES 3.00 text, not a copy of its shader files.

The captured text is committed in `frameworks/Backports/tests/OpenGLES/glsl_translator/corpus/` (six files, 133937 bytes). The
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

### The xmake build

Both packages build for armv7 with the iPhoneOS 26.2 SDK and a 6.0 deployment target, through the `iphoneos` CMake helper
(`toolchain/modules/apple/cmake.lua`). The translator is part of the `OpenGLESBackports` library, not a separate target:
`frameworks/Backports/tools/library_list.lua` lists `glslang` and `spirv-cross` as archives of that library, and
`frameworks/Backports/tools/subset.lua` maps them to the packages. Sources in `frameworks/Backports/src/OpenGLES/`:

- `RevenantGLSLTranslator.cpp` (the translator, C ABI in `RevenantGLSLTranslator.h`, both internal to the library);
- `RevenantShaderSource.c` (the shader intercept, below).

- `glslang` installs `libglslang`, `libMachineIndependent`, `libGenericCodeGen`, `libOSDependent` and
  `libglslang-default-resource-limits`, with SPIR-V in `libglslang`. It builds with `DISABLE_THREAD_SUPPORT` and without
  HLSL, the SPIRV-Tools optimizer, tests and the standalone binaries. CMake writes `build_info.h`.
- `spirv-cross` installs `libspirv-cross-core` and `libspirv-cross-glsl`; its CLI and the other back ends are off.
- `RevenantGLSLTranslator.cpp` does the translation in process, with the same steps as the CLI pipeline: OpenGL
  semantics, automatic locations, and SPIRV-Cross for ES 1.00. Its two entry points are `revenant_glsl_translate_es300`
  and `revenant_glsl_translation_free`, both hidden (`visibility("hidden")`), so they do not reach apps.

```
REVENANT_CACHE=<private cache> ./xmakew f -P . -p iphoneos -a armv7 --component=Backports -y
REVENANT_CACHE=<private cache> ./xmakew build -P . OpenGLESBackports
```

The private cache must lie outside the checkout (see the finding below). The library builds for armv7 and, among its dependencies, links `libc++`, `libgcc_s.1` (which supplies the SjLj unwinder
the glslang objects use; the `gcc_s.1` entry is the `system` item in `library_list.lua`) and `libSystem`. `OpenGLES` is a
weak dependency. Its exports are the five GL wrappers above; no `revenant_` symbol is exported. Both packages and the translator build, with no warnings from the patched files.

### The shader intercept

`RevenantShaderSource.c` exports five GL entry points with default visibility (`REVENANT_GL_EXPORT`):
`glShaderSource`, `glCompileShader`, `glGetShaderiv`, `glGetShaderInfoLog` and `glDeleteShader`. The system functions
are found with `dlopen` and `dlsym` on the OpenGLES image, never `RTLD_DEFAULT`, following
`docs/explanation/backports-loading.md`.

- `glShaderSource` joins the pieces (honouring `length`, with `-1` meaning NUL-terminated). Only a source whose first
  line is `#version 300 es` (followed by end of text, a newline, a carriage return, a space or a tab) is translated. The
  shader's type decides the stage. A successful translation goes to the driver as the ES 1.00 text. A failed one is
  recorded with its log, and the original text goes to the driver unchanged, so the driver's own error is still
  available.
- `glCompileShader` does not compile a recorded failure. `glGetShaderiv` reports `GL_COMPILE_STATUS` as `GL_FALSE` and
  the log length for it, and `glGetShaderInfoLog` returns the translator's log, truncated to the buffer, with the
  terminator. Any other shader goes to the driver unchanged.
- A new `glShaderSource` or a `glDeleteShader` on a shader forgets its earlier failure.

The intercept is tested with a fake driver on the host (`frameworks/Backports/tests/OpenGLES/glsl_translator/shader_source_test.c`,
16 checks): the corpus vertex shader reaches the fake driver as its expected ES 1.00 text and compiles there; a shader the
translator refuses gives `GL_FALSE` and a log that names the identifier; a version line that only starts like ES 3.00
is passed through; pieces are joined. The host run prints `0 failure(s)`. The host has no OpenGLES header, so the test
was built against a minimal stub `OpenGLES/ES2/gl.h` (GL types and the seven constants the test uses), kept outside the
repository. The fake driver is not the phone: whether the SGX543 driver compiles these outputs is still the open test.

The EAGL ES 3.00 context decision depends on that device test, and is not made here.

**Finding, toolchain: patches do not apply inside a checkout.** With the default cache, which lies inside the checkout,
xmake's patch step runs `git apply` and gets "Skipped patch" for every file, exits 0, and leaves the sources unpatched. The
first armv7 build then compiled the unpatched glslang and failed on `std::filesystem` (iOS 13). The same `git apply` applies
the patches cleanly from `/tmp`, and a clone of the cache outside the checkout applies them too. The cause was not
isolated. It was checked for glslang only; any package with patches built from a checkout-local cache may be affected.
The fix belongs to the toolchain, not to this prototype.

**The import check.** `llvm-nm` lists 194 undefined symbols across the nine archives, after removing the ones they define:

- 120 are C++ and 116 of them are exported by the revenant armv7 libc++ (`libc++.1.0.dylib` and `libc++abi.1.0.dylib`).
  The four others are `__Unwind_SjLj_Register`, `__Unwind_SjLj_Resume` and `__Unwind_SjLj_Unregister`, which come from
  `libgcc_s` and the SjLj unwinder armv7 iOS uses, and `___cxa_atexit`, from libSystem.
- 74 are C library symbols (libSystem, libgcc helpers, stdio, math). These are not yet checked against the 6.1.3 dyld
  shared cache: the repository has no export reader for it.
- None is `std::filesystem`, a thread-local (`_tlv_*`), `clock_gettime`, `os_unfair_lock`, an Objective-C or a dispatch
  symbol.

**The host check.** `frameworks/Backports/tests/OpenGLES/glsl_translator/translate_corpus.cpp` translates the six corpus
programs in process, built against the pinned host glslang and SPIRV-Cross. The outputs are byte-identical to the CLI
pipeline's ES 1.00 outputs (`expected/` in the same folder), and a source one byte over the 1 MiB limit is rejected. The
test passes on the host (`0 failure(s)`);
the device has not compiled these outputs. It is built with `clang++ -std=c++17 -fexceptions` against the glslang and
SPIRV-Cross host libraries and the include paths of the pinned sources, then run with the test folder as its argument.

## Risks the review raised, and what they are

An automated review of the commit flagged three upstream glslang paths. Their status:

- **`PoolAlloc.cpp`, dangling pointer in the no-thread path.** Real, and in upstream code: with `DISABLE_THREAD_SUPPORT`,
  the default allocator was a stack local. Patch 0002 makes it static, which the review's suggested fix matches.
- **`PoolAlloc.cpp`, integer overflow in `allocationSize + headerSkip`.** Real, in upstream code. Patch 0003 makes a
  request over `SIZE_MAX / 4` return nullptr, the allocator's own failure value, before any sum. The unpatched allocator
  segfaults on a request of `SIZE_MAX - 8` (exit 139), and the patched one passes. The test is
  `frameworks/ReactNative/tests/glsl_translator/poolalloc_overflow.cpp` (it tests glslang, so it stays with the ReactNative
  tools), built with `clang++ -std=c++17` against the
  glslang sources and `PoolAlloc.cpp` with patches 0002 and 0003. The translator also rejects a source over 1 MiB
  (`MAX_SOURCE_BYTES` in `tools/glsl_translator.lua`); an oversized shader is reported, not compiled.
  Patch 0004 covers the typed wrapper `pool_allocator<T>`, which multiplies `n * sizeof(T)` before the allocator sees it.
  A count over `max_size()` now calls `std::abort()`: a standard container must not receive nullptr from `allocate()`.
  The test forks and checks for SIGABRT; the pristine tree wraps the count and segfaults (exit 139) instead.
  The review's two points, answered: `allocationSize` has one caller, `TPoolAllocator::allocate`, which patch 0003 guards
  before the call, so `size + 2 * guardBlockSize + headerSize()` cannot wrap; and the `allocate` guard returns nullptr,
  which is glslang's own allocation-failure value for the pool, not an STL contract.
- **`InfoSink.h`, `std::filesystem::absolute` can throw.** The calls are reached only with the `absolute` diagnostic
  set. Patch 0001 removes them, and the translator never sets that option. Its only effect is the text of error
  locations.

## Not measured yet

- **The device compiler: measured once, on an iPhone 4S (iPhone4,1) with iOS 6.1.3.** A probe that creates an
  `EAGLContext` (`kEAGLRenderingAPIOpenGLES2`), compiles each file with `glShaderSource` and `glCompileShader`, and prints
  `GL_COMPILE_STATUS` with the info log, ran on the phone. The six ES 1.00 outputs (`expected/*.es100`) all compile:
  `COMPILE_STATUS = TRUE`, `glError = 0`, empty log. The driver reports `GL_VERSION = OpenGL ES 2.0 IMGSGX543-73.16.1`,
  `GL_RENDERER = PowerVR SGX 543`, `GL_VENDOR = Imagination Technologies`. Its `GL_EXTENSIONS` string has 35 names, from
  `GL_OES_depth_texture` to `GL_IMG_texture_compression_pvrtc`; it is kept in the session log, not copied here.
  As a control, the six raw ES 3.00 corpus sources compile to `FALSE`, each with `version '300' is not supported`, so
  translation is needed. The ES 1.00 outputs are not yet proven through the intercept on the phone: the probe calls the
  driver directly, and the intercept's translation of the corpus is tested on the host.
- **A linker note, not isolated.** A probe linked with the host's default linker stopped with `Illegal instruction`
  before `main` and printed nothing. The same source linked with the revenant `ld64` 956.6 (the one the xmake build uses)
  ran. The cause was not isolated; the working link is the one to use for device probes.
- **The rendered result.** The stub renders nothing, so no output image exists yet.
- **The device run.** The armv7 static libraries build and link, and the C++ imports are checked (above), but the thread-free
  configuration has not run on the device, and the 74 C library imports are not yet checked against iOS 6.1.3.
- **Skia's output.** Not in the corpus (see `docs/explanation/backports/metal-on-ios6.md`, the run-time MSL gap).
