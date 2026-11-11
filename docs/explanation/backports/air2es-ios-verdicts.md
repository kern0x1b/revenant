# air2es on Telegram's iOS Metal sources: per-shader verdicts

Measured 2026-10-30 with the Metal compiler of Xcode 27B47 (Metal 32023.922), compiling the 27 Telegram `.metal` files in 18 directories of the Telegram-iOS-release-13.0.0 reference to `air64-apple-ios12.0` with `-ffast-math` and linking each directory with `metallib`, as `rules_apple` does. The verdicts come from `./xmakew l -P . frameworks/Backports/tools/metal_corpus.lua`. The ffmpeg sources and the `rules_apple` test samples are not included. The sources are the `.metal` files of the `release-13.0.0` tag of `github.com/TelegramMessenger/Telegram-iOS` (commit `f1dd7a2`), fetched with a blobless sparse checkout of the 19 directories that hold them; the tool leaves out the 28th file, under `submodules/ffmpeg`, which leaves 27 files in 18 directories.

Result: 89 entry points (43 fragment, 27 vertex, 19 kernel). Before the changes measured below, 32 translate (18 fragment, 14 vertex) and 57 are refused by name, including all 19 kernels. After the matrix uniforms, 48 translated (21 fragment, 19 vertex, 8 kernel) and 41 were refused. After the intrinsic batch in the section below, 57 translate (27 fragment, 20 vertex, 10 kernel) and 32 are refused; 9 of the 19 kernels are still refused. After the unsigned max, divide and remainder in the last change row of the table, 58 translate (27 fragment, 20 vertex, 11 kernel) and 31 are refused; 8 of the 19 kernels are still refused. After the clamp-to-zero emulation, 63 translate (32 fragment, 20 vertex, 11 kernel) and 26 are refused. After the bounded integers, 64 translate (32 fragment, 21 vertex, 11 kernel) and 25 are refused. After the switch change, 65 translate (32 fragment, 22 vertex, 11 kernel) and 24 are refused. After the half-precision change and the instance-id correction, 64 translate (32 fragment, 21 vertex, 11 kernel) and 25 are refused. After the host element cap of `callBlobVertex` in its change row, 65 translate (32 fragment, 22 vertex, 11 kernel) and 24 are refused. After the point size and `any` change in the last row of the table, 66 translate (32 fragment, 23 vertex, 11 kernel) and 23 are refused. The table shows the state after the last row. Which of the 26 block the app, and in what order, is in the last section, which predates that row. Refusals are by air2es's own reasons, not by the GLES 2 target, except the mipmap-filter row, which is the target's limit (see `frameworks/Backports/src/air2es/NOTES.md`).

| Library | Entry point | Stage | Verdict | Reason |
| --- | --- | --- | --- | --- |
| submodules_AnimationCompression_Resources | dctKernel | kernel | REFUSED | an argument of a kind this emitter does not read |
| submodules_AnimationCompression_Resources | idctKernel | kernel | REFUSED | an argument of a kind this emitter does not read |
| submodules_AnimationCompression_Resources | vertexShader | vertex | REFUSED | a load from a constant table this emitter does not map |
| submodules_AnimationCompression_Resources | samplingIdctShader | fragment | OK |  |
| submodules_AnimationCompression_Resources | samplingRgbShader | fragment | OK |  |
| submodules_AnimationCompression_Resources | samplingYuvaShader | fragment | REFUSED | a division of an integer with no known bound |
| submodules_Camera_CameraNeo_MetalResources | convertNV12 | kernel | OK |  |
| submodules_Camera_CameraNeo_MetalResources | downsampleNV12 | kernel | OK |  |
| submodules_Camera_CameraNeo_MetalResources | compositeRoundVideo | kernel | OK |  |
| submodules_Camera_MetalResources | vertexPassThrough | vertex | OK |  |
| submodules_Camera_MetalResources | fragmentPassThrough | fragment | OK |  |
| submodules_DrawingUI_MetalResources | vertex_render_target | vertex | OK |  |
| submodules_DrawingUI_MetalResources | vertex_point_func | vertex | OK |  |
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
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBlobVertex | vertex | OK |  |
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
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectInitializeParticle | kernel | REFUSED | a shift left of an integer with no known bound below 2^22, or by something other than a constant below 32 |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectUpdateParticle | kernel | REFUSED | a division of an integer with no known bound |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectVertex | vertex | REFUSED | a division of an integer with no known bound |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectFragment | fragment | OK |  |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassCrestKernel | kernel | REFUSED | a struct member this emitter does not read in parameters |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassRadialKernel | kernel | REFUSED | a struct member this emitter does not read in parameters |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesVertex | vertex | OK |  |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesContentFragment | fragment | REFUSED | a local of a type this emitter does not hold as a variable |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesMultiplyFragment | fragment | REFUSED | a local of a type this emitter does not hold as a variable |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesMaskFragment | fragment | REFUSED | a load from an address this emitter does not read |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesDisplacementFragment | fragment | REFUSED | a load from an address this emitter does not read |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | dualFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | bt709ToRGBFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | defaultVertexShader | vertex | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | defaultFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | histogramPrepareFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | gradientFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | adjustmentsFragmentShader | fragment | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | enhanceGenerateLUT | kernel | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | rgbToLightnessFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | enhanceColorLookupFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurRadialFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurLinearFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurPortraitFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | gramDiamondCompositeVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | backgroundStarVertex | vertex | REFUSED | a logical shift right of an integer with no known bound |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | sparkleVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | referenceHighlightVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | gramDiamondCompositeFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | backgroundStarFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondFragment | fragment | REFUSED | control flow that reaches one block twice |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondLensFragment | fragment | REFUSED | control flow that reaches one block twice |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | sparkleFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Stories_StoryPeerListComponent_MetalResources | cameraBlobVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Stories_StoryPeerListComponent_MetalResources | cameraBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletCardComponent_Resources | walletCardBackgroundVertex | vertex | REFUSED | a struct member this emitter does not read in uniforms |
| submodules_TelegramUI_Components_Wallet_WalletCardComponent_Resources | walletCardBackgroundFragment | fragment | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountBlur | kernel | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountLayerVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountFragment | fragment | OK |  |
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
| clamp-to-zero samples emulated (`samplers.cpp`, `translate.cpp`, `emulatedSample`): a constexpr sampler with a clamp-to-zero address becomes four nearest fetches per linear sample, each masked to zero outside the texture, with the texel count from the `<texture>_size` uniform the host already sets; a clamp-to-edge or repeat axis is clamped or wrapped in the shader, so the host binds nearest and clamp-to-edge; a clamp-to-zero address whose minification and magnification filters differ stays refused, since the level of detail is not computed; a clamp-to-zero cube sample stays refused | 63 | 26 | the three MediaEditor blurs, `enhanceColorLookupFragmentShader` and `walletAmountFragment` (Wallet send), REFUSED to OK; the blurs and the lookup are checked against Metal on the Mac (see the clamp-to-zero section) |
| bounded integers: division, remainder, shift left and logical shift right of bounded integers, computed in float and exact below 2^16 for the operands and 2^22 for the results (`translate.cpp`, `boundOf`, `integerDivide`, `shiftLeft`, `shiftRight`); the bounds are a constant, a vertex or instance id, a buffer member and a float converted to unsigned, all taken below 2^16 (see the bounded-integers section) | 64 | 25 | `dustEffectVertex` (DustEffect), REFUSED to OK; `compositeRoundVideo` keeps its OK with a new division text; the reasons of `callBlobVertex`, `samplingYuvaShader`, `dustEffectUpdateParticle`, `dustEffectInitializeParticle` and `backgroundStarVertex` change and they stay refused |
| switch arms that fall through to the default block: the default block is emitted again on each path that reaches it, with the visited blocks kept per arm (`translate.cpp`, `multiway`), so a block reached by two paths before the join is not refused | 65 | 24 | `referenceHighlightVertex` (Premium gem), REFUSED to OK; no other entry changes, the 89 verdicts and the other 64 OK outputs are byte-identical |
| `half` values declared `mediump float` at each declaration site (`declaredType`, `translate.cpp`, see the half-values section); a struct returned by an inlined call taken from the returned fields (`aggregates_`, `Frame::fields`); an undefined argument the callee does not use dropped; the bounds of an inlined argument followed to its actual value; `sdiv` and `srem` bounded as `udiv` and `urem`; an instance id has no bound (`boundOf`), which corrects the earlier bounded-integer row | 64 | 25 | `dustEffectVertex` (DustEffect), OK to REFUSED: its instance id runs to the particle count, the item's width times its height in points, 153,600 for the layer-sized MediaCutout item on the 4S, above the 2^16 bound (see the bounded-integers section); `callBlobVertex` and the four liquid glass fragments change reason; the other verdicts are the same; 33 corpus `.glsl` files change only by `mediump` |
| a buffer argument with an element count that the host declares (`kBufferCaps`, `Binding::capCount`, `resolve`, `selectMember`): a `const device` scalar pointer read at a dynamic index is one uniform per element, and the index is a select chain over them, as for an array member of a buffer struct; `air.fast_atan2.f32` as GLSL `atan(y, x)` (`kPlainFunctions`); an `extractvalue` of an inlined call's returned struct, read from the fields captured at the return (`aggregateTexts_`) | 65 | 24 | `callBlobVertex` (CallScreen), REFUSED to OK (its `positions` buffer, capped at the host's 8 elements, and its `atan2` and struct field); the other 88 verdicts are the same; the CallScreen folder gains `callBlobVertex` and eight `positions_k` uniforms on buffer 1, and no other `.glsl` changes |
| a vertex output of kind `air.point_size` as `gl_PointSize`, a float only (`translate.cpp`, the return path), and `air.any.v2i1` as GLSL `any` (`kPlainFunctions`) | 66 | 23 | `vertex_point_func` (DrawingUI), REFUSED to OK; `walletCardBackgroundFragment` keeps its REFUSED, now at an address this emitter does not read; the other 87 verdicts are the same; the DrawingUI folder passes `air2es_check.lua` and glslangValidator (4 of 4 functions); the translator does not clamp the size, the GLES driver clamps it to its aliased point size range, which may differ from Metal's, and the size is not measured on a device |
| a macOS `air.sample_texture_2d.v4f32` sample, nine operands, as GLSL `texture2D` of its colour: `min_lod_clamp` must be the constant 0.0 and the access must be sample, and the residency element of the result is refused if used (`translate.cpp`, `sampleLocal`, the sample gate; see the macOS section) | 66 | 23 | none on the iOS corpus, which has no macOS sample: the 89 verdicts and the 66 OK outputs are the same (`new8` = `new7`); the fixture `tests/air2es/sample_mac` gives `sampleVertex` and `sampleFragment` OK and `sampleMinLodFragment` REFUSED by name, and the harness matches Metal on `sampleFragment` with a max diff of 0 over 13,312 non-zero channels |
| a constant loop with a break: the loop's latch is found by reachability from its header, and a block that the header branches to and that flows to the loop's exit is part of the body; each exit copies the exit phis before it breaks (`translate.cpp`, `latchCycleOf`, `bodyOf`) | 66 | 23 | none on the iOS corpus: the 89 verdicts and the 66 OK outputs are byte-identical to the previous state; `tests/air2es/exit_mac` gives `exitFragment` OK, and the Mac harness matches Metal on it with a max diff of 0 over 16,062 non-zero channels (see the loops section) |
| derivatives of a `float2` and a `float3`: `air.dfdx.v2f32` as GLSL `dFdx`, and `air.fwidth.v3f32` as `fwidth`, both with `GL_OES_standard_derivatives` and fragment only, and `air.dfdy.v2f32` as `-dFdy`, since GL's y axis points up and Metal's points down (`kPlainFunctions` with its `sign` field, `translate.cpp`; see the derivatives section) | 66 | 23 | none on the iOS corpus: the 89 verdicts and the 66 OK outputs are byte-identical; `tests/air2es/deriv_mac` gives `derivFragment` OK, and the Mac harness matches Metal on it with a max diff of 0 over 14,368 non-zero channels; `tests/air2es/dfdy_mac` gives `dyFragment` OK with a max diff of 0 over 8,192 non-zero channels, and its negative control fails |
| a counted loop whose bound is a uniform, cut at the host cap of the capped buffer its body indexes (`latchCycleOf`, `loopCapOf`), with the latch test kept in the body so the loop stops at the uniform's count; a loop whose body is one block (header and latch) with a runtime bound; a host-capped buffer of `float2` to `float4` elements, one uniform per element (`translate.cpp`, the cap check) | 66 | 23 | none on the iOS corpus: the 89 verdicts and the 66 OK outputs are byte-identical; `tests/air2es/loop_mac` gives `loopFragment` OK, and the Mac harness matches Metal at counts 0, 1, 3 and 8 with a max diff of 0 over 16,384 channels each (see the runtime-bounded loops section) |
| a bitwise and of an integer with a known bound that is `2^k - 1`, as `int(mod(float(x), 2^k))` (`maskAnd`, `boundOf`); a loop index's bound is its trip count, so `(i + 1) % 8` in a loop of eight is exact (`indexBounds_`); the diamond's host caps, planes 17 and edges 128, and the select limit of 128 (`kBufferCaps`, `selectMember`) | 66 | 23 | none on the iOS corpus: the 89 verdicts and the 66 OK outputs are byte-identical; `tests/air2es/mask_mac` gives `maskFragment` OK with a max diff of 0 over 16,384 channels, and its negative control fails with 9/255 over 4,096 channels; the Mac diamond stays REFUSED on its control flow |
| a loop whose latch tests a header flag that is a constant on entry and on the back edge, as a `for` of the passes the flag gives (`flagCycleOf`); a helper's blocks inside a caller's loop (`insideLoop`); `air.sign.f32` as `sign`, `air.mix.v4f32` as `mix`, and `air.fast_asin.f32` as `asin` (`kPlainFunctions`) | 66 | 23 | none on the iOS corpus: the 89 verdicts and the 66 OK outputs are byte-identical; `tests/air2es/flag_mac` gives `flagFragment` OK with a max diff of 0 over 16,384 channels, and its negative control fails with 31/255 over 576 channels; on the Mac library `diamondFragment` becomes OK, and `diamondLensFragment` stays REFUSED |
| two members of one name in two uniform or vertex buffers (a lens's `viewport` and the stone's `viewport`) were declared once, so a load of the second read the first; they are now prefixed with their argument's name (`memberName`), and a name claimed at another offset is refused (`claimSlot`) | 66 | 23 | none on the iOS corpus: the 89 verdicts and all 150 output files are byte-identical; `tests/air2es/shared_mac` gives `sharedFragment` OK with a max diff of 0 over 13,312 channels, and its negative control, the pre-fix translator, fails with 255/255 over 8,192 of 16,384 channels; on the Mac library the lens reads `lens_viewport` and `lens_parameters`, and `diamondLensFragment` passes the oracle at all four uniform sets |
| a block reached from both arms of a branch is emitted in each arm, with the visited set reset per arm (`region`, as `multiway` does); on the Mac library `diamondLensFragment` becomes OK | 66 | 23 | none on the iOS corpus: the 89 verdicts and the 66 OK outputs are byte-identical; the Mac library's `diamondFragment` and `diamondLensFragment` translate, and the Mac diamond oracle is blank for them, so it proves nothing yet (see the section below) |

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
| 7 | `vertex_point_func` (DrawingUI) | `DrawingMetalView.swift:344` (`if let`) | yes | the point vertex function is not set (fallback not traced) | none: OK, `air.point_size` is `gl_PointSize` | the point size is not measured on a device; check it against Metal's |
| 8 | `dustEffectVertex`, `dustEffectInitializeParticle`, `dustEffectUpdateParticle` (DustEffect) | `DustEffectLayer.swift` (the file's iOS 15 gate is the signposter only) | yes | the dust effect is not shown (fallback not traced) | `urem`, `shl` and a divisor read from a buffer (integer, refused by decision) | stays refused by decision |
| 9 | `matrixFragment` (PremiumUI, DataRain) | `DataRainView.swift:51` (`guard`) | yes | the background is not drawn (fallback not traced) | a linear sample with a mipmap filter, and GLES 2 has no mipmaps | a rewrite without mipmaps, by design |
| 10 | `walletAmountBlur`, `walletAmountFragment` (Wallet send) | `WalletSendAmountCanvas.swift:36` (`guard`) | yes; the file has no gate | the amount blur is not shown (fallback not traced) | an address this emitter does not read; clamp-to-zero linear samples | last: a rare feature, and both blockers are decisions |
| 11 | liquid glass: `liquidGlassShapesContentFragment`, `liquidGlassShapesMultiplyFragment`, `liquidGlassShapesMaskFragment`, `liquidGlassShapesDisplacementFragment`, `liquidGlassCrestKernel`, `liquidGlassRadialKernel` | `LiquidGlassShapesLayer.swift:234` (`#available(iOS 26.0)`) | no | not reached | struct values and members | none needed for iOS 6 |
| 12 | sticker compression: `dctKernel`, `idctKernel`, `vertexShader`, `samplingYuvaShader` | `AnimatedStickerNode.swift:296–300` (`#available(iOS 10.0)`; otherwise the software renderer) | no | not reached | an argument kind, a constant table, and `sdiv` | none needed for iOS 6 |
| 13 | wallet card background: `walletCardBackgroundVertex`, `walletCardBackgroundFragment` | `WalletCardBackgroundView.swift:231` (the file has an iOS 13 gate; the Metal path was not traced to it) | probably no | not reached | an address this emitter does not read (fragment, after `air.any.v2i1`, which translates now); a struct member in uniforms (vertex) | none needed for iOS 6 |
| 14 | `wallpaperFragment` | none in release-13.0.0 | no | OK: translated, nothing calls it | none | none |

Order of work, for the owner to set:

1. Round video recording (row 1): the three kernels translate and link on the 4S, and the render-pass path into a CoreVideo texture with flipped coordinates is shown on the 4S. Not yet shown: the kernels' values on the 4S, and a round video run end to end.
2. Video frames (row 2), the editor's video input (row 3) and the premium sparkles (row 6): translated now. Their device checks cover the maps they use, not the whole shader.
3. The call blobs (row 4): the blobs need integer division, which is a decision; the background needs the address rule.
4. The rest, in the order above. Rows 4, 5, 8 and 10 each include a blocker that is a decision: integer operations, clamp-to-zero samples, or the address rules. Those stay refused until the decision changes.

The cheap intrinsic maps are built, and the ones listed in the intrinsics section are checked on the 4S. A check covers a map, not the whole shader.

## Clamp-to-zero samples (2026-11-11)

The earlier decision kept the clamp-to-zero linear samples refused, with the integer operations, because the translator
did not emulate them. The brief of 2026-11-11 (coordinator aa549f85) changes that decision for clamp-to-zero samples, so
they are emulated with the real semantics: a sample at uv reads the texels of a linear or nearest filter, and a texel
outside the texture reads zero. Each tap is one nearest fetch of the texel centre, multiplied by a mask that is 1 inside
the texture and 0 outside, on each clamp-to-zero axis. The texel count is the host's `<texture>_size` uniform. An axis
that is clamp-to-edge is clamped in the shader, and a repeat axis is wrapped in the shader, so the host binds nearest
and clamp-to-edge for these textures and the wrap of a non-power-of-two texture does not matter.

Measured on the Mac, not on the phone:

- Metal's own output for the MediaEditor bundle (compiled to `air64-apple-macos14.0` for the Mac's Metal, from the same
  sources) against the air2es GLSL on ANGLE, through `metal_shader_harness`: `blurRadialFragmentShader`,
  `blurLinearFragmentShader`, `blurPortraitFragmentShader` and `enhanceColorLookupFragmentShader` each PASS, with a maximum
  channel difference of 1/255 over about 15,800 non-zero channels.
- A negative control on the same folder, with the clamp-to-zero masks removed from `blurRadialFragmentShader`, FAILs with
  a maximum difference of 174/255 over 1,401 channels. The harness does discriminate the edge rule.
- `walletAmountFragment` is not compared on the Mac: the harness reports its Metal output as blank, because its vertex
  reads a quad from a buffer the harness does not fill, and a blank case proves nothing. It uses the same emulation as the
  blurs. Its translation passes glslangValidator and the Appendix A checker, as the three blurs and the lookup do.
- The corpus translation of all 18 libraries, with the binary of the commit before this change and with the change: the
  only outputs that differ are the five new functions. Every other `.glsl` and `.json` is byte-identical.
- `./xmakew l -P frameworks/Backports frameworks/Backports/tests/air2es_test.lua` passes, with the decode of two new
  constexpr states: a linear clamp-to-zero sampler is accepted, and a clamp-to-zero sampler with a linear minification and a
  nearest magnification is refused.

Not measured: the nearest filter with a clamp-to-zero address, and a repeat axis with a clamp-to-zero axis. Both are
emitted by the same helper, and no corpus entry uses them. A cube sample with a clamp-to-zero address stays refused.

## Bounded integers (2026-11-11)

The brief of 2026-11-11 (coordinator aa549f85), group 1, asked for shifts and unsigned division with the real semantics.
The translator now lowers them when it can see a bound on the operands, and it refuses the rest by name. The thread-position
shift path is unchanged.

What is computed:

- A bound is the largest value of a non-negative integer. It is known for a constant; a vertex id; a member of a buffer; a
  float converted to an unsigned integer; and a `max`, `add`, `udiv`, `urem`, `shl` or `lshr` of bounded values. A bound above
  2^22 is not known. An instance id has no bound. A DustEffect draw has one instance per particle, and the particle count is
  the item's width times its height in points (`submodules/TelegramUI/Components/DustEffect/Sources/DustEffectLayer.swift:255-257`
  and `:337-339`). The item of `MediaEditorScreen/Sources/MediaCutoutScreen.swift:259` is the effect layer's own bounds, and at the
  4S's 320 by 480 points that is 153,600 particles. The shader divides that id by the column count (`DustEffect/Metal/DustEffectShaders.metal:148-149`),
  and the translator refuses the division: the quotient is a row index, so the float division would be exact at these sizes on the
  device model, but the operand is above the 2^16 limit that the division is checked against.
- The host inputs taken below 2^16 are a contract on the host, which the shader does not check: a draw of 65536 or more
  vertices, or a buffer integer of 65536 or more, is outside it. The vertex counts with a bounded vertex id are 6 for the
  quads (`DustEffect/Sources/DustEffectLayer.swift:360`, `CallScreen/Sources/Components/CallBackgroundLayer.swift:225`), 4 for the
  wallet quads with `WalletSendScreen/Sources/WalletSendAmountCanvas.swift:82` and `WalletCardComponent/Sources/WalletCardBackgroundView.swift:461`,
  and `3 * 8 * points.count` for the blobs (`CallScreen/Sources/Components/CallBlobsLayer.swift:152`). The buffer members are the
  DustEffect grid, `particleResolution` set from the item's width and height in points (`DustEffectLayer.swift:353`), at most the
  screen size; the blob point count of 8 (`CallBlobsLayer.swift:113`); and the gem's plane count from its fixed geometry
  (`Premium/PremiumDiamondComponent/Sources/InteractiveDiamond/DiamondRenderer.swift:169`). The Telegram tree is the
  `release-13.0.0` reference, and all paths are relative to `submodules/TelegramUI/Components/` unless they name a directory.
- No host-side check is added. A range check needs the buffer contents at draw creation, which the Metal layer does not read,
  so the limits are documented here and not checked.
- A division or remainder takes operands below 2^16 and is computed in float. The quotient `floor((a + 0.5) / d)` is within one
  of the exact quotient, so the remainder `a - q * d` lies in [-d, 2d), and one more `floor((r + 0.5) / d)` gives the exact
  quotient. A divisor of zero is undefined in LLVM, and the translation takes it as 1.
- A shift left by a constant stays exact below 2^22, as `float(x) * 2^k`. A logical shift right by a constant is
  `floor(float(x) * 2^-k)`, with 2^-k written as a decimal literal of exactly k digits, so it is exact for any bounded x.
- A signed division or remainder is translated only where both operands are known non-negative, as the unsigned one is.
- A zero divisor is taken as 1. The divisors of the translated shaders are constants, and in DustEffect the column count of
  the grid. A zero column count gives zero instances (`DustEffectLayer.swift:257`), so the vertex shader does not run with
  a zero divisor. A divisor that the host sets from a buffer and that could be zero is not checked; the translator refuses
  the divisions it cannot bound, and the zero case is documented here, not checked.

Measured:

- The float formulas in IEEE binary32 against exact integers, in a scratch check that is not committed. For every dividend
  below 2^16 and 465 divisors (1 to 256, nine chosen values, and 200 random values below 2^16), that is 30,474,240 cases per
  error level, with the float division modelled as `(x / d) * (1 + e)`. The corrected quotient and remainder are exact at
  every error level tried, from zero to plus or minus 2^-17. The uncorrected formula the translator emitted before has 2,462
  failures at +2^-17 and none at the other levels, so the correction is what makes the division exact. The shift literals
  are the exact float 2^-k for k from 0 to 31; 399,760 shl cases and 6,400,000 lshr cases agree with integer shifts.
- The corpus of 89 entry points, rerun on the iOS AIR of the 18 libraries after the half-precision change: 64 translate. Against
  the switch-change run, the only verdict that changed is `dustEffectVertex`, OK to REFUSED. `compositeRoundVideo` stays OK.
  Of the 34 files that differ, 33 `.glsl` files differ only by `mediump` (see the half-values section); the DustEffect
  `library.json` loses `dustEffectVertex`.
- `air2es_check` with glslangValidator on the new corpus folders: all 64 translated functions pass (DustEffect 1 of 1,
  CameraNeo 3 of 3, and the rest as in the table). `./xmakew l -P frameworks/Backports frameworks/Backports/tests/air2es_test.lua`
  passes its 15 checker cases and the sampler checks.
- The ES 2 probe folders (`tests/device_probe/intrinsics`, `instance` and `cvrender`) are regenerated from their `.metal`
  sources with the pinned Metal compiler (`metal -c -target air64-apple-ios12.0 -ffast-math`, then `metallib`). The base
  translator reproduced the checked-in intrinsic folder byte for byte, so the pipeline matches. What changes is the `mediump`
  declarations (26 intrinsic files and one cvrender file) and the `highp` `revenant_flip` uniform of the earlier group, which the
  instance folder (3 files) did not carry. `udiv_u_i32` and `urem_u_i32` change only by `mediump`. The 4S compared the old two
  maps exactly over all 4096 texels, so the next probe run tests the new formula.

Not measured on the phone. The regenerated `udiv_u_i32` and `urem_u_i32` have not run on the 4S: the probe app needs an iOS
build that the worktree does not have. The next probe run must show both maps exact (maxdiff 0). It also tests the float
division of the device, which the 2^-18 limit depends on, and the int range of the results, which ES 1.00 guarantees only
at 16 bits for highp int. The Mac harness is no substitute: it draws instance 0 only and sets each int uniform to 0 or 1, so
it runs `0 / n` and `1 / n` and does not exercise the division.

Still refused, with the reason:

- `dustEffectVertex` is refused again, for the instance-id bound above: its particle id runs to the particle count, which
  is above 2^16 on the 4S. The DustEffect effect also needs its two particle kernels. Both store to a device buffer
  (`particles[gid] = particle`), which the translator does not write (it writes only textures), so they stay refused:
  `dustEffectInitializeParticle` (a shift of an unbounded hash, and the store) and `dustEffectUpdateParticle` (a division by
  `size.x * size.y`, a product with no bound here, and the store). Until a buffer-writing kernel is designed, the effect is not
  shown; the vertex alone is not an effect.
- `callBlobVertex` (CallScreen) translates now (the last row of the table). Its `positions` buffer is a host cap of 8 elements:
  `CallBlobsLayer.swift:113` (`Blob(count: 8, ...)`), `:146` (`setVertexBytes` of `points.count` floats) and `:152`
  (`vertexCount` of `3 * 8 * points.count`). The host passes the count buffer as the same 8, so the dynamic index stays below
  8 (`CallScreen/Metal/CallScreenShaders.metal:204`, `:156`). The cap is `kBufferCaps` in `translate.cpp`. The shader reads the
  index through eight uniforms `positions_0` to `positions_7` on buffer 1 and a select chain. The loader reads uniform bytes at
  their offsets without a length check, so a host that set fewer than 8 floats would read past its bytes. The cap was checked
  by reading the Swift code, not by a run, and the device check of this function is owed.
- `diamondFragment` and `diamondLensFragment` (PremiumDiamond) stay refused. Their bounds are real: the planes loop of
  `coolInnerGlow` runs to `uint(u.viewport.z)`, the plane count of the fixed geometry (`DiamondGeometry.swift:50`,
  `DiamondRenderer.swift:169`), and the lens loop runs to the edge count, which the host caps at 128
  (`DiamondRenderer.swift:272-273`). The translator does not lower these loops. In the AIR the planes loop is rotated: its
  latch tests the index against the converted bound, and its exit is the post-loop block, which has phis; its body has an
  `if`; and a zero-trip guard comes before it. Lowering it needs a structurer change for rotated runtime-bounded loops with exit
  phis and multi-block bodies, and the lens edges need a loader rule for a buffer shorter than its cap. No oracle is available
  for such a loop: the Mac harness needs `REVENANT_ANGLE_CEF`, and the phone is claimed.
- `backgroundStarVertex` (PremiumDiamond): `starRandom` is a 32-bit finaliser (xorshift, a wrap-around multiply by two
  constants, then the low 24 bits). It needs all 32 bits, and no bound applies. ES 1.00 has no bit operators, and a float
  product does not wrap exactly. A wide-integer representation (two 16-bit halves in float, with 8-bit limbs for the product)
  would be needed; it is not built here, so the function stays refused. The coordinator's option of an exact emulation in a highp
  vertex shader was not attempted in this change; the refusal stands on the bit-level reason above, and the attempt is open.
- `samplingYuvaShader`: a division of an integer with no known bound (a signed value the translator cannot see as
  non-negative).

The statements earlier in this file that `dustEffectVertex` and `dustEffectUpdateParticle` stay refused for their divisor are
superseded for the bounded case by this section, and this section is superseded for `dustEffectVertex` by its correction: the
instance id has no bound, so `dustEffectVertex` is refused again.

## Half values as mediump (2026-11-11)

The coordinator decided on 2026-11-11 that `half` maps to `mediump float`, and asked for the precision to be documented. The
translator declares a `half` value, or a vector of them, as `mediump float` (or `mediump vec2`, `vec3`, `vec4`) at each
declaration site: locals and temporaries, phi copies, fragment varyings, vertex outputs, struct fields and local slots
(`declaredType` in `translate.cpp`). Constructors keep the plain type names, which carry no precision.

Precision. Metal's `half` has a 10-bit mantissa and a range up to 65504. The GLSL ES 1.00 minimum for `mediump` is a 10-bit
mantissa and a range of plus or minus 2^14 (GLSL ES 1.00 specification, section 4.5.2). So the mapping keeps Metal's
precision and has a smaller range: a value above 2^14 is not guaranteed on a device that implements only the minimum. The
translation does not promise more precision than Metal's half, and it relies on no device that runs `mediump` at a higher
precision.

Where it applies. A fragment shader already defaults to `mediump float` (the loader's `precision mediump float;`), so the
declaration changes no value there. A vertex shader defaults to `highp`, so the declaration lowers its half values to the
`mediump` above. The changed text is declarations only: the 33 corpus `.glsl` files that differ from the switch-change run each differ by
`mediump` alone, and 27 probe files differ by `mediump` alone.

Checks. The checker and glslangValidator pass all 64 translated functions of the corpus. The verdict changes are the ones in the
table: `callBlobVertex` and the four liquid glass fragments change reason, and `dustEffectVertex` is refused for its instance
id, which is not a precision effect.

Not measured. No pixel comparison of a `mediump` output against Metal's `half` has been made. The Mac harness
(`metal_shader_harness`) needs `REVENANT_ANGLE_CEF`, which this worker does not have, and the phone check of the regenerated
probe folders is owed (the bounded-integers section). The precision claim rests on the specification, not on a measurement.

## macOS sample_texture_2d (2026-11-11)

The brief of 2026-11-11 (coordinator aa549f85) asked for the macOS sample form to map in general, with a fixture test, so that the Mac harness can check a sampled shader against Metal. The corpus is iOS, so this changes no verdict on it.

The form. On `air64-apple-macos13.0` a sample is `air.sample_texture_2d.v4f32` with nine operands: the texture, the sampler state, the coordinate (`<2 x float>`), `normalized` (i1), the offset (`<2 x i32>`), `hasLod` (i1), the level or bias (float), `min_lod_clamp` (float) and the access (i32). It returns `{ <4 x float>, i8 }`. The iOS form has eight operands, with no `min_lod_clamp`, and returns `<4 x float>`. The order and types are those of `__metal_sample_texture_2d_t` in the Metal toolchain's header `metal/__bits/metal_texture2d`, which takes the same values in the same order.

What is translated. The colour element is the sampled value (`sampleLocal`, `translate.cpp`). A `min_lod_clamp` that is not the constant 0.0 is refused ("a sample with a minimum level of detail clamp this emitter does not map"), and so is an access that is not sample ("a sample of a texture whose access is not sample"). The `i8` residency element is refused if it is used. The eight-operand form is unchanged. The `v4f16` variant takes the same path; no fixture has a half sample.

Fixture. `tests/air2es/sample_mac.metal`, compiled with the pinned Metal compiler for `air64-apple-macos13.0` with `-ffast-math`, gives `sample_mac.metallib`. `sampleVertex` and `sampleFragment` translate (the fragment samples a nearest, clamp-to-edge constexpr sampler with no LOD clamp), and `sampleMinLodFragment` is refused by name. `tests/air2es_test.lua` checks those verdicts and compares the folder with `sample_mac.golden/`.

Oracle. `metal_shader_harness` on the fixture: `sampleVertex + sampleFragment` PASS, max channel diff 0 over 13,312 non-zero Metal channels. The harness reads each texture's wrap and filter from the reflection and sets them on the GLES texture, so a GLES sampler that differs from the constexpr one fails. A run before that change differed on 9,408 of 16,384 channels, and the difference was the sampler.

Not measured. A `min_lod_clamp` other than zero and an access other than sample are refused, and no fixture produces either, so neither is run against Metal. The residency element is not run. The diamond entries (`diamondFragment`, `diamondLensFragment`) keep their refusals: this mapping changes no verdict, and the diamond structurer is not validated by the oracle.

Real shader check (same run): `gramDiamondCompositeVertex` and `gramDiamondCompositeFragment` of the Mac GramDiamond library, the 9-operand sample of a real Telegram shader, match Metal with a max diff of 0 over 6,036 non-zero channels.

## Loops with a break to the exit (2026-11-11)

The brief of 2026-11-11 (coordinator aa549f85) asked for the structurer to handle the loops of the diamond shaders. This section covers the part that does not need a runtime bound: a constant loop whose body breaks out to a block that flows to the loop's exit.

- Shape handled: the header of a constant-bound loop branches to the latch path or to a block that does its own work and then goes to the loop's exit, and the latch test goes to that same exit. The latch is the block of the body that branches back to the header and to the exit (`latchCycleOf`). The body is the blocks reached from the header without the exit (`bodyOf`), so the break block is inside the loop and breaks with its own code. Each exit copies the exit phis and then breaks.
- Shape still refused: when clang peels the first iteration into the entry block, the break block has a predecessor outside the loop and is reached twice, and the translator refuses it with "control flow that reaches one block twice", as before. The fixture `exit_mac.metal` keeps its test on a loop-carried value, which clang does not peel. A first variant with a test on the constant `1/7` was peeled and stayed refused.
- Mac check: `exit_mac.metallib`, compiled for `air64-apple-macos13.0` with `-ffast-math`, gives `exitVertex` and `exitFragment` OK. `metal_shader_harness` on it: PASS, max channel diff 0 over 16,062 non-zero Metal channels. Negative control: the same source with the break's constant changed from 0.5 to 0.6, run against the GLES folder of the original: FAIL, 3,004 of 16,384 channels over the tolerance of 2 (max diff 22).
- The iOS corpus is unchanged: the 89 verdicts and the 66 OK `.glsl` outputs are byte-identical to the previous state.
- Diamond: `diamondFragment` and `diamondLensFragment` still refuse. The loop with a break in `diamondSurface` is now translated, and their first refusal is `air.dfdx.v2f32`, a derivative of a `float2`, which is the next item. Their loops over the planes and the edges have a runtime bound, which this push does not handle.
- Not measured: the loops of the diamond against Metal, and the runtime-bounded loops, which are not in this change.

## Derivatives (2026-11-11)

The brief of 2026-11-11 (coordinator aa549f85) asked for the diamond shaders. Their first refusal after the constant loop was `air.dfdx.v2f32`, a derivative of a `float2`; this section covers the derivative intrinsics.

- Mapped: `air.dfdx.v2f32` as GLSL `dFdx`, and `air.fwidth.v3f32` as `fwidth` (`kPlainFunctions`). `air.fwidth.f32` was already mapped. All three set `GL_OES_standard_derivatives` and are fragment only.
- Mapped with a sign: `air.dfdy.v2f32` as GLSL `-dFdy`. The first translation, `dFdy` as is, failed on the Mac: its output differed from Metal's on 4,096 of 16,384 channels. The mismatch was the green channel of every pixel, with the sign flipped, and not a scale or a varying fault: the interpolated `in.uv.y` without a derivative passes. A pixel dump from the harness (`REVENANT_DUMP`) showed the flip, and negating `dFdy` in a copy of the failing folder makes every channel pass. The cause is the y axis: GL's points up and Metal's points down, so the same derivative has the opposite sign. The fixture `tests/air2es/dfdy_mac` gives `dyFragment` and `dyNegFragment` OK, and the Mac harness matches Metal on `dyFragment` with a max diff of 0 over 8,192 non-zero channels. Its negative control, the same folder without the minus, fails with a difference of 255 over 4,096 channels.
- Oracle: `tests/air2es/deriv_mac.metal`, compiled for `air64-apple-macos13.0` with `-ffast-math`, gives `deriv_mac.metallib`. `derivVertex` and `derivFragment` translate, and the `derivFragment` folder matches `deriv_mac.golden/`. `metal_shader_harness` on it: PASS, max channel diff 0 over 14,368 non-zero Metal channels. The harness tolerance is 2/255; the positive run is exact, so the tolerance does not carry the pass.
- Negative control: the same source with the `dfdx` scale changed from 16.0 to 8.0, run against the GLES folder of the original: FAIL, max channel diff 32/255, 4,096 of 16,384 channels over the tolerance.
- The iOS corpus is unchanged: the 89 verdicts and the 66 OK `.glsl` outputs are byte-identical to the previous state.
- Diamond, Mac library (`GramDiamond.metallib`): `gramDiamondCompositeFragment` is OK, and `diamondFragment` and `diamondLensFragment` now refuse with "an address this emitter does not read", the planes read at a dynamic index. The derivative is no longer their first refusal, and a `dfdy` later in those functions now translates as `-dFdy`. The iOS library's diamond refusals ("control flow that reaches one block twice") are unchanged.
- Not measured: derivative values on a device, and `dfdy` against Metal beyond the fixture.

## Runtime-bounded loops and vector buffer elements (2026-11-11)

The brief of 2026-11-11 (coordinator aa549f85) asked for the diamond's loops over `planes` and `edges`. Their bounds are the uniform counts `viewport.z` and `viewport.w`, and the host caps the buffers at 17 planes and 128 edges (`DiamondGeometry.swift:50`, `DiamondRenderer.swift:169`, `:272–273`). This section covers the part the Mac oracle can check: a loop with a uniform bound over a capped buffer.

- Shape: a counted loop whose latch compares its index with a value from outside the loop (a uniform, here) is emitted as a `for` to the cap of the capped buffer its body indexes with the loop index. The latch test stays in the body, so the loop stops at the count (`if (t17 == t0) break;`), and a zero count is the guard before the loop. A loop with no capped buffer behind its index is refused, as before.
- Self-loops: a loop whose body is one block, which is both header and latch, is recognised when its bound is a runtime value. A constant-bound self-loop keeps its earlier route. The first attempt changed four `gaussianBlur` kernels from OK to REFUSED ("a branch that leaves a loop somewhere other than its exit"); the corpus check caught it, and the constant case was put back.
- Vector elements: a host-capped buffer of `float2`, `float3` or `float4` elements is one uniform per element. `float3` is not tested.
- Fixture: `tests/air2es/loop_mac.metal`. `loopFragment` loops `uint(viewport.z)` times over a `float4` buffer capped at eight, and returns the last index through a phi. Its capped buffer is named in `kBufferCaps` (`loopFragment`, `planes`, 8), as `callBlobVertex` is. `tests/air2es_test.lua` checks the verdict and compares the folder with `loop_mac.golden/`.
- Oracle: `metal_shader_harness` with the data sets `loop_z0`, `loop_z1`, `loop_z3` and `loop_z8`: PASS at every count, max channel diff 0 over 16,384 channels each. Negative control: Metal `i + 1 < z` against the GLES folder of `i < z`, at z = 3: FAIL, 25/255 over 4,664 channels.
- The iOS corpus is unchanged: the 89 verdicts and the 66 OK `.glsl` outputs are byte-identical.
- The diamond's `kBufferCaps` entries and the select limit of 128 come in the next section. They do not move the diamond's verdicts yet, because its next blocker is its control flow.
- Not measured: the diamond itself, 128 edges, and `float3` elements.

## Masks and bounded indices (2026-11-11)

The brief of 2026-11-11 (coordinator aa549f85) asked for the diamond shaders' loops. Their index arithmetic is taken modulo a power of two, which LLVM emits as an `and` of an integer; this section covers that `and` and the bound of a loop index.

- Mapped: a bitwise and with `2^k - 1` of an integer whose bound is known and below 2^22 (`kExactLimit`) is `int(mod(float(x), 2^k))` at `highp` (`maskAnd`). The bound of a loop index is its trip count (`indexBounds_`, set in `emitLoop` and `emitCountedCycle`), so `(i + 1) % 8` in a loop of eight is at most 8 and the modulo is exact. The old path, an `and` of an unsigned float conversion with the sign bit, is unchanged.
- The successor of a loop index, `(t + 1)` in the GLSL, may sit in the header or the body: `latchCycleOf` and `loopOf` accepted it only in the latch.
- Refused as before: an `and` whose mask is not `2^k - 1`, and an integer with no bound, such as a loop over a uniform with no cap.
- Diamond: `kBufferCaps` now gives `diamondFragment` and `diamondLensFragment` a planes buffer of 17 (`DiamondGeometry.swift:50`), and `diamondLensFragment` an edges buffer of 128 (`DiamondRenderer.swift:272–273`); the select limit of an array member is 128. The verdicts do not move: on the Mac library `diamondFragment` and `diamondLensFragment` are REFUSED with "control flow that reaches one block twice", as on the iOS corpus. That is the next blocker. The planes and edges loops are not lowered yet.
- Fixture: `tests/air2es/mask_mac.metal`. `maskFragment` sums eight terms over `ring[i % 8]` and `ring[(i + 1) % 8]`, and writes `acc * 0.05 + 0.5` to red, which keeps the sum inside the channel. The unscaled sum saturated red at 255 on both sides, so the first negative control passed; the scale fixes that. `tests/air2es_test.lua` checks the verdict and compares the folder with `mask_mac.golden/`.
- Oracle: `metal_shader_harness` PASS, max channel diff 0 over 16,384 channels. Negative control: the same source with `(i + 2) % 8` in place of `(i + 1) % 8`, its GLES folder against the Metal of the positive: FAIL, 9/255 over 4,096 channels, every pixel's red channel.
- The iOS corpus is unchanged: the 89 verdicts and the 66 OK `.glsl` outputs are byte-identical, and all 18 output folders are byte-identical to the 2026-11-11 run before this change.
- Not measured: the diamond against Metal (it still refuses), `float3` capped elements, and 128 edges on a device.

## Flag loops and calls inside loops (2026-11-11)

The brief of 2026-11-11 (coordinator aa549f85) asked for the diamond shaders. On the Mac library, `diamondFragment` stopped at a flag loop, a helper call with a branch inside a loop, and three intrinsics. This section covers them.

- Flag loops: `flagCycleOf` takes a latch whose branch tests a header phi that is a constant on the entry edge and a constant on the back edge. The number of passes comes from simulating the flag, up to 64, and the loop is emitted as `for (int t = 0; t < n; t++)` with the flag as a local. A single-block loop (header and latch) and a multi-block body are both accepted. The exit is still a `break` from the latch. A flag that never leaves its continue value is not taken as a loop.
- Calls in loops: the blocks of a helper that is not inlined are not in the caller loop's body. `insideLoop` now treats a block of another function as inside, so the helper's own branch and join are emitted in place. Before, a branch in such a helper refused with "a branch that rejoins outside its loop".
- Intrinsics: `air.sign.f32` as `sign`, `air.mix.v4f32` as `mix`, and `air.fast_asin.f32` as `asin`. The accuracy of `fast_asin` against Metal is not measured yet.
- Fixture: `tests/air2es/flag_mac.metal`. `flagFragment` runs a two-pass loop whose latch tests the flag that is true on the first pass, and calls `pick`, a `__attribute__((noinline))` helper with a branch. `tests/air2es_test.lua` checks the verdict and compares the folder with `flag_mac.golden/`, which has `for (int t4 = 0; t4 < 2; t4++)`.
- Oracle: the positive matches Metal with a max channel diff of 0 over 16,384 channels. Negative control: the second pass's factor 0.4 changed to 0.45, the GLES folder against the Metal of the positive: FAIL, 31/255 over 576 channels.
- Mac library: `diamondFragment` is OK, but it is not yet compared with Metal. `diamondLensFragment` is REFUSED with "control flow that reaches one block twice", the loop over its edges, which is the next item.
- iOS corpus: unchanged, 66 OK and 23 REFUSED, with byte-identical outputs. The Telegram release library's `diamondFragment` and `diamondLensFragment` are still REFUSED with "control flow that reaches one block twice". The Mac and iOS builds of the same source have different control flow. That difference is not diagnosed yet.
- Not measured: the diamond against Metal (its uniform sets are the next step), `fast_asin` against Metal, and the iOS diamond's control flow.

## Shared blocks in branches (2026-11-11)

The brief of 2026-11-11 (coordinator aa549f85) asked for the diamond's lens loop. Its refusal, "control flow that reaches one block twice", came from a block reached from both arms of a branch before the branch's join.

- Rule: the two arms of a conditional branch are separate paths. A block reached from both is emitted in each arm (tail duplication). The visited set is reset to the blocks seen before the branch for each arm, and the two sets are joined after the branch (`region`, the same rule `multiway` uses). A block reached twice on one path is still refused, so an unrecognised cycle stays refused.
- Values: each emission declares its own locals, and the latest name wins. A value of a shared block that is used after the join goes through a phi, which the edge copies assign on each arm.
- Mac library (`GramDiamond.metallib`): `diamondLensFragment` is OK now, and so is `diamondFragment`. The one refusal left is `backgroundStarVertex`, "a logical shift right of an integer with no known bound". This is translation only.
- iOS corpus: unchanged. 89 verdicts, 66 OK, 23 REFUSED, and the output folders are byte-identical.
- Diamond oracle: `diamondFragment` and `diamondLensFragment` are SKIP for all four uniform sets (zero, one, mid, max), with the harness's note "Metal output is blank, so the case proves nothing". The data sets (`diamond_*.data.json`) set `viewport` only. The vertex stage reads the `model`, `projection` and `inverseModel` matrices of `Uniforms`, and the fragment reads the other `Uniforms` fields, so the geometry lands outside the target. The composite pair is a real check on the same sets: PASS, max channel diff 0 over 6,036 non-zero channels.
- Not tested: a fixture for a block shared between arms. The Mac diamond is the only input that exercises it.
- Not measured: the diamond against Metal. The next step is to fill the `Uniforms` members the diamond reads from `DiamondRenderer.swift`, and the vertex buffer the vertex stage reads. (Measured in the next section.)

## Members with one name in two buffers (2026-11-11)

The diamond's lens reads `viewport` and `parameters` from its own argument (`LensFields lens`, buffer 3), and the stone's `Uniforms` has fields of the same names at buffer 1. The GLES uniform was keyed by name, so the second declaration was dropped and every load of the lens's `viewport` read the stone's. The lens's `viewport.w`, the edge count, read 0, so the lens loop never ran. The reflection showed it (`viewport` at buffer 1 only, with no lens entry); the oracle confirmed it.

- Rule: a member is declared under its argument's name as a prefix (`u_viewport`, `lens_viewport`) when another buffer of the same kind (uniform or vertex) has a member of that name. Other names are unchanged, so no existing output moves. A name is claimed by one buffer and offset; a second claim at another offset is refused, not aliased (`memberName`, `claimSlot`).
- Fixture: `tests/air2es/shared_mac.metal` (macOS): `StoneUniforms u` at buffer 1 and `LensFields lens` at buffer 3, both with `viewport` and `parameters`. `sharedChecks` compares the output of `sharedFragment` with its golden files.
- Fixture oracle, with `u_viewport`, `u_parameters`, `lens_viewport` and `lens_parameters` set to distinct values: after the fix, PASS with a max channel diff of 0 over 13,312 non-zero Metal channels. Before the fix (negative control), FAIL with 255/255 over 8,192 of 16,384 channels.
- iOS corpus: unchanged. 89 verdicts (66 OK, 23 REFUSED), and all 150 output files are byte-identical to the 2026-11-11 run.

Diamond oracle (Mac library `GramDiamond.metallib`: nine functions translated, `backgroundStarVertex` still refused). The data come from a generator in scratch, not committed (`diamond-data/make_full.c`). The model is `Rx(0.35)·Ry(0.6)`, the projection a 40° perspective (near 0.1, far 10) moved four units back on z, and `inverseModel` the transpose of `model`. The stone takes the `Uniforms` values listed in the generator. The lens takes `lens_viewport = (32, 32, 2, edges)`, `lens_parameters = (0.8, 0.6, 40, 0)`, `rect = (-32, -32, 64, 64)`, `uv = (0, 0, 1, 1)` and `center = 0`; the source texture is the harness's. The four sets are zero (0 planes, 0 edges), one (1, 3), mid (8, 64) and max (17, 128). `planes` always has 17 entries. The vertex stage reads the harness's default quad, not DiamondGeometry's mesh.

| set | stone (`diamondVertex` + `diamondFragment`) | lens (`diamondVertex` + `diamondLensFragment`) | composite |
|---|---|---|---|
| zero | PASS, 0 over 6,304 channels | PASS, 0 over 6,304 | PASS, 0 over 16,384 |
| one | PASS, 0 | PASS, 0 | PASS, 0 |
| mid | PASS, 0 | PASS, 0 | PASS, 0 |
| max | PASS, 0 | PASS, 1/255 | PASS, 0 |

Tolerance: 2/255, the harness's. The 8-bit outputs of Metal and ANGLE come from the same float expressions on different backends, so one step of rounding, 1/255, is expected; the largest difference seen is one such step. The tolerance is not what makes the oracle pass or fail: the negative control below differs by 35/255.

Negative control: the pre-fix translator on the same data, max set. The stone still PASSes with 0. The lens FAILs with 35/255 over 4,728 of 16,384 channels. The lens output differs from the stone output, so the lens case is not a copy of the stone.

Not covered: the sparkle pair is SKIP (blank Metal output) and outside this check; the lens hull is a synthetic 128-gon of radius 90 points, not the device projection; the vertex stage is the default quad; nothing ran on a device. Telegram's iOS AIR still refuses the diamond ("control flow that reaches one block twice"), so this change does not alter what Telegram builds from origin/main, and the diamond on iOS is still not validated.

## Diamond oracle data: how to reproduce (2026-11-11)

The data generator is committed as `frameworks/Backports/tests/air2es/diamond_data.c`. It writes `diamond_zero.data.json`, `diamond_one.data.json`, `diamond_mid.data.json` and `diamond_max.data.json` into the directory it is given. Each file has `arrays.planes` (17 vec4, from the seven rings of Telegram's `DiamondGeometry`, release 13.0.0), `arrays.edges` (128 vec4, with the first `w` set to a regular polygon of radius 90 points), and `members`: `model`, `projection` and `inverseModel` (column-major 4×4), the stone's `Uniforms` fields under their GLES names, and the lens's fields under the names the translator emits for a member shared with the stone (`u_viewport`, `u_parameters`, `lens_viewport`, `lens_parameters`), with `rect`, `uv` and `center`.

Runbook (the Metal library is compiled from Telegram's `MetalResources/GramDiamond.metal`, which is not in this repository):

```
cc -O2 -o make_diamond_data frameworks/Backports/tests/air2es/diamond_data.c -lm
mkdir -p OUT && ./make_diamond_data OUT
TC="$HOME/Library/Caches/revenant/metal-toolchain/mount/Metal.xctoolchain/usr/bin"
"$TC/metal" -c -target air64-apple-macos13.0 -ffast-math GramDiamond.metal -o GramDiamond.air
"$TC/metallib" GramDiamond.air -o GramDiamond.metallib
build/macosx/arm64/release/air2es GramDiamond.metallib FOLDER
REVENANT_DUMP=DUMP build/macosx/arm64/release/metal_shader_harness GramDiamond.metallib FOLDER build/macosx/arm64/release/angle OUT/diamond_max.data.json
```

Repeat the last line for `zero`, `one` and `mid`. The harness needs the ANGLE argument whenever a data set is given. A pair is PASS when the largest channel difference is within 2/255, and SKIP when Metal's output is blank.

Results at `0f09451ee` plus the member-name fix (`3dd642f6c`):

| set | stone (`diamondVertex` + `diamondFragment`) | lens (`diamondVertex` + `diamondLensFragment`) | composite |
|---|---|---|---|
| zero | PASS, 0 over 6,304 channels | PASS, 0 over 6,304 | PASS, 0 over 16,384 |
| one | PASS, 0 | PASS, 0 | PASS, 0 |
| mid | PASS, 0 | PASS, 0 | PASS, 0 |
| max | PASS, 0 | PASS, 1/255 | PASS, 0 |

Tolerance: 2/255. The largest difference observed is one step of 8-bit rounding, and the tolerance allows one more such step. A translation error is far larger (see the controls).

Controls:
- Translator negative control: the pre-fix translator on the same data, max set. The stone still PASSes; the lens FAILs with 35/255 over 4,728 of 16,384 channels, and its output differs from the stone's.
- Test negative control: `diamondChecks` removes `lens_viewport` from the max set and requires the contract check to refuse it. The fixture golden `shared_mac.golden` fails with the pre-fix translator, because `sharedFragment` declares `viewport` once.

Limits, which the numbers above do not cover:
- The vertex stage reads the harness's default quad (`a_position` by name, `a_normal` and `a_surface` at 0.5), not the mesh of `DiamondGeometry`. The fragment's ray-plane work is exercised over the quad's area; the vertex transform is not checked against the mesh.
- The lens hull is the synthetic 128-gon of the generator, not the projected hull of a device frame.
- The sparkle pair is SKIP because its Metal output is blank; it is outside this check.
- The stone's rotation (pitch 0.35, yaw 0.6) and projection (40°, camera 4 units back) are fixed values, not the app's; the sets cover planes and edges, not the app's motion or appearance values.
- Nothing ran on a device.

## Phone window and the iOS diamond, state (2026-11-11)

Phone window (item 3 of the brief): not used for new measurements. The probe that reads the GL limits, `Es2ProgramProbe` (`frameworks/Backports/tests/device_probe/es2_main.m`), is not built in this worktree: `./xmakew -P frameworks/Backports build Es2ProgramProbe` stops in package resolution (`llvm`, `ffmpeg` from xmake-repo) before any of its code compiles. The earlier windows still stand:

- `udiv` and `urem` are exact on the 4S over the 4096 texels, maxdiff 0 (the integer-map section).
- Highp float and int in a fragment shader are exact for the bitwise-`and` emulation (the bitwise section).
- Mediump float holds integers only up to 2048 (the enhance-LUT design note); the mediump range of ±2^14 is not measured on the device.
- The GL limits (`GL_MAX_VERTEX_UNIFORM_VECTORS`, `GL_MAX_FRAGMENT_UNIFORM_VECTORS`, `GL_MAX_VARYING_VECTORS`, `GL_MAX_TEXTURE_IMAGE_UNITS`, `GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS`) are read by `revenant_limits` in the probe, and no run of it is recorded in the docs; their values are not recorded here.

The iOS diamond refusal, "control flow that reaches one block twice": the refusing block is the header of a counted loop inside `diamondSurface`, which both `diamondFragment` and `diamondLensFragment` inline. A temporary trace at the refusal site (removed; the committed translator is unchanged) printed the block's first instruction. In the iOS AIR (`submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources.metallib`, `air-objdump -d`):

- block 286: `%287 = phi i32 [ %288, %257 ], [ 1, %187 ]`, `%288 = add nuw nsw i32 %287, 1`, `%289 = icmp eq i32 %288, 7`, `br i1 %289, label %290, label %257`;
- block 257, the body, ends in an unconditional branch back to 286.

The walk reaches 286 from its entry, follows the body 257, and comes back to 286, so it is visited twice. `cycleOf`, `latchCycleOf` and `flagCycleOf` need a conditional latch that tests the next index with `eq` or `ne`, and `loopOf` needs the test on the header's phi. The test here sits in the header and the body branches back unconditionally, so none of them matches.

Direction for the fix: a do-while recogniser. The header holds a phi with a constant start and step 1, tests the next index against a constant bound with `eq` (exit on true), and the body branches back unconditionally; it is emitted as `for (int t = start; t < bound - 1; t++) { body }`, with the index uses handled as `emitLoop` does. It needs a macOS fixture with the same shape, a corpus check over the 18 libraries, a digest and a prepush. Estimate: one to two hours. It was not started in this window.

Not checked: whether the Mac AIR of the same library has this shape. The Mac library translates, so its loop must be recognised, but the two disassemblies were not compared.

The shared-member fix (`3dd642f6c`), the diamond data generator and its test (`138a49101`) are unchanged by this section.
