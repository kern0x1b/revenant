# air2es on Telegram's iOS Metal sources: per-shader verdicts

Measured 2026-10-30 with the Metal compiler of Xcode 27B47 (Metal 32023.922), compiling the 27 Telegram `.metal` files in 18 directories of the Telegram-iOS-release-13.0.0 reference to `air64-apple-ios12.0` with `-ffast-math` and linking each directory with `metallib`, as `rules_apple` does. The verdicts come from `./xmakew l -P . frameworks/Backports/tools/metal_corpus.lua`. The ffmpeg sources and the `rules_apple` test samples are not included. The sources are the `.metal` files of the `release-13.0.0` tag of `github.com/TelegramMessenger/Telegram-iOS` (commit `f1dd7a2`), fetched with a blobless sparse checkout of the 19 directories that hold them; the tool leaves out the 28th file, under `submodules/ffmpeg`, which leaves 27 files in 18 directories.

Result: 89 entry points (43 fragment, 27 vertex, 19 kernel). Before the changes measured below, 32 translate (18 fragment, 14 vertex) and 57 are refused by name, including all 19 kernels. After them, 46 translate (21 fragment, 17 vertex, 8 kernel) and 43 are refused; 11 of the 19 kernels are still refused. The table shows this state. Refusals are by air2es's own reasons, not by the GLES 2 target, except the clamp-to-zero and the mipmap-filter rows, which are the target's limits (see `frameworks/Backports/src/air2es/NOTES.md`).

| Library | Entry point | Stage | Verdict | Reason |
| --- | --- | --- | --- | --- |
| submodules_AnimationCompression_Resources | dctKernel | kernel | REFUSED | an argument of a kind this emitter does not read |
| submodules_AnimationCompression_Resources | idctKernel | kernel | REFUSED | an argument of a kind this emitter does not read |
| submodules_AnimationCompression_Resources | vertexShader | vertex | REFUSED | a load from a constant table this emitter does not map |
| submodules_AnimationCompression_Resources | samplingIdctShader | fragment | OK |  |
| submodules_AnimationCompression_Resources | samplingRgbShader | fragment | OK |  |
| submodules_AnimationCompression_Resources | samplingYuvaShader | fragment | REFUSED | a sdiv this emitter does not map |
| submodules_Camera_CameraNeo_MetalResources | convertNV12 | kernel | REFUSED | a terminator this emitter does not structure |
| submodules_Camera_CameraNeo_MetalResources | downsampleNV12 | kernel | REFUSED | a terminator this emitter does not structure |
| submodules_Camera_CameraNeo_MetalResources | compositeRoundVideo | kernel | REFUSED | a terminator this emitter does not structure |
| submodules_Camera_MetalResources | vertexPassThrough | vertex | OK |  |
| submodules_Camera_MetalResources | fragmentPassThrough | fragment | OK |  |
| submodules_DrawingUI_MetalResources | vertex_render_target | vertex | REFUSED | a member of type float4x4 in uniforms |
| submodules_DrawingUI_MetalResources | vertex_point_func | vertex | REFUSED | a member of type float4x4 in uniforms |
| submodules_DrawingUI_MetalResources | fragment_render_target | fragment | OK |  |
| submodules_DrawingUI_MetalResources | fragment_point_func | fragment | OK |  |
| submodules_MetalEngine_Sources | clearVertex | vertex | OK |  |
| submodules_MetalEngine_Sources | clearFragment | fragment | OK |  |
| submodules_PremiumUI_MetalResources | matrixVertex | vertex | OK |  |
| submodules_PremiumUI_MetalResources | matrixFragment | fragment | REFUSED | a sample with a linear mipmap filter, and the textures of a translated shader have no mipmaps |
| submodules_TelegramCallsUI_Resources | nv12VertexPassthrough | vertex | OK |  |
| submodules_TelegramCallsUI_Resources | nv12FragmentColorConversion | fragment | OK |  |
| submodules_TelegramCallsUI_Resources | blitFragmentColorConversion | fragment | OK |  |
| submodules_TelegramCallsUI_Resources | i420VertexPassthrough | vertex | OK |  |
| submodules_TelegramCallsUI_Resources | i420FragmentColorConversion | fragment | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | videoBiPlanarToRGBA | kernel | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | videoTriPlanarToRGBA | kernel | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | gaussianBlurHorizontal | kernel | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | gaussianBlurVertical | kernel | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBackgroundVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBlobVertex | vertex | REFUSED | a udiv this emitter does not map |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | mainVideoVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | edgeTestVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBackgroundFragment | fragment | REFUSED | a call to air.dot.v2f16 |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | mainVideoFragment | fragment | REFUSED | a call to air.fabs.v3f16 |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | edgeTestFragment | fragment | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | videoBiPlanarToRGBA | kernel | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | videoTriPlanarToRGBA | kernel | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | gaussianBlurHorizontal | kernel | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | gaussianBlurVertical | kernel | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | cameraBlobVertex | vertex | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | mainVideoVertex | vertex | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | cameraBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | mainVideoFragment | fragment | REFUSED | a call to air.fabs.v3f16 |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectInitializeParticle | kernel | REFUSED | a shl this emitter does not map |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectUpdateParticle | kernel | REFUSED | a urem this emitter does not map |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectVertex | vertex | REFUSED | a urem this emitter does not map |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectFragment | fragment | OK |  |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassCrestKernel | kernel | REFUSED | a struct member this emitter does not read in parameters |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassRadialKernel | kernel | REFUSED | a struct member this emitter does not read in parameters |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesVertex | vertex | OK |  |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesContentFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesMultiplyFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesMaskFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesDisplacementFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | dualFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | bt709ToRGBFragmentShader | fragment | REFUSED | a call to air.fast_saturate.v3f32 |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | defaultVertexShader | vertex | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | defaultFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | histogramPrepareFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | gradientFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | adjustmentsFragmentShader | fragment | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | enhanceGenerateLUT | kernel | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | rgbToLightnessFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | enhanceColorLookupFragmentShader | fragment | REFUSED | a sample with a linear filter and a clamp-to-zero address: the edge texels read as zero, which OpenGL ES 2 does not have, and an emulation needs the size of the texture |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurRadialFragmentShader | fragment | REFUSED | a sample with a linear filter and a clamp-to-zero address: the edge texels read as zero, which OpenGL ES 2 does not have, and an emulation needs the size of the texture |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurLinearFragmentShader | fragment | REFUSED | a sample with a linear filter and a clamp-to-zero address: the edge texels read as zero, which OpenGL ES 2 does not have, and an emulation needs the size of the texture |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurPortraitFragmentShader | fragment | REFUSED | a sample with a linear filter and a clamp-to-zero address: the edge texels read as zero, which OpenGL ES 2 does not have, and an emulation needs the size of the texture |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | gramDiamondCompositeVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | backgroundStarVertex | vertex | REFUSED | a logical shift right other than of a thread position or its lane by a constant |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondVertex | vertex | REFUSED | a member of type float4x4 in u |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | sparkleVertex | vertex | REFUSED | a member of type float4x4 in u |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | referenceHighlightVertex | vertex | REFUSED | a member of type float4x4 in u |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | gramDiamondCompositeFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | backgroundStarFragment | fragment | REFUSED | a call to air.fwidth.f32 |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondFragment | fragment | REFUSED | a member of type float4x4 in u |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondLensFragment | fragment | REFUSED | a member of type float4x4 in u |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | sparkleFragment | fragment | REFUSED | a call to air.fast_saturate.f32 |
| submodules_TelegramUI_Components_Stories_StoryPeerListComponent_MetalResources | cameraBlobVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Stories_StoryPeerListComponent_MetalResources | cameraBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletCardComponent_Resources | walletCardBackgroundVertex | vertex | REFUSED | a struct member this emitter does not read in uniforms |
| submodules_TelegramUI_Components_Wallet_WalletCardComponent_Resources | walletCardBackgroundFragment | fragment | REFUSED | a call to air.discard_fragment |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountBlur | kernel | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountLayerVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountFragment | fragment | REFUSED | a sample with a linear filter and a clamp-to-zero address: the edge texels read as zero, which OpenGL ES 2 does not have, and an emulation needs the size of the texture |
| submodules_WallpaperBackgroundNode_Resources | wallpaperVertex | vertex | OK |  |
| submodules_WallpaperBackgroundNode_Resources | wallpaperFragment1 | fragment | OK |  |
| submodules_WallpaperBackgroundNode_Resources | wallpaperFragment | fragment | REFUSED | a call to air.tan.f16 |

## Changes measured against the corpus

Before the changes below, the corpus measured 89 entry points, 32 OK and 57 REFUSED. Its 89 verdict rows (library, name, stage, verdict, reason) match the table above, after sorting, so that run is the baseline. Each change was measured with the same tool, `frameworks/Backports/tools/metal_corpus.lua`, into its own verdict file.

| Change | OK | REFUSED | Rows that moved |
| --- | --- | --- | --- |
| baseline | 32 | 57 | none |
| `air.point_coord` lowered to `gl_PointCoord` (`translate.cpp`) | 33 | 56 | `fragment_point_func`, REFUSED to OK |
| fragment outputs narrower than four lanes padded to `vec4(…, 0.0, 0.0, 1.0)` (`colorOf`) | 33 | 56 | none; the GLSL of `histogramPrepareFragmentShader` changed from `gl_FragColor = t9;` |
| `air.instance_id` lowered to `int(revenant_instance)`, a `uniform float` that the host sets once per instance (`translate.cpp`) | 33 | 56 | none to OK; six vertex functions leave the argument-kind reason: `dustEffectVertex` to a urem, `backgroundStarVertex` and `walletAmountVertex` and `walletAmountLayerVertex` to a local, `referenceHighlightVertex` and `sparkleVertex` to an address |
| `width` and `height` queries of the output texture lowered to `<tex>_size.x` and `.y` (`translate.cpp`, `air2es_check.lua`); the host sets the size of an output texture from its render target (`RevenantMetalEncoder.m`) | 33 | 56 | none to OK; the eight kernels with an output-size query leave the width refusal: `convertNV12`, `downsampleNV12` and `compositeRoundVideo` to `and`, `gaussianBlurHorizontal` and `gaussianBlurVertical` (two libraries) to an unsigned comparison, `walletAmountBlur` to a comparison |
| bitwise `and` with a constant mask in floats, signed and unordered compares, per-lane vector compares, `air.all.v2i1` to `all` (`translate.cpp`; measured after the group's last translator commit) | 33 | 56 | none to OK; `convertNV12`, `downsampleNV12` and `compositeRoundVideo` leave the `and` for a `switch` terminator; the gaussian blurs leave the vector compare for `air.write_texture_2d.v4f16`; `walletAmountBlur` leaves the comparison for a sign extension to i64; `sparkleFragment` leaves it for `air.fast_saturate.f32` |
| array and struct locals of the held types, declared as `T name[n]` and as a GLSL struct, each element named by its indices (`translate.cpp`; measured after this change) | 33 | 56 | none to OK; the nine kernels of the locals group leave the local refusal: `callBlobVertex` to a `udiv`, `backgroundStarVertex` to a `lshr`, `diamondFragment` and `diamondLensFragment` to a `float4x4` member in `uniforms`, `gramDiamondCompositeVertex` to `llvm.memset`, `walletCardBackgroundFragment` to `air.fast_clamp.v2f32`, `walletAmountVertex` and `walletAmountLayerVertex` to an address, `dustEffectInitializeParticle` to a `shl` |
| the clamp-to-zero samples, reason named: a linear filter with a clamp-to-zero address, which needs the texture size (`samplers.cpp`) | 33 | 56 | none; the five samples keep the refusal, and their reason now names the linear filter and the size |
| `air.fast_clamp` of a float2 lowered to GLSL `clamp` (`translate.cpp`) | 33 | 56 | none to OK; `walletCardBackgroundFragment` leaves the call for `air.discard_fragment` |
| `air.write_texture_2d.v4f16` written as the output, as the v4f32 write is (`translate.cpp`) | 37 | 52 | `gaussianBlurHorizontal` and `gaussianBlurVertical` in both libraries, REFUSED to OK |
| sample coordinates and size queries declared `precision highp float` and `highp int` (`translate.cpp`) | 37 | 52 | none; the precision line of 18 OK shaders changed and nothing else in them; the 4S compiles and links all 37 OK programs |
| `llvm.memset` of a local to zero, a constant lane of a local as `.x` to `.w`, and a dynamic index that ends a local's path as a select over its constant elements (`translate.cpp`) | 38 | 51 | `gramDiamondCompositeVertex`, REFUSED to OK; the 4S compiles and links it; a store through a dynamic index is refused |
| the half-precision `air.mix.v4f16`, `air.fmin.f16`, `air.fmax.f16` and `air.fract.f16` mapped to `mix`, `min`, `max` and `fract` (`translate.cpp`) | 40 | 49 | `dualFragmentShader` and `rgbToLightnessFragmentShader` in MediaEditor, REFUSED to OK; `mainVideoFragment` (two libraries) leaves the mix for `air.fabs.v3f16`; `adjustmentsFragmentShader` leaves the max for a cast; the 4S compiles and links the six MediaEditor programs |
| texture reads: `air.read_texture_2d.v4f16` at the thread position, level 0, as a nearest fetch of the texel centre with the texture's size (`translate.cpp`, `readTexture`); measured before the next row | 40 | 49 | none to OK; the four video kernels leave the read for the shift of a thread lane |
| a logical shift right of a thread position, or of one of its lanes, by a constant, as an integer division by 2^k (`translate.cpp`, `shiftRight`) | 44 | 45 | `videoBiPlanarToRGBA` and `videoTriPlanarToRGBA` in CallScreen and CameraScreen, REFUSED to OK; the 4S compiles and links all 44 OK programs; `backgroundStarVertex` keeps its refusal (a hash, see below) |
| a buffer indexed by the instance id read as uniforms of that instance's element, with `instanceStride` set to the element size (`translate.cpp`, `resolve`, `accessMember`); `air2es_check.lua` accepts `revenant_instance`, which the host sets (`RevenantMetalPipeline.m`) | 46 | 43 | `walletAmountVertex` and `walletAmountLayerVertex` in WalletSendScreen, REFUSED to OK; the 4S compiles and links all 46 OK programs; `instance_main.m` checks the element path through the Metal backport on the 4S (9 PASS) |
| a dynamic index into an array member of a buffer, as a select chain over one uniform per element (`selectMember`), and an i32 index widened to i64 read as the i32 (`isAddressIndex`) | 46 | 43 | none to OK; `adjustmentsFragmentShader` and `walletAmountBlur` leave the cast for an address this emitter does not read, a buffer read at a data-dependent index; `liquidGlassShapesDisplacementFragment` leaves the uniform index for a value of a struct type |

A verdict does not show that the GLSL compiles. `histogramPrepareFragmentShader` was OK at baseline, and its GLSL assigned a `float` to `gl_FragColor`. On the 4S it fails the ES 2 probe (`ERROR: 0:26: Incompatible types (vec4 and float)`), and `glslangValidator` rejects it for ES 1.00. After `colorOf` both accept it.

Checks on the state the table shows (46 OK, 43 REFUSED):

- the ES 2 probe on the 4S (iPhone4,1, iOS 6.1.3, PowerVR SGX 543) over the 46 OK entries: 46 PASS, 0 FAIL (`REVENANT-DONE programs 46 failures 0`). It compiles and links each one; it does not compare values. At the 44-entry state it was 44 PASS; at the earlier 33-entry state 33 PASS, and before `colorOf` 32 PASS, 1 FAIL;
- `air2es_check.lua` with `glslangValidator` over the 18 translated folders: 46 of 46 functions pass, and 0 folders fail; before `colorOf` 1 failed;
- `air2es_test.lua`: 15 cases pass.

The 49 refusals had 25 reasons after the half-precision maps. After the texture reads they have 24 reasons, and after the lane shift 45 refusals have 24. After the address changes the 43 refusals have 23 reasons. The earlier counts were 24 after the bitwise `and` and comparison changes, 28 after the locals change, 27 after the texture writes and 26 after the memset. The half-precision maps compute in the float or mediump precision of the GLSL they become; the rounding of Metal's half is not compared, so the compile on the 4S is the only device check of them. The argument-kind group is down from 9 to 2, and both are the threadgroup kernels below.

`width` and `height` of an output texture (the width group, decision: host loader sets `<tex>_size`):

- the translator accepts a size query on a `texture2d<..., access::write>` argument and emits `uniform vec2 <name>_size` with `"output": true` in the sizes entry of the reflection;
- the host sets that uniform from the render target of the pass (`_target`), and for a translated kernel the output texture is the color attachment (`MTLComputeCommandEncoder8.m`). The iOS build of `MetalInstanceProbe` compiles the host loader (`RevenantMetalEncoder.m`, `RevenantMetalPipeline.m`); the 4S has not run this yet, and no entry is OK in this group, so the 33 OK entries and their 33/33 probe are unchanged;
- the eight kernels stop at a different operation each: a bitwise `and` (three), an unsigned comparison of integers other than 32 bits (four, the two gaussian blurs in two libraries), and a comparison (`walletAmountBlur`). The next section lowers the first two and records where all eight stop now.

Bitwise `and`, comparisons and `all` (decision: an exact float emulation of a constant-mask `and`, and per-lane vector compares):

- `x & m` with a constant `m` that keeps bit 31 is written as `int(S)`, where `S` is `max(float(x), 0.0)` minus, for each cleared bit `b`, `2^b * floor(mod(max(float(x), 0.0), 2^(b+1)) / 2^b)`. GLSL ES 1.00 has no integer bit operators and reserves `%`, so the emitter has no other exact form.
- The operand must be the result of an unsigned float-to-integer conversion (`air.convert.u.i32.f`). Its integer is a float32 value, so the float arithmetic on it is exact. A negative operand is out of range for that conversion, and the emulation takes the saturated value 0; the device needs the clamp (below). A signed conversion, a mask that clears bit 31 and a non-constant mask are refused by name. Operands stay below 2^31, because the emitter holds an i32 as `int`.
- The shader is declared `precision highp float` and `precision highp int` when the emulation is used. The default `mediump` holds integers only up to 2048, and the default int precision of a fragment shader is mediump.
- Device check, on the 4S (PowerVR SGX 543, iOS 6.1.3), with `Es2ProgramProbe` in its point-render mode: one point per pixel of a 1024×1024 target, in three sets (every integer from -2^19 up, the integers around 2^24, and random float truncations with the int32 extremes). The clamped form, with highp float and int, passes all 3,145,728 points, the negative operands included (expected 0). Without the clamp, all 2,097,237 non-negative operands pass and 98,389 of the 1,048,491 negative operands fail. A float-only variant with no int conversion fails on the same inputs, and the int round trip passes for every value, so the fault is the device's floor and mod of negative floats. With highp float and the default int, or with mediump float, almost every value fails.
- Host check: in single precision with `-ffp-contract=off`, for every integer from -2^24 to 2^24 and for 20 million truncated floats, the clamped formula equals `x & ~2` for non-negative x and gives 0 for negative x (53,554,495 values, 0 mismatches). The emitted statement compiles as ES 1.00 under `glslangValidator`; a control shader with a native `&` is rejected, as expected.
- Signed `slt`, `sgt`, `sle` and `sge` map to the GLSL operators. An unordered float predicate maps to its ordered form only with `nnan`, where no operand is NaN; without it, it is refused by name. The ordered `one` maps to `!=`.
- A vector compare builds its `bvec` from one comparison per lane, because GLSL ES 1.00 compares vectors only with functions. The unsigned predicates on 32-bit lanes use the sign split of each lane, which is exact for every int32. `air.all.v2i1` maps to `all`.

The blockers these kernels stop at now:

- `convertNV12`, `downsampleNV12` and `compositeRoundVideo`: a `switch` terminator on the convert result, which the structurer does not handle;
- `gaussianBlurHorizontal` and `gaussianBlurVertical` in both libraries: `air.write_texture_2d.v4f16`;
- `walletAmountBlur`: `sext i32` to `i64`, used as a constant-buffer index;
- `sparkleFragment`: `air.fast_saturate.f32`.

Locals of a type this emitter did not hold (decision: arrays and structs of the GLSL types it holds, each element named by its indices):

- An alloca of an array of a held type is declared as `T vN[n];`. A struct local is a GLSL struct `SN` with a field `fI` for each member, and an array member is an array field. Struct members and arrays of structs are refused by name.
- A GEP into a local follows its indices: a struct field by its constant index, an array element by a constant or a dynamic index. An i32 widened to i64 is that i32, because GLSL ES 1.00 has no i64. The element is a local of its own, so loads and stores of it take the path of any local.
- Dynamic indexing of a local array is translated, and `glslangValidator` accepts it for ES 1.00 in fragment and vertex shaders. The 4S has not compiled it. No OK entry uses a local array (before this change every array local was refused), so no device result depends on it yet.
- Measured: every `.glsl` and `.json` file of the 18 translated folders is byte-identical to the state before this change, so the 33 OK entries keep their 4S probe result (33 PASS) without a new run. `air2es_check.lua` with `glslangValidator`: 0 folders fail. `air2es_test.lua`: 15 cases pass.
- The nine kernels of the group leave the local refusal, and none is OK yet. They stop at these now:
  - `callBlobVertex`: `udiv`;
  - `backgroundStarVertex`: `lshr`;
  - `diamondFragment` and `diamondLensFragment`: a `float4x4` member in `uniforms`;
  - `gramDiamondCompositeVertex`: translated now, see the memset section below;
  - `walletCardBackgroundFragment`: `air.fast_clamp.v2f32`;
  - `walletAmountVertex` and `walletAmountLayerVertex`: an address this emitter does not read;
  - `dustEffectInitializeParticle`: `shl`.

Clamp-to-zero samples (decision: kept refused, with the reason named; an exact emulation needs a host change):

- Five entries use one constexpr sampler: clamp to zero on s and t, linear minification and magnification. They are `enhanceColorLookupFragmentShader`, `blurRadialFragmentShader`, `blurLinearFragmentShader` and `blurPortraitFragmentShader` (MediaEditor), and `walletAmountFragment` (WalletSendScreen).
- With a linear filter, a sample near the edge blends the edge texels with the zero border, so its value depends on the texture size. OpenGL ES 2 clamps to the edge texel and has no zero border.
- An emulation would fetch the four texels around each sample with a nearest fetch and weight them by the texture size. The host would have to set that size for each input texture; the width group's size uniform covers only output textures. The weights are computed in float, so the result is an approximation of the hardware filter, not a bit-exact match. Decision (coordinator): keep these refused, with the reason named. They return only with an exact emulation that can be measured on the 4S with a small deviation. Low priority.
- A nearest-filter clamp-to-zero sample needs no size: a coordinate in [0, 1) indexes a texel, and any other coordinate reads zero. No corpus entry uses one, so it is not implemented.
- Measured: 33 OK and 56 REFUSED before and after. The five rows keep their refusal, and the reason changed only for them. `air2es_test.lua`: 15 cases pass.

Texture writes of half4, and highp for sampled coordinates:

- `air.write_texture_2d.v4f16` writes the output the same way `v4f32` does, so the two gaussian blurs of each library are translated. They read their input through `inTexture_size` and sample it, and the host sets that uniform from the bound texture's width and height (`RevenantMetalEncoder.m`). That host path has not run on the 4S yet, and the output-size path of the width group has not either.
- A sample coordinate is computed from the position and a size, and the default mediump float rounds it to 10 mantissa bits. Samples and size queries therefore declare `precision highp float` and `precision highp int`, as the and emulation does. A diff of the 18 changed OK shaders shows only the precision line changed.
- Measured on the 4S: all 37 OK programs compile and link under the ES 2 probe (`REVENANT-DONE programs 37 failures 0`). That is compile and link only. Whether the 4S samples the same values as Metal is not measured, so an OK entry means translated, compiled and structurally checked; it does not mean the sampled values are equal.
- `air2es_check.lua` with `glslangValidator`: 0 folders fail; `air2es_test.lua`: 15 cases pass.

Texture reads (`air.read_texture_2d.v4f16`, four rows: `videoBiPlanarToRGBA` and `videoTriPlanarToRGBA` in two libraries) are translated (`translate.cpp`, `readTexture`). A read at a thread position, of a texture argument at level 0, is a nearest fetch of the texel centre, `texture2D(tex, (vec2(p) + vec2(0.5)) / tex_size)`, with a nearest sampler that clamps to the edge. The size is the host's, as for a size query. The chroma planes read at the position halved, a logical shift right of a thread lane, which is the next row of the table.

- Measured on the 4S with the texture stage of `Es2ProgramProbe` (`frameworks/Backports/tests/device_probe/es2_main.m`). The host writes a texel pattern into an RGBA8 input texture, the translated shader renders into an RGBA8 target, and the probe compares every output byte with the value the host computes. `readIdentity` at 1024×1024 and at 250×130 passes all 1,081,076 pixels with a maximum difference of 0. `readHalfResolution`, which reads at the position halved, passes 98,036 pixels with 0 difference at 256×256 from 128×128 and at 250×130 from 125×65. The nearest fetch and the integer division by 2 are exact on this device for these sizes.
- Negative control on the same phone: the half-resolution shader compared with the identity mapping fails 65,282 of 65,536 pixels, with a maximum difference of 251. So the comparison can fail.
- Not measured: the formats of the planes. The probe uses RGBA8 only. The video kernels read the luminance plane through `.x` and the chroma through `.xy`. The host must bind those planes so the sampled channels hold the plane's values. `RevenantMetalEncoder.m` sets the input sizes from the bound textures; that path has not run on the 4S. The 4S compile of the two kernels does not show the binding.

Memset of a local and dynamic indexes (decision: the project's Appendix A rule for array indexes applies to locals too):

- `gramDiamondCompositeVertex` zero-fills a local `[6 x <2 x float>]` with `llvm.memset`, writes single lanes of its elements, and reads an element at the vertex id. A memset of a local to zero stores `0.0` (or `vecN(0.0)`) into each element it covers, and a constant lane becomes `.x`, `.y`, `.z` or `.w`.
- The vertex id is a dynamic index into the local. `air2es_check.lua` rejects any array index that is not a constant (Appendix A, section 5), and the local-array lowering of `ccf2a75ae` accepted a dynamic index that the check would reject. No corpus entry had reached one, because the memset refused the kernel first. A dynamic index that ends a local's path is now a select chain over the constant elements, `((i == 0) ? v[0] : ((i == 1) ? v[1] : …))`, and a store through a dynamic index is refused. The chain's last element is the default for indexes past the array.
- Metal leaves an index past the six elements undefined, and the translation returns the last element there. The caller that draws this pass is not in the reference checkout, so whether it ever draws more than six vertices is not checked.
- Measured: 38 OK and 51 REFUSED. On the 4S the new vertex and the existing fragment compile and link (`REVENANT-DONE programs 2 failures 0`). `air2es_check.lua` with `glslangValidator` passes on all 18 folders, and `air2es_test.lua` passes 15 cases.

Addresses this emitter does not read (the decision by the coordinator, with what is built now):

- Buffers read at the instance id (`walletAmountVertex`, `walletAmountLayerVertex`, and `sparkleVertex` and `referenceHighlightVertex` through `anchors[instance]` and `highlights[instance]`). Decided: the element of each instance is read as uniforms. The host already offsets each uniform by `instanceStride` times the instance for every draw of an instanced call (`uploadUniforms` in `RevenantMetalEncoder.m`), so this is not the host expansion of per-vertex data that the decision named, and it needs no host change. The wallet kernels are OK. `sparkleVertex` and `referenceHighlightVertex` now stop at a `float4x4` member in `u`, which is a matrix uniform and a separate group (seven `float4x4` rows in all).
- `liquidGlassShapesDisplacementFragment`: the select chain over `layerRimGlass` is built (`selectMember`), but the shader still reads `samples` at an index computed from the pixel (`radius[index]`, `crest[index]`) and returns a struct by value. It stops at a value of a type this emitter does not hold and stays refused. Its buffer reads need a design of their own.
- `enhanceGenerateLUT` is a kernel that reads a buffer at an index computed from the thread position. The translated kernels write one output per thread, so this read needs a different pass design. Decided: later, and only with a written design of that pass. Not built.
- `walletAmountBlur` (`weights[offset + radius]`) and `adjustmentsFragmentShader` (the curve tables) read a buffer at an index the data sets. They were not in the decided set and stay refused.

Integer operations, the first refusal of four kernels (decision: they stay refused; no buffer divisor is assumed):

- `callBlobVertex` divides the vertex index by constants (`udiv` by 3 and 24, `urem` by 3). Its next refusal is a `srem` by a value loaded from a buffer, and that value has no bound the translator can see. A division of the vertex index by a constant could be GLSL int division, but the translator refuses this kernel at the `srem` first, so no entry uses it, and the 4S has not checked int division. It is not translated.
- `dustEffectVertex` and `dustEffectUpdateParticle` divide by a value loaded from a buffer. The divisor may be zero or negative, and the translator cannot bound it.
- `dustEffectInitializeParticle` and `backgroundStarVertex` compute a 32-bit hash with xor, shifts and a wrap-around multiply. GLSL ES 1.00 has no bit operators, and float arithmetic does not give a 32-bit wrap-around multiply exactly without multi-precision steps. They stay refused.
- Decision (coordinator): a buffer divisor is not assumed positive and below 2^24, so these stay refused. The float attribute holds a vertex index exactly only below 2^24, which is why the assumption was asked about. The hashes need another approach and stay refused.
- Measured: 33 OK and 56 REFUSED, the same as before this group.

`instance_id` (decision: a host-filled uniform, looped per instance):

- the emitter declares `uniform float revenant_instance;` and reads `int(revenant_instance)`. The name is the one the host already sets (`RevenantMetalPipeline.m`, `revenant_instance`), so the host needed no change;
- `RevenantMetalEncoder.m` draws an instanced call as one GL draw per instance, setting the uniform to `0 … instanceCount - 1` in order. That is the Metal value for a draw with no base instance. The backport has no `baseInstance` overloads, so the loop starts at 0; if overloads are added the loop must start at `baseInstance`;
- the three-instance check is `frameworks/Backports/tests/device_probe/instance_main.m`: a 3-instance draw must write the columns `1`, `2`, `3` in order, and an indexed draw must match. On the 4S (iPhone4,1, iOS 6.1.3) all five checks pass and `REVENANT-DONE failures 0`. The probe ran from `/var/revenant/MetalInstanceProbe.app`, with the build's four backport dylibs next to the binary (install names rewritten to `@executable_path` and re-signed with `ldid`); `/usr/lib/revenant` and the platform package were not changed. The run logs `objc` warnings that `NSJSONSerialization`, `NSProgress` and `NSUUID` exist in both the system Foundation and the bundled `libFoundationBackports`; the Metal checks do not use those classes.

`dctKernel` and `idctKernel` (`submodules/AnimationCompression/Resources/DCT.metal`) stay in the later group. What they need:

- a threadgroup of 8×8 threads (`BLOCK_SIZE` 8); `thread_position_in_threadgroup` gives the position in the 8×8 block, and `thread_position_in_grid` gives the pixel;
- two `threadgroup float[64]` arrays (`CurBlockLocal1`, `CurBlockLocal2`), written by one thread and read by others in the same block;
- barriers, `threadgroup_barrier(mem_flags::mem_threadgroup)`: `dctKernel` has four in its body (lines 417, 425, 430, 434: after copy-in, after the DCT, after quantize, after the zigzag reorder), plus one in the `DCT` helper (line 296); `idctKernel` has two in its body (469, 477), plus one in the `IDCT` helper (line 335). Each barrier needs every thread of the block to arrive, and a read after it sees the writes made before it by the other threads;
- the zigzag reorder permutes the block across threads, so one output pixel depends on all 64 inputs;
- the intermediate values are `float`, and the output is `half4` per pixel (`copyTextureBlockOutFloat`).

Two ways to meet that without a compute shader:

- (a) per pixel, with no shared memory and no barriers: each fragment reads its 8×8 block (64 texels), computes its own coefficient and writes it. Cost: 64 reads and a full 8-point transform per output pixel and per frame;
- (b) multi-pass: one draw per barrier interval, with intermediate render targets. Needs a float or wide render target. On ES 2 (iOS 6, PowerVR SGX 543) an RGBA8 target would hold the coefficients at 8 bits. Not measured: whether the 4S renders to `OES_texture_float`.

The decision between (a) and leaving the two kernels unsupported is open.

The bitwise `and`, comparison and locals groups are translated as far as the table shows, and the clamp-to-zero samples are kept refused with their reason named (decision above). The blockers listed above are the first refusal of each kernel. Counted by reason, the largest remaining are a linear filter with a clamp-to-zero address (5), a `float4x4` member (7), a value of a type this emitter does not hold (4), and the integer operations `udiv`, `urem`, `sdiv`, `shl` and a shift of a non-thread operand (6 together). An address this emitter does not read is three rows now, and the texture reads are translated (see above).
