# enhanceGenerateLUT on ES 2: design

Status: design only. Nothing here is implemented, and no verdict changes. `enhanceGenerateLUT` stays REFUSED (`an address this emitter does not read`) until the owner gives the go. Measured facts are marked as such. Everything else is a plan or an assumption, and says so.

Source: `submodules/TelegramUI/Components/MediaEditor/MetalResources/EditorEnhance.metal` and `submodules/TelegramUI/Components/MediaEditor/Sources/EnhanceRenderPass.swift` of the release-13.0.0 reference (`Telegram-iOS-release-13.0.0`).

## What the kernel computes

One thread per tile `gid < numberOfLUTs`, each on its own row of a histogram of `histogramBins` counts (`histogramBuffer`, `uint`, read and written in place):

1. Clip: for each bin, `clipped += l[i] - clipLimit` where `l[i] > clipLimit`, and `l[i] = clipLimit`.
2. Redistribute: `batch = clipped / bins`, `residual = clipped - batch * bins`. Every bin gets `+batch`. If `residual != 0`, `step = max(bins / residual, 1)`, and a loop adds 1 to `l[i]` for `i = 0, step, 2*step, …` while `i < bins` and `residual > 0`, decrementing `residual` each time.
3. Cumulative sum: `sum += l[index]`, and the texel `(index, gid)` gets `round(sum * lutScale) / 255`, where `lutScale = (bins - 1) / totalPixelCountPerTile` in float.

## Host facts (measured from the reference source)

- `binCount = 256`. The LUT texture is `r8Unorm`, 256 texels wide and `numberOfLUTs` high (`EnhanceRenderPass.swift`, lines 84 and 137–139).
- The histogram is encoded per tile with `MPSImageHistogram` into one buffer of `numberOfLUTs * 256` `uint` entries. The backport has its own `MPSImageHistogram` (`frameworks/Backports/src/MetalPerformanceShaders/MPSImageHistogram13.m`). Whether it writes the same counts as Apple's on the 4S is not measured.
- `clipLimit = max(1, clip * tilePixels / 256)`, truncated to `uint`. `totalPixelCountPerTile = tileWidth * tileHeight`. Both reach the kernel through `setBytes` as four `uint` values, `MediaEditorEnhanceLUTGeneratorParameters`.
- The kernel is dispatched in one-dimensional threadgroups over `numberOfLUTs`. The buffer is not read after the dispatch in this file; the pass returns the LUT texture. So the write-back of the clipped histogram is dead for this host, if no other code reads the buffer. That is not checked outside this file.
- The tile size comes from `input.width / gridSize.width`. The grid size is not in the corpus checkout, so the largest tile pixel count is not known yet.

## Why it is refused now

The kernel reads and writes device memory at indexes from the thread position and from the data (`l[i]`, `l[i] = clipLimit`, `l[i]++` at a stride). OpenGL ES 2 has no buffer that a shader can write, and the translator has no address form for it. The design therefore has to change the pass shape, not only the translation.

## Proposed ES 2 shape

A single render pass into the LUT target, with no inter-thread dependency:

- Target: the LUT, 256 × `numberOfLUTs`, one fragment per texel. Texel `(x, y)` is bin `x` of tile `y`. The fragment writes `vec4(v / 255.0, 0.0, 0.0, 1.0)`, so an RGBA8 target stores the byte `v`, which is what `r8Unorm` stores for `v / 255`.
- Each fragment recomputes what it needs for its tile:
  - `clipped = Σ_j max(0, h[j] − clip)` over 256 bins (256 fetches);
  - `batch = floor(clipped / 256)`, `residual = clipped − batch * 256`;
  - `l'[j] = min(h[j], clip) + batch + extra(j)`, where `extra(j) = 1` when `residual > 0`, `s = floor(256 / residual)`, `j` is a multiple of `s`, and `j / s < count`, with `count = min(residual, floor(255 / s) + 1)`;
  - `sum = Σ_{j ≤ x} l'[j]`, then `round(sum * lutScale) / 255`.
- Cost: about 512 texel fetches per fragment, so 256 × `numberOfLUTs` × 512 in total. A two-pass variant would store the clipped histogram once per tile and halve the work. Not measured on the 4S.

Closed form of the residual rule. The loop increments bin `k * s` for `k = 0, 1, …` while `k * s < 256` and `k < residual`. So `extra(j)` is 1 exactly for the bins `j = k * s` with `k < count`. The equivalence is argued from the source; the device check below tests it.

Arithmetic:

- Every count, index, `s` and `residual` is an integer below 2^24, so highp float holds it exactly. `floor(j / s)` is exact because the fraction of `j / s` is at least `1/256` when it is not an integer.
- `mediump` float holds integers only up to 2048, so the whole count arithmetic is `highp`. The 4S runs highp float and int in fragment shaders for the bitwise-`and` emulation (verdict doc, bitwise section); the full shader is not measured.
- The product `sum * lutScale` is a float32 multiply, as in Metal, if the GPU is IEEE single. Not measured.
- Metal's `round` is half away from zero. For the non-negative values here, `floor(x + 0.5)` gives the same result.

## What the host must do

1. Copy the histogram buffer into a texture before the pass: 256 × `numberOfLUTs`, with each count split into two bytes (for example `LUMINANCE_ALPHA`), so a count up to 65,535 is exact. The copy is a new backport path, not an existing one.
2. Set `clipLimit` and `totalPixelCountPerTile` as uniforms, and refuse the dispatch unless `histogramBins == 256` and the target height is `numberOfLUTs`, because the loop bound is fixed in the shader.
3. Render the quad over the LUT target. Kernels already render into an output texture as their colour attachment (`MTLComputeCommandEncoder8.m`), so this part exists.
4. Check that every tile's pixel count is below 65,536. That is an assumption until the tile grid is read from the host.

## Not established, and why it matters

- A tile's pixel count below 65,536: not checked (the grid size is not in the corpus checkout). If a tile is larger, the two-byte histogram texture loses counts.
- Whether the backport's `MPSImageHistogram` gives the same counts as Apple's on the 4S: not measured.
- Whether the host reads the histogram buffer after the kernel: not in this file. If it does, the write-back is needed.
- Highp fragment arithmetic over a 256-step loop on the SGX 543, and the time per enhance call: not measured.
- The output format `r8Unorm` is stored as bytes on the 4S with the RGBA8 target: not measured.

## Value of this pass on its own

The enhance tool samples the LUT in `enhanceColorLookupFragmentShader`, which the corpus refuses for a linear, clamp-to-zero sampler (`samplers.cpp`, the clamp-to-zero decision in the verdict doc). Without that shader, a correct LUT produces no enhance output on the phone. So this pass alone unlocks no visible feature. The clamp-to-zero decision is the other half.

## Verification plan (when the go is given)

- A host reference: a C port of the kernel, with the residual rule written as the loop, not the closed form, so the closed form is tested against the source.
- Cases: random histograms with the clip active, with the clip inactive, residual 0, 1 and 255, a bin at the maximum count, and a tile with all counts in one bin.
- Compare every LUT byte with the reference on the 4S, with the texture stage of `Es2ProgramProbe` as the model.
- Negative control: a reference with `clipLimit + 1` must mismatch on the same inputs.

## Decision needed from the owner

1. A replacement category. The verdict doc's OK means translated by air2es. This pass would be a hand-written ES 2 shader that the device verifies against a reference, not a translation of the AIR. It needs its own verdict word, or it stays REFUSED in the table.
2. The go for the work. Estimate: a shader of about 60 lines, a host upload path of about 40 lines, and a probe of about 150 lines, plus the clamp-to-zero decision for the lookup.
