# air2es notes

air2es translates the render stages of a Metal library (AIR bitcode) into GLSL ES 1.00
folders that the Metal backport loads. This file records what is known to be missing
and why, so it is not rediscovered later.

## Measured on Telegram's default.metallib (macOS air64, 15 modules)

- 11 of 14 render functions translate, pass the Appendix A checker, and pass
  glslangValidator in ES mode: basic_vertex, edgeTestVertex, matrixVertex,
  post_vertex_main, twoInputVertex, vertexPassthrough, edgeTestFragment, fragmentPlain,
  basic_fragment, scaleAndBlur, transformAndBlend.
- 3 render functions are refused by name, all for the constexpr sampler below:
  fragmentColorConversion, matrixFragment, post_fragment_main.
- compute_main is a kernel and belongs to air2cpu.

post_fragment_main also has a nested loop whose back edge re-enters an earlier block
(block 34 from block 43). The structurer refuses that as control flow once the sampler
is no longer the first refusal. This comes from reading the CFG, not from a run.

## Constexpr sampler (fragmentColorConversion, matrixFragment, post_fragment_main)

- The sampler is an opaque `i64` constant in the module (`@__air_sampler_state`).
  fragmentColorConversion has 0x807bff0000080a49 and matrixFragment has
  0x807bff0000084a92. They differ only in the low 16 bits (XOR 0x40db). Two values
  cannot establish a field layout, so the encoding is not decoded.
- The module carries no layout, only `air.sampler_state` metadata that names the
  constant. Searches of public sources found no published layout.
- Deriving the table needs a Mac with Xcode: compile a set of known constexpr samplers
  with `xcrun metal` and map each configuration to its constant. The Mac used here has
  only the Command Line Tools, which have no Metal compiler.
- Even once the layout is known, the GLES 2 target limits what can be represented:
  PowerVR SGX GLES 2 has no mirrored repeat, and repeat wrapping needs power-of-two
  textures. Some decoded configurations would still be refused by name.
- Until then the three shaders stay refused by name. The loader has no sampler field.

## Precision and device checks still owed

- Fragment shaders use `precision mediump float;`, as the loader contract requires.
  The `fmod` lowering (`x - y * sign(q) * floor(abs(q))`, with `q = x / y`) runs its
  quotient at mediump, so large quotients can lose integer precision. Check it on a
  device.
- The blur accumulators (scaleAndBlur, transformAndBlend) are vec4 sums of 61 samples
  at mediump. Check the result against the Metal output on a device.
- The `[[position]]` flip (`y = revenant_flip > 0 ? target.y - gl_FragCoord.y :
  gl_FragCoord.y`) is derived from the encoder's flip logic and is not verified on a
  device.

## Design choices

- A constant table read at a variable index becomes a select chain over its entries.
  An index outside the table takes the last entry. LLVM calls that case undefined, so
  the choice is ours.
- A variable read from an empty constant table is refused by name.
- Internal helper functions are inlined at each call site. They are not emitted as GLSL
  functions, so their sampler and texture parameters map to the caller's bindings.
- Control flow: an if/else region ends at the branch's immediate post-dominator. Phi
  values are copied on each edge, through temporaries when an edge copies more than one
  phi.
- A loop is lowered only when it is a single block that branches to itself, starts at a
  constant, steps by one and exits when `index + 1` equals a constant. It becomes
  `for (int i = start; i < bound; i++)`. Any other loop is refused by name.
- Half-precision vertex attributes are refused, because the loader reads anything but
  float and i8 as a short.
- `BranchInst` is deprecated in LLVM 23.1.4, as in `air2cpu.cpp`. It is kept because the
  pinned revenant@llvm 23.1.3 cannot be checked on this machine.

## Checks

- `./xmakew l frameworks/Backports/tools/air2es_check.lua FOLDER [GLSLANG]` checks a
  folder written by `air2es METALLIB FOLDER`. It checks `library.json`, every
  function's reflection against its source, and the Appendix A limits. It runs
  glslangValidator as a separate gate, and reports how many functions pass each. A
  function counts only when both pass.
- `frameworks/Backports/tools/air2es_limits.lua` implements the Appendix A checks. The
  rules come from GLSL ES 1.00, Appendix A, section 4 (loops) and section 5 (indexing),
  revision 17.
- `./xmakew l -P frameworks/Backports frameworks/Backports/tests/air2es_test.lua` runs 15
  checker cases. It is registered as the `air2es` suite of the backports tests.
- Negative control: replacing a loop bound with `int(inputTexture_size.x)` in the
  scaleAndBlur output keeps glslangValidator at exit 0, and the checker refuses it.
- The Telegram oracle is an external file, so the harness run on it is not part of CI.
  Whether it may run in CI is an owner decision.
