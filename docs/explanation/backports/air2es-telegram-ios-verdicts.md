# air2es on Telegram's iOS Metal sources: per-shader verdicts

Measured 2026-10-30 with the Metal compiler of Xcode 27B47 (Metal 32023.922), compiling the 27 Telegram `.metal` files in 18 directories of the Telegram-iOS-release-13.0.0 reference to `air64-apple-ios12.0` with `-ffast-math` and linking each directory with `metallib`, as `rules_apple` does. The verdicts come from `./xmakew l frameworks/Backports/tools/metal_corpus.lua`. The ffmpeg sources and the `rules_apple` test samples are not included.

Result: 89 entry points (43 fragment, 27 vertex, 19 kernel); 32 translate (18 fragment, 14 vertex); 57 are refused by name, including all 19 kernels. Refusals are by air2es's own reasons, not by the GLES 2 target, except the clamp-to-zero and the mipmap-filter rows, which are the target's limits (see `frameworks/Backports/src/air2es/NOTES.md`).

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
| submodules_DrawingUI_MetalResources | fragment_point_func | fragment | REFUSED | an argument of a kind this emitter does not read |
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
