# air2es on Telegram's iOS Metal sources: per-shader verdicts

Measured 2026-10-30 with the Metal compiler of Xcode 27B47 (Metal 32023.922), compiling the 27 Telegram `.metal` files in 18 directories of the Telegram-iOS-release-13.0.0 reference to `air64-apple-ios12.0` with `-ffast-math` and linking each directory with `metallib`, as `rules_apple` does. The verdicts come from `./xmakew l -P . frameworks/Backports/tools/metal_corpus.lua`. The ffmpeg sources and the `rules_apple` test samples are not included. The sources are the `.metal` files of the `release-13.0.0` tag of `github.com/TelegramMessenger/Telegram-iOS` (commit `f1dd7a2`), fetched with a blobless sparse checkout of the 19 directories that hold them; the tool leaves out the 28th file, under `submodules/ffmpeg`, which leaves 27 files in 18 directories.

Result: 89 entry points (43 fragment, 27 vertex, 19 kernel). Before the changes at the end, 32 translate (18 fragment, 14 vertex) and 57 are refused by name, including all 19 kernels. After them, 33 translate (19 fragment, 14 vertex) and 56 are refused, still including all 19 kernels. The table shows the state after the changes. Refusals are by air2es's own reasons, not by the GLES 2 target, except the clamp-to-zero and the mipmap-filter rows, which are the target's limits (see `frameworks/Backports/src/air2es/NOTES.md`).

| Library | Entry point | Stage | Verdict | Reason |
| --- | --- | --- | --- | --- |
| submodules_AnimationCompression_Resources | dctKernel | kernel | REFUSED | an argument of a kind this emitter does not read |
| submodules_AnimationCompression_Resources | idctKernel | kernel | REFUSED | an argument of a kind this emitter does not read |
| submodules_AnimationCompression_Resources | vertexShader | vertex | REFUSED | a load from a constant table this emitter does not map |
| submodules_AnimationCompression_Resources | samplingIdctShader | fragment | OK |  |
| submodules_AnimationCompression_Resources | samplingRgbShader | fragment | OK |  |
| submodules_AnimationCompression_Resources | samplingYuvaShader | fragment | REFUSED | a sdiv this emitter does not map |
| submodules_Camera_CameraNeo_MetalResources | convertNV12 | kernel | REFUSED | a width of something other than a texture |
| submodules_Camera_CameraNeo_MetalResources | downsampleNV12 | kernel | REFUSED | a width of something other than a texture |
| submodules_Camera_CameraNeo_MetalResources | compositeRoundVideo | kernel | REFUSED | a width of something other than a texture |
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
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | videoBiPlanarToRGBA | kernel | REFUSED | a call to air.read_texture_2d.v4f16 |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | videoTriPlanarToRGBA | kernel | REFUSED | a call to air.read_texture_2d.v4f16 |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | gaussianBlurHorizontal | kernel | REFUSED | a width of something other than a texture |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | gaussianBlurVertical | kernel | REFUSED | a width of something other than a texture |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBackgroundVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBlobVertex | vertex | REFUSED | a local of a type this emitter does not hold as a variable |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | mainVideoVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | edgeTestVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBackgroundFragment | fragment | REFUSED | a call to air.dot.v2f16 |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | callBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | mainVideoFragment | fragment | REFUSED | a call to air.mix.v4f16 |
| submodules_TelegramUI_Components_Calls_CallScreen_Metal | edgeTestFragment | fragment | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | videoBiPlanarToRGBA | kernel | REFUSED | a call to air.read_texture_2d.v4f16 |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | videoTriPlanarToRGBA | kernel | REFUSED | a call to air.read_texture_2d.v4f16 |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | gaussianBlurHorizontal | kernel | REFUSED | a width of something other than a texture |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | gaussianBlurVertical | kernel | REFUSED | a width of something other than a texture |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | cameraBlobVertex | vertex | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | mainVideoVertex | vertex | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | cameraBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_CameraScreen_MetalResources | mainVideoFragment | fragment | REFUSED | a call to air.mix.v4f16 |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectInitializeParticle | kernel | REFUSED | a local of a type this emitter does not hold as a variable |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectUpdateParticle | kernel | REFUSED | a urem this emitter does not map |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectVertex | vertex | REFUSED | an argument of a kind this emitter does not read |
| submodules_TelegramUI_Components_DustEffect_Metal | dustEffectFragment | fragment | OK |  |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassCrestKernel | kernel | REFUSED | a struct member this emitter does not read in parameters |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassRadialKernel | kernel | REFUSED | a struct member this emitter does not read in parameters |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesVertex | vertex | OK |  |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesContentFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesMultiplyFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesMaskFragment | fragment | REFUSED | a value of a type this emitter does not hold |
| submodules_TelegramUI_Components_LiquidGlassShapes_Metal | liquidGlassShapesDisplacementFragment | fragment | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | dualFragmentShader | fragment | REFUSED | a call to air.mix.v4f16 |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | bt709ToRGBFragmentShader | fragment | REFUSED | a call to air.fast_saturate.v3f32 |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | defaultVertexShader | vertex | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | defaultFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | histogramPrepareFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | gradientFragmentShader | fragment | OK |  |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | adjustmentsFragmentShader | fragment | REFUSED | a call to air.fmin.f16 |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | enhanceGenerateLUT | kernel | REFUSED | an address this emitter does not read |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | rgbToLightnessFragmentShader | fragment | REFUSED | a call to air.fmin.f16 |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | enhanceColorLookupFragmentShader | fragment | REFUSED | a sample with a clamp-to-zero address, which OpenGL ES 2 does not have |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurRadialFragmentShader | fragment | REFUSED | a sample with a clamp-to-zero address, which OpenGL ES 2 does not have |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurLinearFragmentShader | fragment | REFUSED | a sample with a clamp-to-zero address, which OpenGL ES 2 does not have |
| submodules_TelegramUI_Components_MediaEditor_MetalResources | blurPortraitFragmentShader | fragment | REFUSED | a sample with a clamp-to-zero address, which OpenGL ES 2 does not have |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | gramDiamondCompositeVertex | vertex | REFUSED | a local of a type this emitter does not hold as a variable |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | backgroundStarVertex | vertex | REFUSED | an argument of a kind this emitter does not read |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondVertex | vertex | REFUSED | a member of type float4x4 in u |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | sparkleVertex | vertex | REFUSED | an argument of a kind this emitter does not read |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | referenceHighlightVertex | vertex | REFUSED | an argument of a kind this emitter does not read |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | gramDiamondCompositeFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | backgroundStarFragment | fragment | REFUSED | a call to air.fwidth.f32 |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondFragment | fragment | REFUSED | a local of a type this emitter does not hold as a variable |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | diamondLensFragment | fragment | REFUSED | a local of a type this emitter does not hold as a variable |
| submodules_TelegramUI_Components_Premium_PremiumDiamondComponent_MetalResources | sparkleFragment | fragment | REFUSED | a comparison this emitter does not map |
| submodules_TelegramUI_Components_Stories_StoryPeerListComponent_MetalResources | cameraBlobVertex | vertex | OK |  |
| submodules_TelegramUI_Components_Stories_StoryPeerListComponent_MetalResources | cameraBlobFragment | fragment | OK |  |
| submodules_TelegramUI_Components_Wallet_WalletCardComponent_Resources | walletCardBackgroundVertex | vertex | REFUSED | a struct member this emitter does not read in uniforms |
| submodules_TelegramUI_Components_Wallet_WalletCardComponent_Resources | walletCardBackgroundFragment | fragment | REFUSED | a local of a type this emitter does not hold as a variable |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountBlur | kernel | REFUSED | a width of something other than a texture |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountVertex | vertex | REFUSED | an argument of a kind this emitter does not read |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountLayerVertex | vertex | REFUSED | an argument of a kind this emitter does not read |
| submodules_TelegramUI_Components_Wallet_WalletSendScreen_Resources | walletAmountFragment | fragment | REFUSED | a sample with a clamp-to-zero address, which OpenGL ES 2 does not have |
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

A verdict does not show that the GLSL compiles. `histogramPrepareFragmentShader` was OK at baseline, and its GLSL assigned a `float` to `gl_FragColor`. On the 4S it fails the ES 2 probe (`ERROR: 0:26: Incompatible types (vec4 and float)`), and `glslangValidator` rejects it for ES 1.00. After `colorOf` both accept it.

Checks on the state the table shows:

- the ES 2 probe on the 4S (iPhone4,1, iOS 6.1.3, PowerVR SGX 543) over the 33 OK entries: 33 PASS, 0 FAIL; before `colorOf` it was 32 PASS, 1 FAIL;
- `air2es_check.lua` with `glslangValidator` over the 18 translated folders: 0 folders fail; before `colorOf` 1 failed;
- `air2es_test.lua`: 15 cases pass.

The 56 refusals have 22 reasons. The argument-kind group (8, from 9) is what is left of the first group:

- six vertex functions use `air.instance_id`: `dustEffectVertex`, `backgroundStarVertex`, `sparkleVertex`, `referenceHighlightVertex`, `walletAmountVertex`, `walletAmountLayerVertex`. OpenGL ES 2 has no instancing, so these need a decision on how instances are drawn, not a mapping;
- `dctKernel` and `idctKernel` use `air.thread_position_in_threadgroup`, and they also use threadgroup memory, so they need the multi-pass design.

The next groups in the order set for the work are the width refusals (8), the locals of a type this emitter does not hold (6), and the clamp-to-zero samples (5).
