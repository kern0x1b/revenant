# Crutches: the stand-ins of the Backports lowering

Work that stands in for the native behaviour, with the measurement that shows what it does and the limit that would
remove it. The entries describe the Backports lowering on the branch `work/telegram-backports`. An open entry is one
whose removal has not landed. A removed entry stays below, with the commit that removed it.

## Open

### C2. Armv7 iOS 6.0 proof is a typecheck with a known reproduction gap

- Stands in for: a full CI compile of the Foundation overlay. The local proof typechecks the overlay sources with the same compiler, target, stdlib and patched shims as CI; it does not run IR generation or emit objects.
- Gaps: `NSValue.swift` and `CGFloat.swift` are gyb templates that were not expanded; the `ObjectiveC`, `CoreFoundation`, `CoreGraphics` and `Dispatch` swiftmodules come from release `prebuilt-swift-runtime-b3c2a6ae…`.
- Measurement: the same reproduction reproduced CI's `Measurement.swift:23:15` errors before the fix, and reports zero errors after.
- Removed by: the CI full build of the head (the `swift-runtime` prebuild and its check).

### C3. Extension guard cleared for every member of the extension

- Stands in for: a per-operator lowering. The Equatable and Comparable requirements of `Measurement` are witnessed by operators inside `extension Measurement {`, whose guard covers the operators too.
- Widens: every other member of that extension reaches the iOS 6.0 floor.
- Measurement: the armv7 iOS 6.0 typecheck compiles those members with CI's compiler. Nothing has been run on an iOS 6 device.
- Removed by: a device run of the `Measurement` members on iOS 6.

### C4. Non-public and type-level guards cleared by rule

- Stands in for: naming each declaration. The lowering clears the guard of an implemented struct, class or enum, of non-public members of an implemented type, and of file-scope internal functions.
- Widens: these declarations reach the iOS 6.0 floor.
- Measurement: the armv7 iOS 6.0 typecheck compiles them with CI's compiler. Their bodies have not been run on an iOS 6 device.
- Removed by: a device run.

### C6. Reduced check for the weak class NSDateInterval in the lowering test

- Stands in for: a compile-time check of the members of `NSDateInterval`. The class keeps its class-level guard by design (the guard table records it as a weak import), so the IMPLEMENTED probe refers to it through an `id` receiver. `NSURLComponents` no longer keeps its guard: its alias exports the class, and the apple-ios rule links every binary against the flat-class stubs, so its reference is strong.
- Measurement: the rest of the probe still checks typed receivers and the lowered headers at armv7 iOS 6.0.
- Removed by: the export dependency for `NSDateInterval` (the Backports library that exports it, linked into the runtime); the probe then returns to typed receivers.

### C7. Export dependency for weak classes and UIFocusSystem: pending

- The runtime's UIKit overlay imports `_OBJC_CLASS_$_UIFocusSystem` weakly (guard table, `UIKit.swift:398`); Telegram's `UIKitRuntimeUtils` needs the class unguarded.
- Removal: the runtime links the Backports UIKit library that exports the class, so the load check's exports include it. Pending implementation.

### SceneKit audio (branch work/scenekit-audio)

### C8. Reverb is a dry and wet split on the ASA send

- Stands in for: the reverb of AVAudioEnvironmentNode. The dry gain is `volume × (1 − reverbBlend)` and the send level of the ASA reverb is `reverbBlend`; a blend of zero applies neither and needs no ASA.
- Gaps: the wet level of ASA is not calibrated against AVAudioEnvironmentNode's reverb, so an equal blend gives equal dry and wet gains here, not equal loudness there.
- Measurement: host readback of `AL_GAIN` and the `rvsl` send at blends 0, 0.25 and 0.5 (`tests/SceneKit/audio_test.m`).
- Removed by: a listening comparison on the device against AVAudioEnvironmentNode at the same blend.

### C9. Distance is OpenAL's clamped inverse law with AVAudioEnvironmentNode's defaults

- Stands in for: AVAudioEnvironmentNode's inverse distance model (reference distance 1, maximum distance 100000, rolloff factor 1). OpenAL's clamped inverse law is the same formula, set per source.
- Gaps: not compared with Apple's output on the device.
- Measurement: host readback of the three source parameters, and a falloff ratio between 0.15 and 0.35 for 1 m against 4 m.
- Removed by: a device comparison of the falloff against AVAudioEnvironmentNode.

### C10. Custom AVAudioNode players are attached without spatialisation

- Stands in for: SceneKit placing a custom node in its environment. The node is connected to the main mixer of a shared `AVAudioEngine`.
- Gaps: a custom node is not positioned from its node's transform nor from the listener, and `didFinishPlayback` is never called for it, because the node decides when its audio ends.
- Measurement: host attach on start and detach on stop (`audio_test.m`). The device is not measured for custom nodes.
- Removed by: an environment node that positions custom nodes, and an end notification for them.

### C11. `audioNode` is nil for players built from a source

- Stands in for: the internal AVAudioPlayerNode that SceneKit uses for a source player. The player plays through the OpenAL source instead, so there is no node to return.
- Measurement: host check that a source player has no node and a node player returns its node.
- Removed by: a source player that plays through an AVAudioPlayerNode, or a documented decision to keep `audioNode` nil.

### C12. The engine behind custom nodes is the Backports AUGraph lowering

- Stands in for: `AVAudioEngine` (iOS 8). The Backports build it on an AUGraph in `AVFoundationBackports`.
- Gaps: the lowering is unverified on iOS 6.1.3. Start, connect and attach run through the AUGraph on the device, and only the host (Apple's engine) has run them.
- Measurement: host attach, connect and detach with Apple's `AVAudioEngine` (`audio_test.m`).
- Removed by: a device run of a custom node playing through the engine.

### C13. Archives carry the URL of the source

- Stands in for: SceneKit's archive. A macOS archive of a source made with `initWithURL:` stores `url` as nil; the keys are otherwise the same as ours (`loops`, `positional`, `rate`, `reverbBlend`, `shouldStream`, `url`, `volume`).
- Gaps: our archive keeps the URL, so a source decoded from it plays. Apple's archive of the same source decodes to a source with no URL, which cannot play.
- Measurement: host check that the archive keys equal the macOS keys, and that flags and values survive a round trip (`audio_test.m`).
- Removed by: a decision to match Apple's nil `url`, or to keep the URL as the only way to play after decode.

### C14. Velocity is a finite difference of positions

- Kept by the coordinator's decision: SceneKit has no velocity of its own, so the velocity is the difference between the last two positions, and zero for the first sample. Listed here so the choice is visible; it is not a stand-in.

### C15. Reverb needs the ASA procedures when the blend is above zero

- Stands in for: the reverb of AVAudioEnvironmentNode, through the ASA send of OpenAL (`alcASASetSource`, `rvsl`). A blend of zero needs no ASA.
- Gaps: the ASA procedures are not exported from `OpenAL.framework` on 6.1.3 (checked against the image: `_alcASASetSource`, `_alcASASetListener` and `_alcASAGetSource` are absent as exports). They are resolved at run time with `alcGetProcAddress`, and a device without them raises `NSInternalInconsistencyException` on a start with a blend above zero. Whether the procedures resolve on 6.1.3 has not been measured on a device.
- Measurement: host readback of the send through `alcASAGetSource` (`audio_test.m`). On the 6.1.3 emulator the runtime case `scenekit_audio` reports `ALC_EXT_ASA` present and the three procedures non-NULL from `alcGetProcAddress` (C16). A real device is not measured.
- Removed by: that report on a real 6.1.3 device.

### C16. The OpenAL device path, the audio session and streaming are not run on iOS 6.1.3

- Stands in for: the output path of AVAudioSession and AVAudioPlayer, which SceneKit uses on the device. The OpenAL device, the ExtAudioFile decode, source playback and stream playback run only on the macOS host.
- Gaps: no AVAudioSession category is set, so output follows the default session (mute switch, other audio). On the 6.1.3 emulator (iPhone4,1, time scale 10) the runtime case `tests/runtime/cases/scenekit_audio.m` passes its positive mode: OpenAL opens an output device, `ALC_EXT_ASA` is present, the three ASA procedures resolve through `alcGetProcAddress`, ExtAudioFile decodes the 2 s tone at 8000 Hz, a source and a stream start and finish on their own. The last emulator run with the grid schedule finished the 2 s tone at 2.79 guest seconds and the 2 s stream at 1.76, measured with the guest clock, so the tone's margin in the 3 s window is about 0.2 s. An earlier run under host load stalled: the kernel cached the IO proc deadline while a callback was in flight and did not refresh it after completion, so the wakeup was lost. The kernel now reads that deadline on every check, and the IO proc keeps the grid of its start time (C22). Under host load this has not been measured since the fix. Nothing has run on a real device.
- Measurement: the emulator run above (positive and negative modes of the case) and host tests of the same paths (`audio_test.m`, `action_run_test.m`).
- Removed by: a run on a real iPhone 4S with the mute switch set and other audio playing.

### C17. SCNView adopts SCNSceneRenderer; two members raise, and three properties store their value without effect

- Stands in for: the members of SCNSceneRenderer that have no GLES counterpart. Implemented natively: `hitTest:options:` (CPU ray picking against the triangles of the scene, with the search modes, back-face culling, bounding boxes, category masks and texture coordinates per channel), `isNodeInsideFrustum:withPointOfView:` and `nodesInsideFrustumWithPointOfView:` (world bounds against the frustum of the point of view), `prepareObject:shouldAbortBlock:` and `prepareObjects:withCompletionHandler:` (build the GL meshes and textures of an object ahead of a frame), `presentScene:withTransition:incomingPointOfView:completionHandler:`, `showsStatistics` (an FPS label over the view), `temporalAntialiasingEnabled` (the accumulation of C20 while the frame is still), `autoenablesDefaultLighting` (the renderer's implicit light, off by default as on iOS), `currentViewport` (the size of the last render), `workingColorSpace` (the device RGB space the GLES output is in), and `colorPixelFormat`, `depthPixelFormat`, `stencilPixelFormat` and `currentRenderPassDescriptor`, which are Metal objects: a GLES view has no Metal device, so they answer invalid or nil, as `device` does. The Telegram files call none of these members except `isJitteringEnabled` (C20).
- Still raises: `overlaySKScene` and `audioEnvironmentNode`. Their classes are absent from the 6.1.3 image: the dyld shared cache of `iPhone4,1/6.1.3_10B329` has no `SKScene` string and no `AVAudioEnvironmentNode` string (nor `AVAudioEngine`, which is backported over AUGraph), and the image has no `SpriteKit.framework`. Each raises `NSInternalInconsistencyException` naming the member.
- Stored, with no effect yet: `loops` (defaults YES; there is no scene timeline to loop at, C18; C23) and `debugOptions` (kept, but no debug geometry is drawn; C24). `usesReverseZ` always reads NO: the GLES renderer keeps the normal depth range, and setting YES is reported once and ignored.
- Gaps: `hitTest` tests triangle elements only, and `boneNode` is nil (no skinning). `showsStatistics` shows the frame rate only. `temporalAntialiasingEnabled` accumulates the samples of C20 while the frame is still; Apple's reprojection is not modelled. `autoenablesDefaultLighting` lights every draw in the scene uniformly, not from a light placed at the camera.
- Measurement: the host test `tests/SceneKit/picking_test.m` (ray against triangle and box, back faces, frustum planes and box containment, index and vertex reads). The runtime case `tests/runtime/cases/scenekit_members.m` checks each implemented member on the 6.1.3 emulator, including a hit at the centre of the plane and none at a corner, frustum containment, preparation, presentation completion, the statistics label, `projectPoint:` at the centre of the view, and lighting that is off by default. It is registered but has not run on the emulator yet; the iOS device configuration does not complete on this branch (see the report that accompanies this change). Not measured on a real device.
- Removed by: a passing run of `scenekit_members`, and for the two raising members, a 6.1.3 image that has the class (none does) or a decision to drop the members.

### C18. sceneTime and playing run on a wall clock with an offset

- Stands in for: SceneKit's scene timeline. `sceneTime` is the wall time plus an offset while playing, and it is held while `playing` is NO; `setSceneTime:` sets it, and the frame's animations and delegate callbacks use it.
- Gaps: there is no timeline, so `loops` has no meaning here and raises (C17). The offset model holds the time across pauses and sets it on the wall clock; SceneKit's own timeline has durations and a scene-wide clock we do not model.
- Measurement: host tests of `RevenantSCNClock` (`tests/SceneKit/clock_test.m`): defaults, set while playing and paused, resume from the held time, and repeated pauses.
- Removed by: a scene timeline with durations, replacing the wall clock.

### C19. audioEngine is the engine of custom audio nodes only

- Stands in for: the engine SceneKit uses for its audio. `SCNView.audioEngine` returns the shared `AVAudioEngine` that custom `AVAudioNode` players attach to (C10, C12). Source players play through OpenAL and are not on this engine, so attaching to it does not affect them.
- Gaps: a caller that expects SceneKit's own engine to hold every player finds only the custom ones.
- Measurement: the node attach test (`audio_test.m`); not measured on the device.
- Removed by: moving source players onto the same engine, or documenting the split as the intended API.

### C20. Jittering accumulates up to eight samples while the frame does not change

- Stands in for: the jittering of SCNView, which SceneKit performs asynchronously and automatically to reduce aliasing. Here each frame renders one sample of an eight-sample Halton sequence (the projection is shifted by up to half a pixel in clip space) and blends it into an accumulation buffer with weight 1/(n+1). The accumulated image is drawn to the drawable. `temporalAntialiasingEnabled` (C17) uses the same accumulation while the frame is still.
- Gaps: the accumulation restarts whenever the sceneTime, the scene or the point of view changes, so an animated frame is one jittered sample and shows the shift rather than a refined edge. Apple's timing and its sample count are not known. The buffers are RGBA8, so the average drifts by up to one level per step. The accumulation is a mix shader between two ping-pong textures, not blending, because blending with `GL_CONSTANT_ALPHA` drew nothing on the emulator. The GLES path is not run on a real device.
- Measurement: host test of the sample range, the eight-frame period, the weights and the mean of a running average (`tests/SceneKit/jitter_test.m`). On the 6.1.3 emulator, the render case (C21) gives 75 intermediate edge pixels with jittering and none without, and an identical centre. A real device is not measured.
- Removed by: a device run that renders a still scene with jittering on and off and compares its edges, and a check of the animated case.

### C21. The GLES draw path drew no geometry on the emulator (resolved)

- Stands in for: nothing now. Before the fix, a snapshot of an `SCNView` with an `SCNPlane` on the 6.1.3 emulator (iPhone4,1, renderer on) was entirely clear, with and without jittering. Three causes, all in our code: `SCNPlane` had no vertex sources or elements, so the renderer had nothing to draw; the jitter path read `GL_FRAMEBUFFER_BINDING`, which the emulator's GLES does not support (it returns 0 and sets `GL_INVALID_ENUM`), so it presented to framebuffer 0; and the accumulation blended with `GL_CONSTANT_ALPHA`, which gave zeros. The framebuffer is now passed in, the plane builds a grid of positions, normals and texture coordinates with triangle indices, and the accumulation is a mix shader between two ping-pong textures.
- Gaps: the emulator's GLES 2 path passes its own guest test `gles2` with the renderer on (76 of 76) once the guest is linked with the project's ld64; the Apple default linker produced binaries that trap with SIGILL on the emulator. The renderer there is SwiftShader, so no device GPU is checked.
- Measurement: the runtime case `scenekit_render` passes on the 6.1.3 emulator (483.8 host s at time scale 10). The plain snapshot has 492 opaque pixels and the jittered one 455; the edges have 0 and 75 intermediate pixels, and the centre differs by 0.
- Removed by: the same case passing on a real 6.1.3 device.

### C22. Late audio buffers are counted and logged, not replayed

- Stands in for: the device's catch-up of late audio. When an IO proc callback runs late, `CoreAudioHle` skips the grid points it missed (`io_proc_timeline_after`) and adds them to `underruns` in the IO proc registration. The count is printed as `underruns=` on the existing `[coreaudio-device] io-proc` lines, next to `callbacks=`: the periodic line and the remove, stop and native-stop lines.
- Gaps: the missed buffers are not replayed, so the guest hears them as a gap; the count is in the log, not returned to the guest.
- Measurement: `emulator/tests/unit/io_proc_timeline_test.cpp`: delayed callbacks record underruns, every grid point is either played or an underrun, and the negative control shows the old schedule drifting off the grid. The log field is not yet read back by a run.
- Removed by: delivering the due buffers to catch up, or a guest-visible count.

### C23. loops is stored and has no effect

- Stands in for: `SCNSceneRenderer.loops`, which restarts playback when the scene timeline reaches its end. The clock has no timeline end (C18): `sceneTime` is a wall clock with an offset, and nothing in the backport marks where the animations' content ends.
- Gaps: the value reads back as it was set and defaults to YES, as Apple's does, but playback never reaches an end, so neither YES nor NO changes anything.
- Measurement: the runtime case `scenekit_members` reads `loops` back after setting it to NO and to YES. The effect is not measured, because there is no effect.
- Removed by: a scene timeline whose end is the last animation's end, so that NO stops `playing` there and YES wraps `sceneTime` to the start; a test that runs an animation past its end with `loops` set each way.

### C24. debugOptions is stored and draws no debug geometry

- Stands in for: the `SCNDebugOptions` overlays: wireframe, bounding boxes, physics shapes, light extents, skeletons and cameras. The value is kept and read back; no debug geometry is drawn, and `SCNDebugOptionRenderAsWireframe` does not change the image.
- Gaps: every option is a no-op. `RenderAsWireframe` and `ShowWireframe` could be drawn on the GLES renderer with `GL_LINES` over the triangle indices of each element, which the renderer already holds.
- Measurement: the runtime case `scenekit_members` reads back `SCNDebugOptionShowWireframe` after it is set. No image is compared.
- Removed by: drawing `RenderAsWireframe` and `ShowWireframe` on the GLES renderer, with a snapshot test that the wireframe image differs from the solid one; or documenting each remaining option as unsupported, with the member answering NO for it.

### C25. Vision requests beyond iOS 6 image-analysis engines

- Stands in for: `VNDetectRectanglesRequest`, `VNRecognizeTextRequest`, `VNClassifyImageRequest`, `VNGeneratePersonSegmentationRequest`, `VNGenerateForegroundInstanceMaskRequest`, and the barcode symbologies other than QR and PDF417.
- Why: iOS 6 Core Image has face detection, but no rectangle, OCR, built-in image-classification, or subject-segmentation engine. Barcode requests use zxing-cpp for QR and PDF417 because Telegram needs them for QR login and passport scanning; the other symbologies are not implemented.
- Behavior: unsupported requests and unsupported requested barcode symbologies complete with `VNErrorUnsupportedRequest` in `VNErrorDomain`.
- Measurement: generated QR and PDF417 fixtures test decoded payloads, symbology, normalized bounds, and corner coordinates. No broad accuracy comparison against Apple's Vision has been run.
- Removed by: an iOS 6 implementation measured against the corresponding Vision requests, or a source change that no longer requires those requests.

### C26. armv7 Objective-C -Wformat warnings are not errors

- Stands in for: `-Werror` on the `-Wformat` class, for the Objective-C targets whose upstream copts set `-Werror` (14 generated targets). The generator adds `-Wno-error=format` only when `is_arch("armv7")`, so the relaxation is armv7-only. Every other `-Werror` stays strict, and no source is edited.
- Why: on armv7 (ILP32) `NSInteger` is `int`, the same width as `long`, so passing an `NSInteger` to `%ld` is the same size and benign at runtime. Clang still reports the type mismatch as `-Wformat`, which `-Werror` makes fatal, for example `submodules/LegacyComponents/Sources/PGPhotoProcessPass.m:135`.
- Behavior: the format warnings stay warnings on armv7. Swift `-warnings-as-errors` is unchanged.
- Measurement: revenant's LLVM 23.1.3 clang defines `__SIZEOF_INT__` and `__SIZEOF_LONG__` as 4 with no `__LP64__` for `--target=armv7-apple-ios6.0`; for arm64 they are 8 with `__LP64__`. After the change, `LegacyComponents` reports its `-Wformat` findings as warnings and no longer fails on them; it still fails on a different error, `UIActivityIndicatorViewStyleMedium` (iOS 13), which is not covered by this entry.
- Removed by: a Telegram source change that passes `-Wformat` on armv7 (none is made here), or the owner's decision to keep `-Werror` strict for these targets.
>
## Removed

### C1. Member list generated from a stand-in SDK install

- Was: the member and device lists were generated from the `iphoneos-sdk 26.2` install `…/14632581444d4c67a8eee6a6172f4e0a` through `REVENANT_GEN_SDK`, while CI resolves `…/d322b52c69944e4a9c3f3d2a883a9259`.
- Measurement that removed it: with the same code, the two installs give identical member and device lists (0 changed lines). The 26 lines that differed came from a stale committed list after the deprecation rule changed, not from the installs.
- Removed in: `77cf0704e` (list regenerated from `d322…`, the package CI resolves).

### C5. Device check skipped on CI

- Was: `device_members_test` skipped on CI, because the checks job did not restore the iOS 6.0 armv7 shared cache that holds the inventory.
- Removed in: `e01213a11` (the checks job restores the cache with the key the other jobs use, fetches it on a miss, and asserts the inventory is in place), and `75413488d` (the cache restore lacks `classes_armv7.json`, so the job writes it with the firmware `classes` action when absent).
