# air2es on Telegram's iOS Metal sources: per-shader verdicts

Measured 2026-10-30 with the Metal compiler of Xcode 27B47 (Metal 32023.922), compiling the 27 Telegram `.metal` files in 18 directories of the Telegram-iOS-release-13.0.0 reference to `air64-apple-ios12.0` with `-ffast-math` and linking each directory with `metallib`, as `rules_apple` does. The verdicts come from `./xmakew l -P . frameworks/Backports/tools/metal_corpus.lua`. The ffmpeg sources and the `rules_apple` test samples are not included. The sources are the `.metal` files of the `release-13.0.0` tag of `github.com/TelegramMessenger/Telegram-iOS` (commit `f1dd7a2`), fetched with a blobless sparse checkout of the 19 directories that hold them; the tool leaves out the 28th file, under `submodules/ffmpeg`, which leaves 27 files in 18 directories.

Result: 89 entry points (43 fragment, 27 vertex, 19 kernel). Before the changes measured below, 32 translate (18 fragment, 14 vertex) and 57 are refused by name, including all 19 kernels. After the matrix uniforms, 48 translated (21 fragment, 19 vertex, 8 kernel) and 41 were refused. After the intrinsic batch in the section below, 57 translate (27 fragment, 20 vertex, 10 kernel) and 32 are refused; 9 of the 19 kernels are still refused. After the unsigned max, divide and remainder in the last change row of the table, 58 translate (27 fragment, 20 vertex, 11 kernel) and 31 are refused; 8 of the 19 kernels are still refused. The table shows this state. Which of the 32 block the app, and in what order, is in the last section. Refusals are by air2es's own reasons, not by the GLES 2 target, except the clamp-to-zero and the mipmap-filter rows, which are the target's limits (see `frameworks/Backports/src/air2es/NOTES.md`).

| Library | Entry point | Stage | Verdict | Reason |
| --- | --- | --- | --- | --- |
| submodules_AnimationCompression_Resources | dctKernel | kernel | REFUSED | an argument of a kind this emitter does not read |
| submodules_AnimationCompression_Resources | idctKernel | kernel | REFUSED | an argument of a kind this emitter does not read |
| submodules_AnimationCompression_Resources | vertexShader | vertex | REFUSED | a load from a constant table this emitter does not map |
| submodules_AnimationCompression_Resources | samplingIdctShader | fragment | OK |  |
| submodules_AnimationCompression_Resources | samplingRgbShader | fragment | OK |  |
| submodules_AnimationCompression_Resources | samplingYuvaShader | fragment | REFUSED | a sdiv this emitter does not map |
| submodules_Camera_CameraNeo_MetalResources | convertNV12 | kernel | OK |  |
| submodules_Camera_CameraNeo_MetalResources | downsampleNV12 | kernel | OK |  |
| submodules_Camera_CameraNeo_MetalResources | compositeRoundVideo | kernel | OK |  |
| submodules_Camera_MetalResources | vertexPassThrough | vertex | OK |  |
| submodules_Camera_MetalResources | fragmentPassThrough | fragment | OK |  |
| submodules_DrawingUI_MetalResources | vertex_render_target | vertex | OK |  |
| submodules_DrawingUI_MetalResources | vertex_point_func | vertex | REFUSED | an output of kind air.point_size in a vertex function |
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
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBlobVertex | vertex | REFUSED | an unsigned division that is not of bounded integers with a non-zero divisor |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | mainVideoVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | edgeTestVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBackgroundFragment | fragment | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | mainVideoFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | edgeTestFragment | fragment | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | videoBiPlanarToRGBA | kernel | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | videoTriPlanarToRGBA | kernel | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | gaussianBlurHorizontal | kernel | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | gaussianBlurVertical | kernel | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | cameraBlobVertex | vertex | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | mainVideoVertex | vertex | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | cameraBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | mainVideoFragment | fragment | OK |  |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectInitializeParticle | kernel | REFUSED | a shl this emitter does not map |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectUpdateParticle | kernel | REFUSED | an unsigned division that is not of bounded integers with a non-zero divisor |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectVertex | vertex | REFUSED | an unsigned division that is not of bounded integers with a non-zero divisor |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectFragment | fragment | OK |  |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassCrestKernel | kernel | REFUSED | a struct member this emitter does not read in parameters |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassRadialKernel | kernel | REFUSED | a struct member this emitter does not read in parameters |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesVertex | vertex | OK |  |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesContentFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesMultiplyFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesMaskFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesDisplacementFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | dualFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | bt709ToRGBFragmentShader | fragment | OK |  |
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
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | sparkleVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | referenceHighlightVertex | vertex | REFUSED | control flow that reaches one block twice |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | gramDiamondCompositeFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | backgroundStarFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondFragment | fragment | REFUSED | control flow that reaches one block twice |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondLensFragment | fragment | REFUSED | control flow that reaches one block twice |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | sparkleFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Stories_StoryPeerListComponent_MetalResources | cameraBlobVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Stories_StoryPeerListComponent_MetalResources | cameraBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletCardComponent_Resources | walletCardBackgroundVertex | vertex | REFUSED | a struct member this emitter does not read in uniforms |
| submodules_TelegramUI_Components_Wallet_WalletCardComponent_Resources | walletCardBackgroundFragment | fragment | REFUSED | a call to air.any.v2i1 |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountBlur | kernel | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountLayerVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountFragment | fragment | REFUSED | a sample with a linear filter and a clamp-to-zero address: the edge texels read as zero, which OpenGL ES 2 does not have, and an emulation needs the size of the texture |
| submodules_WallpaperBackgroundNode_Resources | wallpaperVertex | vertex | OK |  |
| submodules_WallpaperBackgroundNode_Resources | wallpaperFragment1 | fragment | OK |  |
| submodules_WallpaperBackgroundNode_Resources | wallpaperFragment | fragment | OK |  |

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
| square float matrix uniforms: a `float2x2`, `float3x3` or `float4x4` member of a constant buffer as one `uniform matN`, its column and lane loads as indexes, the host uploads it with `glUniformMatrixNfv` and packs the padded `float3` column (`translate.cpp`, `accessMatrix`; `RevenantMetalPipeline.m`, `RevenantMetalEncoder.m`); a pointer bitcast is an address, not a value (`translate.cpp`, the instruction pass) | 48 | 41 | `vertex_render_target` (DrawingUI) and `diamondVertex` (PremiumDiamondComponent), REFUSED to OK; `vertex_point_func` leaves the matrix for `air.point_size`; `sparkleVertex` leaves it for `air.mix.v2f32`, `referenceHighlightVertex` for a terminator, `diamondFragment` and `diamondLensFragment` for `air.fast_saturate.f32`; the 4S compiles and links all 48 OK programs, and the matrix probe checks the products on the 4S (see the matrix section) |
| the intrinsic maps `sqrt`, `sin`, `cos`, `tan`, `exp`, `floor`, `pow`, `min`, `max`, `clamp` and `mix` at the half and vector widths, `fast_saturate`, `fabs`, `dot`, and `fwidth` with `GL_OES_standard_derivatives` (fragment only); a `switch` terminator as an if / else if chain, the join shared with the branch path (`multiway`, `rejoin`); a scalar integer fragment input or vertex output as a float, because ES 1.00 has no integer varyings; `discard` in a fragment function (`translate.cpp`) | 57 | 32 | `convertNV12` and `downsampleNV12` (the rotation switches), `mainVideoFragment` (both libraries), `bt709ToRGBFragmentShader`, `backgroundStarFragment`, `wallpaperFragment`, `sparkleVertex` and `sparkleFragment`, REFUSED to OK; `compositeRoundVideo` leaves the switch for `air.max.u.i32`; `callBackgroundFragment` leaves `sin` for an address; `referenceHighlightVertex`, `diamondFragment` and `diamondLensFragment` leave the switch or `fast_exp` for control flow that reaches one block twice; `walletCardBackgroundFragment` leaves `fast_pow` for `air.any.v2i1`; the 4S compiles and links all 57 OK programs |
| unsigned `air.max.u.i32` as a select of its operands, and the unsigned divide and remainder of bounded integers (`translate.cpp`, `unsignedDivide`): the quotient is taken in float as `int((float(a) + 0.5) / float(b))`, because the device's integer `/` is off by one at exact multiples; a constant operand must be below 2^23; the `revenant_flip` uniform is declared `highp` in both stages (`needFlip`) | 58 | 31 | `compositeRoundVideo`, REFUSED to OK; the reasons of `callBlobVertex`, `dustEffectUpdateParticle` and `dustEffectVertex` change from the `udiv` and `urem` refusal to the bounded-divisor refusal, and they stay refused; the 4S compiles and links all 58 OK programs |

Checks on the state the table shows (58 OK, 31 REFUSED):

- the ES 2 probe on the 4S over the 58 OK entries and the 27 texture cases of the intrinsic test: 85 PASS and 1 FAIL, the FAIL being the negative control (`REVENANT-DONE programs 86 failures 1`). `convertNV12`, `downsampleNV12` and `compositeRoundVideo` are in that bundle and compile and link; their values are not compared on the device;
- the intrinsic maps `max_u_i32`, `udiv_u_i32` and `urem_u_i32` over all 4096 texels: maxdiff 0 each. The first device run was not exact: `urem` was off at 17 texels (got 11, expected 0, where the device's integer division gave one less at an exact multiple), and `udiv` was off by one at multiples. The integer maps now compare exactly (`revenant_integer` in `es2_main.m`);
- `air2es_check.lua` with `glslangValidator`: 27 of 27 intrinsic functions and 3 of 3 render functions pass;
- the render-pass probe `CVRenderProbe` on the 4S (`CVRENDER-DONE failures 0`): a fill render pass into a BGRA CoreVideo texture, read on the CPU from the pixel buffer, is exact (bad=0), and its negative control (red and blue swapped) differs. A copy from a BGRA CoreVideo texture through `CVMetalTextureGetCleanTexCoords` into a plain texture is exact (bad=0) with the buffer flipped (`ll(0,1) lr(1,1) ur(1,0) ul(0,0)`), and the unflipped corners as a negative control differ;
- the first render run failed to link the fill program (`Uniform precision mismatch 'revenant_flip'`): the fragment default was mediump and the vertex default highp. The flip uniform is `highp` in both stages now, and the link passes on the 4S.

Not verified: the values of `convertNV12`, `downsampleNV12` and `compositeRoundVideo` on the 4S, and a round video run end to end (the Telegram call path, and the NV12 planes bound through the CoreVideo cache).

A verdict does not show that the GLSL compiles. `histogramPrepareFragmentShader` was OK at baseline, and its GLSL assigned a `float` to `gl_FragColor`. On the 4S it fails the ES 2 probe (`ERROR: 0:26: Incompatible types (vec4 and float)`), and `glslangValidator` rejects it for ES 1.00. After `colorOf` both accept it.

Checks on the state the table shows (57 OK, 32 REFUSED):

- the ES 2 probe on the 4S (iPhone4,1, iOS 6.1.3, PowerVR SGX 543) over the 57 OK entries and the 25 texture cases of the intrinsic test: 81 PASS and 1 FAIL, the FAIL being the negative control (`REVENANT-DONE programs 82 failures 1`). The 57 programs compile and link; the texture cases compare values. Earlier, over the 48 OK entries: 48 PASS, 0 FAIL (`REVENANT-DONE programs 48 failures 0`), which compiles and links each one and does not compare values. At the 46-entry state it was 46 PASS; at the 44-entry state 44 PASS; at the earlier 33-entry state 33 PASS, and before `colorOf` 32 PASS, 1 FAIL;
- `air2es_check.lua` with `glslangValidator` over the 18 translated folders: 57 of 57 functions pass at the 57-entry state. At the 48-entry state 48 of 48 passed, and 0 folders failed; before `colorOf` 1 failed;
- `air2es_test.lua`: 15 cases pass;
- the instance probe on the 4S, with the matrix shaders added: 12 PASS, `REVENANT-DONE failures 0`. The nine earlier checks are the device, two pipelines, three instance draws and three element draws; the three matrix checks are the pipeline, the column-major product against the host reference, and the transposed negative control;
- the full corpus rerun (`metal_corpus.lua`, 2026-10-30, the 57-entry state): 57 OK and 32 REFUSED, identical to the scratch tally of the 18 libraries. Nine verdicts changed to OK, six changed reason, and no OK entry became REFUSED. At the 48-entry state: 48 OK and 41 REFUSED. Two verdicts changed to OK (`vertex_render_target`, `diamondVertex`), five entries moved to a later refusal (`vertex_point_func`, `sparkleVertex`, `referenceHighlightVertex`, `diamondFragment`, `diamondLensFragment`), and no OK entry became REFUSED;
- the commit message of `b67923084` lists the element checks incompletely: it names three draws and three element draws and leaves out the device and pipeline checks. The count of nine PASS is right. The commit is not amended.

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

The bitwise `and`, comparison and locals groups are translated as far as the table shows, and the clamp-to-zero samples are kept refused with their reason named (decision above). The blockers listed above are the first refusal of each kernel. Counted by reason, the 41 refusals are: 12 intrinsic gaps (four `fast_saturate`, two `fabs` on half vectors, and one each of `dot`, `mix`, `fwidth`, `tan`, `discard_fragment` and the `point_size` output), 6 liquid glass values and members, 6 integer operations (`udiv`, `urem`, `shl`, `lshr`, `sdiv`), 5 clamp-to-zero linear samples, 4 control-flow terminators, 3 addresses this emitter does not read, 3 argument kinds and constant tables, 1 struct member and 1 linear mipmap sample. The `float4x4` group is gone.

## Intrinsic batch, switch lowering and the 4S checks

The translator changes in `translate.cpp` take the corpus from 48 to 57 OK (the row above). Each new OK entry passes `air2es_check.lua`, which runs `glslangValidator` in ES 1.00 mode, over the 18 translated folders: 57 of 57 functions pass.

What the batch changes:

- Plain maps: `sqrt.f16`, `sin.f16`, `cos.f16`, `tan.f16`, `fast_tan.f32`, `fast_exp.f32` (`exp`), `fast_floor.f32`, `fmin.v3f16`, `fast_fmax.v3f32`, `fast_pow.v3f32`, `clamp.v3f16`, `mix.v2f32`, `mix.v3f16`, `fabs.v3f16`, `dot.v2f16`, and `fast_saturate` at f32, v2f32 and v3f32 as `clamp(x, 0.0, 1.0)`.
- `fwidth.f32` as `fwidth`, with `#extension GL_OES_standard_derivatives : enable` after `#version 100`. It is refused outside a fragment function. The 4S lists `GL_OES_standard_derivatives` (the `GL_EXTENSIONS` line of the `highp` runs).
- A `switch` terminator becomes an `if` / `else if` chain on the switch value. Cases that share a target are one arm joined with `||`, and a case whose target is the default is left to the `else`. Each arm runs its target through the same edge copies as a branch. The join is found by the post-dominator code that the branch path uses (`rejoin`). `convertNV12` and `downsampleNV12` each have one such switch on the rotation of the output.
- A scalar integer fragment input or vertex output travels as a float, because GLSL ES 1.00 has no integer varyings. A `[[flat]]` Metal integer is the same at every fragment of its primitive, so the fragment rounds it back with `int(floor(x + 0.5))`. Bool and integer vector varyings are refused by name. `sparkleVertex` and `sparkleFragment` passed air2es before this change and failed `glslangValidator` (`varying int layer`), so they count as OK only with it.

The 4S checks are in `frameworks/Backports/tests/device_probe/intrinsics/` (`intrinsics.metal`, its translation `intrinsics.metallib.es2/`) and the texture stage of `es2_main.m`. The run was on the 4S (iPhone4,1, iOS 6.1.3, PowerVR SGX 543), with the bundle of the 57 OK programs and the 25 texture cases in the same run: `REVENANT-DONE programs 82 failures 1`.

- The 57 OK programs compile and link: 57 PASS.
- 24 value cases: one fragment function for each of 21 intrinsic maps, the `switch`, and the two planes. Each output byte is compared with a host reference computed in double, with one byte of tolerance for mediump. All 24 pass. The largest difference is one byte for `dot`, `fabs`, `pow`, `saturate`, `mix`, `sqrt` and `tan`, and zero for the others.
- The negative control, `sqrt` times 0.5 against `sqrt`, must fail, and does: 16 of 4096 pixels match. The one failure in the run is that control.
- `fwidth` was first checked against a quad reference on the texel bytes, and failed (1749 of 4096 pixels, the largest difference 28). A diagnostic run, hand-written GLSL that is not in the bundle, measured the derivatives: `dFdx` matches the difference of the two pixels of a 2 by 2 pair at every pixel, but `dFdy` on odd columns is taken from other rows (at row 0 the device's value is the difference of rows 1 and 2). `GL_OES_standard_derivatives` leaves the local differencing to the implementation, so a pair reference is not a valid check. The check now uses a linear ramp, for which every differencing scheme gives the same slope, and it passes exactly. The translated call is the same either way.
- The NV12 planes: the translated shaders read the first channel of an R8 texture (`GL_RED_EXT`) and the first two channels of an RG8 texture (`GL_RG_EXT`) as the texel bytes, exactly. These are the GL formats that `RevenantMetalTexture.m` uses for `r8Unorm` and `rg8Unorm`. This checks the GL side only. The host binding of a `CVPixelBuffer` plane is the CoreVideo texture cache, which is a stub (next).

Round video, reconnaissance:

- `convertNV12` and `downsampleNV12` translate. Their values are not checked on the 4S: the switch lowering is checked through `switch_f32`, not through the kernel.
- `compositeRoundVideo` was refused by `air.max.u.i32`; it translates now (see the last change row of the table).
- Outside air2es (this section was written before the fix): `CVMetalTextureCacheCreate` in `frameworks/Backports/src/CoreVideo/CVMetalTexture80.m` returned `kCVReturnInvalidArgument`, and the other CVMetalTexture functions were stubs. Telegram's `RoundVideoFrameProcessor` returns nil from `init?` when the cache is not created (`RoundVideoFrameProcessor.swift:214`), and `CameraNeo` then reports `videoRecorderInitializationError`. The cache is now implemented on `CVOpenGLESTextureCache` (commits 847b4e79a and a688f806b), and `CVRenderProbe` creates it on the 4S.

Not verified on the device, named here: the 57 OK entries are compiled and linked on the 4S but their values are not compared, except the 21 maps, the `switch` and the two planes above. The integer varyings of the sparkle shaders are compiled and linked only. The `switch` inside `convertNV12` is not value-checked.

## Matrix uniforms (the `float4x4` rows)

Square float matrix members of a constant buffer (`float2x2`, `float3x3`, `float4x4`) are translated (`translate.cpp`, `accessMatrix`) and uploaded by the host (`RevenantMetalEncoder.m`, `uploadUniforms`).

- Translator: the member is one `uniform matN`. A load of a column is `name[c]`, and a load of one lane is `name[c][r]`. A `float3` column is padded to four floats in Metal, so when the padded lane is read it loads as `vec4(name[c], 0.0)`. A matrix that is a vertex attribute is refused.
- Reflection: the uniform entry carries `"columns": N` beside `"components": N`, the row count. `air2es_check.lua` accepts it only for a float `matN` with equal rows and columns.
- Host: `RevenantUniformPlan` has a `columns` field, read from the reflection. For a matrix, `uploadUniforms` packs each column's rows in column-major order (two floats for `float2`, three for `float3`, four for `float4`) and calls `glUniformMatrix2fv`, `3fv` or `4fv` without transposing.
- A pointer bitcast is an address, not a value, so the instruction pass accepts it. The loads and stores through it are checked where they are read. The padded column of the probe's `float3x3` needs this.
- Corpus: `vertex_render_target` (DrawingUI) and `diamondVertex` (PremiumDiamondComponent) are OK. The other matrix rows stop at their next blocker, listed in the changes table.
- Probe: the instance probe has `matrix_column_vertex` and `matrix_column_fragment` (`frameworks/Backports/tests/device_probe/instance/instance.metal`). The vertex stage multiplies `(1, 2, 3, 1)` by `model` and then by `projection`, and writes the product's x and y, `model[3][1]` and `normal[2][1]` (a `float3x3`) into the colour. The host computes the same values in column-major order and expects them in each of the three pixels. A second draw uploads the transposed matrices, and it must fail the same reference. On the 4S the pipeline links, the products and the element reads match, and the transposed draw fails (its first pixel reads `(14,54,1,3)`), so the check tells a layout error from the right layout. Result: 12 PASS, `REVENANT-DONE failures 0`.
- Not measured: a matrix in a fragment shader. No OK fragment uses one, and fragments default to `mediump` float, so a matrix product there needs its own precision check. The values of `vertex_render_target` and `diamondVertex` are not compared with Metal (both are compile and link checked). The host path of `render_target_uniform` in `DrawingMetalView` has not run.

## enhanceGenerateLUT

Still refused, with `an address this emitter does not read`. The kernel reads and writes a histogram buffer in place, and ES 2 has no form for that. The design is in [`air2es-enhance-lut-design.md`](air2es-enhance-lut-design.md): one render pass onto the LUT, one fragment per texel, with each fragment recomputing its tile's clipped histogram, so no fragment depends on another, and the histogram supplied as a texture. It is not built, and it waits for the owner's go. Two decisions come with it. A hand-written replacement is not a translation, so it needs its own verdict word, since OK here means translated. And the enhance lookup that reads the LUT is refused for its clamp-to-zero sampler, so the LUT alone changes no output the user sees.

## What blocks the app: the 32 refusals by user impact

The order is by what the app does with each entry, not by the count. The entries were checked against the release-13.0.0 sources (the read-only reference `Telegram-iOS-release-13.0.0`). Each name was looked up in the Swift and Objective-C sources: every entry has a `makeFunction` call, except `wallpaperFragment`, which has none in this release. Reach on the target (iOS 6.1.3 with the backport) comes from the `#available` gates around the call. The fallback is what the code does at the call site; where a fallback is not traced, the row says so. This is a reading of the code, not a run on a device.

| Priority | Entries | Call site (release-13.0.0) | Reached on iOS 6 | Without it | First refusal | Next step |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `compositeRoundVideo` (CameraNeo), and the round-video path it belongs to | `RoundVideoFrameProcessor.swift:194,214`; `CameraNeo.swift:319–334` | yes; the iOS 13 and 18 gates in `CameraNeo` are multicam and frame rate | round video recording fails with `videoRecorderInitializationError`: the processor's `init?` returns nil when the CoreVideo texture cache is not created, and the backport's cache is a stub | none in air2es now (`compositeRoundVideo` translates); the CoreVideo cache was a stub, now implemented | the three kernels translate and link on the 4S; their values on the 4S and an end-to-end run are next (see the intrinsics section) |
| 2 | `mainVideoFragment` (CallScreen and CameraScreen) | `PrivateCallVideoLayer.swift:91`; `CameraVideoLayer.swift:148` | yes; calls on iOS 6 are not checked | the guard returns nil before the render state exists; the caller's handling is not traced | none: OK in both libraries | the `fabs`, `mix` and `clamp` maps it uses are checked on the 4S; the call path is not |
| 3 | `bt709ToRGBFragmentShader` (MediaEditor) | `VideoInputPass.swift:11` | yes | the editor's video input pass has no conversion (fallback not traced) | none: OK | the `fast_saturate` map is checked on the 4S; the shader itself is not run on a device |
| 4 | `callBlobVertex`, `callBackgroundFragment` (voice call) | `CallBlobsLayer.swift:48`; `CallBackgroundLayer.swift:56` | yes | no animated blobs and no animated background on each call (the layer returns nil) | `udiv` (integer, refused by decision); `callBackgroundFragment`: an address this emitter does not read | the blobs stay off while integer division is refused; the background needs the address rule |
| 5 | `adjustmentsFragmentShader`, `blurRadialFragmentShader`, `blurLinearFragmentShader`, `blurPortraitFragmentShader`, `enhanceColorLookupFragmentShader`, `enhanceGenerateLUT` (MediaEditor) | `AdjustmentsRenderPass.swift:96`; `BlurRenderPass.swift:103`; `EnhanceRenderPass.swift:196` and the LUT pass | yes | the adjust, blur and enhance tools have no output (fallback not traced) | address (adjustments, LUT); clamp-to-zero linear samples (the blurs and the lookup) | the clamp-to-zero decision; the LUT design (linked above) |
| 6 | `diamondFragment`, `diamondLensFragment`, `referenceHighlightVertex`, `backgroundStarVertex` (Premium gem); `sparkleFragment`, `sparkleVertex` and `backgroundStarFragment` are OK | `DiamondRenderer.swift:117–120` (`try? make(...)`, so nil on failure) | yes; no gate in the file | the gem's lazy layers are nil, so the gem is not drawn (the rest of the screen is not traced) | control flow that reaches one block twice (three shaders, the next structurer shape); `lshr` (integer, `backgroundStarVertex`) | the structurer's next shape, which needs a reading of the CFG first; the integer shift stays refused by decision |
| 7 | `vertex_point_func` (DrawingUI) | `DrawingMetalView.swift:344` (`if let`) | yes | the point vertex function is not set (fallback not traced) | an output of kind `air.point_size` | point size as `gl_PointSize`, then check |
| 8 | `dustEffectVertex`, `dustEffectInitializeParticle`, `dustEffectUpdateParticle` (DustEffect) | `DustEffectLayer.swift` (the file's iOS 15 gate is the signposter only) | yes | the dust effect is not shown (fallback not traced) | `urem`, `shl` and a divisor read from a buffer (integer, refused by decision) | stays refused by decision |
| 9 | `matrixFragment` (PremiumUI, DataRain) | `DataRainView.swift:51` (`guard`) | yes | the background is not drawn (fallback not traced) | a linear sample with a mipmap filter, and GLES 2 has no mipmaps | a rewrite without mipmaps, by design |
| 10 | `walletAmountBlur`, `walletAmountFragment` (Wallet send) | `WalletSendAmountCanvas.swift:36` (`guard`) | yes; the file has no gate | the amount blur is not shown (fallback not traced) | an address this emitter does not read; clamp-to-zero linear samples | last: a rare feature, and both blockers are decisions |
| 11 | liquid glass: `liquidGlassShapesContentFragment`, `liquidGlassShapesMultiplyFragment`, `liquidGlassShapesMaskFragment`, `liquidGlassShapesDisplacementFragment`, `liquidGlassCrestKernel`, `liquidGlassRadialKernel` | `LiquidGlassShapesLayer.swift:234` (`#available(iOS 26.0)`) | no | not reached | struct values and members | none needed for iOS 6 |
| 12 | sticker compression: `dctKernel`, `idctKernel`, `vertexShader`, `samplingYuvaShader` | `AnimatedStickerNode.swift:296–300` (`#available(iOS 10.0)`; otherwise the software renderer) | no | not reached | an argument kind, a constant table, and `sdiv` | none needed for iOS 6 |
| 13 | wallet card background: `walletCardBackgroundVertex`, `walletCardBackgroundFragment` | `WalletCardBackgroundView.swift:231` (the file has an iOS 13 gate; the Metal path was not traced to it) | probably no | not reached | `air.any.v2i1` (fragment); a struct member in uniforms (vertex) | none needed for iOS 6 |
| 14 | `wallpaperFragment` | none in release-13.0.0 | no | OK: translated, nothing calls it | none | none |

Order of work, for the owner to set:

1. Round video recording (row 1): the three kernels translate and link on the 4S, and the render-pass path into a CoreVideo texture with flipped coordinates is shown on the 4S. Not yet shown: the kernels' values on the 4S, and a round video run end to end.
2. Video frames (row 2), the editor's video input (row 3) and the premium sparkles (row 6): translated now. Their device checks cover the maps they use, not the whole shader.
3. The call blobs (row 4): the blobs need integer division, which is a decision; the background needs the address rule.
4. The rest, in the order above. Rows 4, 5, 8 and 10 each include a blocker that is a decision: integer operations, clamp-to-zero samples, or the address rules. Those stay refused until the decision changes.

The cheap intrinsic maps are built, and the ones listed in the intrinsics section are checked on the 4S. A check covers a map, not the whole shader.
