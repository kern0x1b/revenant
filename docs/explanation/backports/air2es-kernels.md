# air2es kernel lowering

Status: kernel mode is in `frameworks/Backports/src/air2es/translate.cpp` on `work/metal-kernel-2`. It translates the
subset described under "Translated" and checked on synthetic kernels. No real kernel translates yet: the one kernel in
the corpus is refused by name (see "Still refused"). The Metal port still runs kernels through the air2cpu table.

## Measured

- Corpus: `/Applications/Telegram.app/Contents/Resources/default.metallib`, read with `air2es --list`. It holds 15
  modules: 8 fragment, 6 vertex, 1 kernel (`compute_main`). The 11 render functions translate, 4 are refused by name
  (three with a constexpr sampler, `post_fragment_main`). The `.es2` output for the 11 is byte-identical before and
  after the kernel change.
- Kernel `compute_main` (AIR metadata `!air.kernel`):
  - argument 0: `air.texture`, `air.write`, `texture2d<float, write>`, named `outputTexture`
  - argument 1: `air.texture`, `air.sample`, `texturecube<float, sample>`, named `cubemap`
  - arguments 2 to 4: `air.buffer`, read; `iTime` (float), `iResolution` (float2), `cameraRotation` (float3)
  - argument 5: `air.thread_position_in_grid`, `uint2`, named `gid`
  - the sampler is a constexpr global `@__air_sampler_state`, not an argument
- The output is a texture written once per thread, `air.write_texture_2d.v4f32(out, gid, value, 0, 2)`, not a buffer.
  The fifth operand is `2` in this kernel; its meaning is not documented here, and the translator does not read it.
- Some threads skip the write (a branch goes straight to the return), which is the case a fragment expresses with
  `discard`.
- The kernel calls two helpers with references (`trace`, `trace2D`), which leave `alloca <3 x float>` in its body.
- No Metal compiler is on this Mac (`xcrun -f metal` fails; Command Line Tools only). New kernel AIR cannot be built
  here, and the Metal shader harness cannot run compute.

## Translated

- A kernel becomes one ES 1.00 fragment shader.
- `gid` is `ivec2(floor(gl_FragCoord.xy))`. GL row `r` of a texture is memory row `r`, so no flip is applied.
- The write texture (`air.write`) is the output. A write must be at level 0, and its coordinate must be the thread
  position. Its value becomes `gl_FragColor`, and `revenant_written` is set.
- A thread whose path never writes runs `discard`, which leaves the texel as it was, as Metal does.
- Locals: an `alloca` of a scalar or vector type becomes a GLSL local. Its stores and loads are emitted in program
  order, so a value stored on one branch and loaded after the join is right. A helper that takes a reference is
  inlined, and the reference is the local.
- Unsigned compares of 32-bit integers (`icmp ult`, `ule`, `ugt`, `uge`) use the sign-aware form
  `((a < 0) != (b < 0)) ? (a >= 0) : (a < b)`. A host check compares it with unsigned comparison on 81 value pairs
  and finds no mismatch.
- `air.sample_texture_cube.v4f32` becomes `textureCube` on a `samplerCube` uniform, and the cube gets a texture entry
  with `"cube": true`. The sampler must be an argument; a constexpr sampler is refused.
- `air.fast_rsqrt.f32` becomes `inversesqrt`. Pointer bitcasts of arguments and locals are followed.
- The reflection carries `outputTexture` (the write texture's name and index).
- Refused by name: a kernel with no write, a kernel with two output textures, a write at another coordinate, a write
  at a level other than 0, a threadgroup argument (`air.threadgroup` tag), a threadgroup barrier (`air.wg.barrier`
  call), an atomic (`air.atomic` call), and an alloca of an array or any other type that is not a scalar or vector.
- Checked: ten synthetic kernels, written as LLVM IR with the metadata shape of `compute_main` and assembled with the
  package's `clang`. The success cases (including the alloca local, the cube sample and the unsigned compare) pass
  `glslangValidator -S frag`; a control with a `1u` literal fails it, so the check is live. The level, coordinate,
  barrier, threadgroup, no-write and array-alloca cases return their named refusals. The barrier and atomic intrinsic
  names are assumed; the Telegram corpus has neither. The fixtures and their driver are in the worktree's scratch
  folder, not in the tests; a tracked regression test is open.

## Still refused

- `compute_main` now stops at a load from an address this emitter does not read. That address pattern is not yet
  characterized, and it is the next thing to map.
- After that, `compute_main` calls intrinsics the emitter does not map yet (read from its call sites):
  `air.fast_fmax.f32`, `air.fast_fmin.f32`, `air.fast_pow.f32`, `air.fast_sqrt.f32`, `air.dot.v2f32`,
  `air.fast_clamp.f32`, `air.mix.f32`, `air.fast_fract.v3f32`, `air.fast_fabs.v2f32` and `air.fast_fabs.v3f32`.
- It samples its cube through the constexpr sampler `@__air_sampler_state`, which is not an argument. The sampler
  table cannot be derived without a Metal toolchain, so that gate stays until one exists.

## Port (not done)

- `frameworks/Backports/src/Metal/MTLComputePipeline8.m` still looks up `air2cpu_kernels`. A kernel air2es translates
  must load its `.es2` fragment and run through the GL path, and must not reach the table. The silent route stays
  until that exists. The air2es refusal text no longer says "belongs to air2cpu".
- The loader contract is open: `library.json` needs a kernel kind, its bindings and the grid rule. The reflection
  carries the output texture (`outputTexture`), but no loader reads it yet.

## Multi-pass designs (design, not implemented)

These replace the refused constructs. The kernel's barrier becomes a pass boundary, and each pass is one draw.

- Reductions: each halving step is one ping-pong pass; `log2(n)` passes over the input.
- Scans: log-step passes over ping-pong targets.
- Histograms: a vertex pass draws one point per element at a precomputed position, with additive blending into a float
  or half-float target. Vertex texture fetch is 0 in the guide and unverified at run time, so positions are computed on
  the CPU when `MAX_VERTEX_TEXTURE_IMAGE_UNITS` is 0.
- A kernel that needs a barrier inside one pass stays refused by name. Its multi-pass rewrite is a separate entry whose
  accuracy the owner accepts.

## Verification

- `air2es` test: passes (`./xmakew test -P . air2es`).
- `digest_test`: the backports digest changed with `translate.cpp`; regenerated under the host config with
  `./xmakew l -P . toolchain/tools/recipe_digests.lua` and passes.
- Accuracy against Metal needs a Metal compiler and the owner's Xcode; neither is on this Mac.
- Performance is measured per kernel on the iPhone 4S, before and after, as ADR 0014 requires. No kernel is on the GL
  path yet, so there is nothing to measure.

## Open items

1. Indexed buffer reads (a non-constant index) need a texture; not implemented.
2. The loader needs to read `outputTexture` and the kernel's bindings from the reflection.
3. Accuracy of translated kernels against Metal (owner's toolchain).
4. Float textures on the A5 (`OES_texture_float`), needed only for indexed float buffers.
