# air2es kernel lowering

Status: kernel mode is in `frameworks/Backports/src/air2es/translate.cpp` on `work/metal-kernel`. It translates the
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
- Refused by name: a kernel with no write, a kernel with two output textures, a write at another coordinate, a write
  at a level other than 0, a threadgroup argument (`air.threadgroup` tag), a threadgroup barrier (`air.wg.barrier`
  call), and an atomic (`air.atomic` call).
- Checked: six synthetic kernels, written as LLVM IR with the metadata shape of `compute_main` and assembled with the
  package's `clang`. The success case passes `glslangValidator -S frag`. The level, coordinate, barrier, threadgroup and
  no-write cases return their named refusals. The barrier and atomic intrinsic names are assumed; the Telegram corpus
  has neither.

## Still refused

- `compute_main` stops at its first `alloca`. Its locals are passed by reference to `trace` and `trace2D`. Mapping an
  alloca that only inlined helpers load and store is the next step.
- After that, `compute_main` needs `samplerCube` support for `air.sample_texture_cube` and the constexpr sampler
  table. The table cannot be derived without a Metal toolchain, so that gate stays until one exists.

## Port (not done)

- `frameworks/Backports/src/Metal/MTLComputePipeline8.m` still looks up `air2cpu_kernels`. A kernel air2es translates
  must load its `.es2` fragment and run through the GL path, and must not reach the table. The silent route stays
  until that exists. The air2es refusal text no longer says "belongs to air2cpu".
- The loader contract is open: `library.json` needs a kernel kind, its bindings, the output texture name and index, and
  the grid rule. The reflection does not carry the write texture yet.

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
2. The write texture needs a reflection entry for the loader.
3. Accuracy of translated kernels against Metal (owner's toolchain).
4. Float textures on the A5 (`OES_texture_float`), needed only for indexed float buffers.
