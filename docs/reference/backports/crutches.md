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

- Stands in for: `VNDetectRectanglesRequest`, `VNClassifyImageRequest`, `VNGeneratePersonSegmentationRequest`, `VNGenerateForegroundInstanceMaskRequest`, and the barcode symbologies other than QR and PDF417.
- Why: iOS 6 Core Image has face detection, but no rectangle, built-in image-classification, or subject-segmentation engine. Barcode requests use zxing-cpp for QR and PDF417 because Telegram needs them for QR login and passport scanning; the other symbologies are not implemented. `VNRecognizeTextRequest` is implemented with Tesseract and is not listed here; its stand-ins are C26 to C36, described in [Vision text recognition on iOS 6](../../explanation/backports/vision-text.md).
- Behavior: unsupported requests and unsupported requested barcode symbologies complete with `VNErrorUnsupportedRequest` in `VNErrorDomain`.
- Measurement: generated QR and PDF417 fixtures test decoded payloads, symbology, normalized bounds, and corner coordinates. No broad accuracy comparison of barcodes against Apple's Vision has been run.
- Removed by: an iOS 6 implementation measured against the corresponding Vision requests, or a source change that no longer requires those requests.

### C26. Tesseract's accurate models stand in for Vision's accurate text recognizer

- Stands in for: `VNRecognizeTextRequest` at the accurate level, for every revision, language and region of interest.
- Why: iOS 6 has no text recognizer, so the backport reads the text with Tesseract 5.5.3 and the pinned tessdata_best LSTM models.
- Behavior: the text matches macOS Vision on the fixtures exactly. Line and word boxes deviate from Vision's in normalized coordinates by at most 0.0323 (`uk.png`) against a tolerance of 0.04. The boxes are Tesseract's segmentation, so a region with another line structure may split or join lines differently from Vision.
- Measurement: `frameworks/Backports/tests/Vision/text_test.mm` compares each fixture with macOS Vision on the same image. On the iPhone 4S a two-line image takes 4.2 to 5.2 s per call (C36).
- Removed by: an iOS 6 implementation of Vision's own recognizer, measured against macOS Vision on the same fixtures.

### C27. The fast models stand in for Vision's fast text recognizer, with misreads

- Stands in for: `VNRequestTextRecognitionLevelFast` for the six languages of macOS's fast list: `en-US`, `fr-FR`, `it-IT`, `de-DE`, `es-ES` and `pt-BR`.
- Why: tessdata_fast is Tesseract's fast LSTM model set, the nearest match to Vision's fast engine.
- Behavior: the fast models misread characters: `42` reads as `A2` in `de.png`. The fast check accepts an edit distance of up to 0.2 of the expected length; the accurate check is exact. Russian and Ukrainian are refused at this level, as on macOS.
- Measurement: `text_test.mm` runs the fast fixtures with that tolerance. On the iPhone 4S the two-line fast recognition takes about 0.65 s (C36).
- Removed by: a fast engine measured against macOS Vision on the fixtures without the edit-distance allowance.

### C28. Word ranges, confidence, candidates and line text stand in for Vision's observations

- Stands in for: `VNRecognizedTextObservation` as Vision builds it: character ranges, Vision's confidence values, and the candidates of `topCandidates:`.
- Why: Tesseract reports lines and words, with a confidence per word; the backport maps them onto Vision's types.
- Behavior: word ranges cover Tesseract's words, so `10:30` is one word where macOS Vision reports two. A word whose text is not found in the line text is skipped. The confidence is the mean of Tesseract's word confidences divided by 100, so it is continuous where Vision's are 0.5 or 1.0. `topCandidates:` returns one candidate per line. The text of a line is Tesseract's own line text, so the spacing of Latin text is kept. `minimumTextHeight` is applied to the line boxes.
- Measurement: `text_test.mm` checks the expected lines, word ranges and boxes of each fixture. The confidence values are not compared with macOS Vision.
- Removed by: a character-level segmentation of the line, and a confidence mapping measured against Vision's values on the fixtures.

### C29. Dictionary toggles and a user-words file stand in for language correction and custom words

- Stands in for: `usesLanguageCorrection` and `customWords`.
- Why: Tesseract applies its dictionaries to words and reads extra words from a user-words file.
- Behavior: `usesLanguageCorrection = NO` turns off Tesseract's dictionaries (the `load_*_dawg` variables). That approximates Vision's behaviour; it is not Vision's algorithm. `customWords` is written to a file in `NSTemporaryDirectory()`, named by a hash of the words, and read by Tesseract as `user_words_file`.
- Measurement: none against macOS Vision for either option.
- Removed by: a correction measured against macOS Vision on the fixtures with correction on and off, and a custom-word test against Vision's output.

### C30. Nearest models stand in for the identifiers Tesseract has no model for

- Stands in for: the Vision identifiers that have no Tesseract model of their own.
- Why: Tesseract has no Cantonese or Najdi Arabic model, and one Norwegian model serves three identifiers.
- Behavior: `yue-Hans` and `yue-Hant` read with `chi_sim` and `chi_tra`; `ars-SA` with `ara`; `no-NO`, `nn-NO` and `nb-NO` with `nor`; `vi-VT` with `vie`. The vertical models `chi_sim_vert` and `jpn_vert` are not packaged, so Tesseract logs that it cannot find them and reads horizontal text.
- Measurement: none against macOS Vision for these identifiers; the fixtures contain no Cantonese, Najdi Arabic or vertical text.
- Removed by: a model for each identifier, or the vertical models packaged and measured on vertical fixtures.

### C31. The CJK spacing rule approximates the spacing of Tesseract's words

- Stands in for: the spacing between Chinese and Japanese words in Vision's text.
- Why: Tesseract puts a space between each Chinese or Japanese word unit, and Vision does not.
- Behavior: the backport drops a space when both neighbours are ideographs or kana (U+3040 to U+30FF, U+3400 to U+9FFF, U+F900 to U+FAFF). Without it the Chinese fixture reads `你 好 世界`. Hangul is not covered.
- Measurement: `text_test.mm` on the Chinese and Japanese fixtures.
- Removed by: spacing taken from Vision's own rule, measured on the fixtures, or a Tesseract output without the extra spaces.

### C32. A cropped copy stands in for the region of interest

- Stands in for: `regionOfInterest` as Vision applies it inside the image.
- Why: Tesseract's `SetRectangle` returned no lines for a region that starts at row 0.
- Behavior: the region is copied into its own buffer before recognition, and the boxes are shifted back by the region's origin. Each call copies the region once.
- Measurement: `text_test.mm` checks the region fixture (region {0, 0.6, 1, 0.4}).
- Removed by: a Tesseract region that reads a region starting at row 0, measured on the fixture.

### C33. A Core Image luma plane stands in for Vision's grayscale input

- Stands in for: the luminance Vision recognises from.
- Why: Tesseract reads one 8-bit plane. Core Image renders the image as RGBA8 and the plane is its luma, `(306 R + 601 G + 117 B + 512) >> 10`, with the orientation applied afterwards.
- Behavior: the luma of a photograph may differ from Vision's. For each call the RGBA scratch is 4 bytes per pixel and the plane is 1 byte per pixel; both are released when the call returns, since `RevenantVisionTextLines` drains its own autorelease pool.
- Measurement: the fixtures pass. The luma is not compared with Vision's.
- Removed by: a plane measured against Vision's input on the fixtures, or a plane rendered without the RGBA scratch.

### C34. A recognition engine is kept for the life of the process

- Stands in for: Vision's loading and unloading of its models for each request.
- Why: a Tesseract model takes about 0.5 s to load on the iPhone 4S, so the engine is kept per datapath, language, user-words file and correction setting, and replaced when any of them changes.
- Behavior: after the first two-line recognition the engine keeps about 25 MB resident on the iPhone 4S, against a peak of about 65 MB. The host test prints `LEAK` lines at exit because the engine is still allocated when the leak checker runs. The engine is a raw pointer: a `unique_ptr` version aborted at exit with `mutex lock failed: Invalid argument`.
- Measurement: the device probe, three calls in one process (table in [Vision text recognition on iOS 6](../../explanation/backports/vision-text.md)).
- Removed by: a load and unload per request, measured for time and memory on the device.

### C35. Tesseract and Leptonica are built for iOS with reduced features and a NEON patch

- Stands in for: the text engine's libraries on iOS 6, which have no packaged OpenMP runtime, image codecs or training tools.
- Why: Tesseract is built with `-DOPENMP_BUILD=OFF`, Leptonica without its codecs, and the TIFF probe is answered in the build (`LEPT_TIFF_RESULT`, `LEPT_TIFF_COMPILE_SUCCESS`). Tesseract finds NEON at run time only through `getauxval` or `elf_aux_info`, which Darwin lacks, so the compiled NEON matrix path was never selected. `packages/t/tesseract/patches/5.5.3-apple-neon-sysctl.patch` reads `hw.optional.neon` on Apple ARM instead.
- Behavior: Tesseract runs on one of the two A5 cores. Leptonica prints `pixReadMemTiff`, `bmfCreate` and `changeFormatForMissingLib` on stderr; none changes a result. With the patch the NEON path is selected (`dotproduct neon`); the text is unchanged, and the time is the same as the generic path on the device.
- Measurement: the device probe with `DOTPRODUCT=neon` and `DOTPRODUCT=generic` on the two-line image: 3.73 to 3.84 s and 3.73 to 3.82 s per call.
- Removed by: an OpenMP build of Tesseract for iOS, which lets the LSTM use both cores, or a Tesseract release that reads `hw.optional.neon` on Darwin, which drops the patch.

### C36. The recognition time stands in for Vision's latency on the device

- Stands in for: the latency of `VNRecognizeTextRequest` on the device, which Apple's engine provides.
- Why: Tesseract's LSTM runs on the A5 CPU, and its page analysis runs first. Neither the NEON path (C35) nor splitting a region across two engines on two threads reduced the time on the device, and the cost that dominates is not measured.
- Behavior: the accurate level takes 4.2 to 5.2 s for the two-line fixture and 29 to 32 s for a 12-line page on the iPhone 4S; the fast level takes about 0.65 s for the two-line fixture. The split was tried and removed: on the 12-line page it took 29.3 s where the serial build took 31.3 s, and on the two-line fixture it took 4.3 s where the serial build took 4.2 s.
- Measurement: the device probe, three calls per configuration, on the iPhone 4S (dual A5, iOS 6.1.3).
- Removed by: a profile that names the dominant cost on the device, and a change that brings a 12-line page below a stated target with the accurate fixtures unchanged.

### C37. armv7 Objective-C -Wformat warnings are not errors

- Stands in for: `-Werror` on the `-Wformat` class, for the Objective-C targets whose upstream copts set `-Werror` (14 generated targets). The generator adds `-Wno-error=format` only when `is_arch("armv7")`, so the relaxation is armv7-only. Every other `-Werror` stays strict, and no source is edited.
- Why: on armv7 (ILP32) `NSInteger` is `int`, the same width as `long`, so passing an `NSInteger` to `%ld` is the same size and benign at runtime. Clang still reports the type mismatch as `-Wformat`, which `-Werror` makes fatal, for example `submodules/LegacyComponents/Sources/PGPhotoProcessPass.m:135`.
- Behavior: the format warnings stay warnings on armv7. Swift `-warnings-as-errors` is unchanged.
- Measurement: revenant's LLVM 23.1.3 clang defines `__SIZEOF_INT__` and `__SIZEOF_LONG__` as 4 with no `__LP64__` for `--target=armv7-apple-ios6.0`; for arm64 they are 8 with `__LP64__`. After the change, `LegacyComponents` reports its `-Wformat` findings as warnings and no longer fails on them; it still fails on a different error, `UIActivityIndicatorViewStyleMedium` (iOS 13), which is not covered by this entry.
- Removed by: a Telegram source change that passes `-Wformat` on armv7 (none is made here), or the owner's decision to keep `-Werror` strict for these targets.
### C38. Page search is injected JavaScript, not WebKit's find

- Stands in for: the find of WebKit behind UIFindInteraction (iOS 16). The backport injects a script that walks the text nodes of the page in document order, splits the matches and wraps them in spans (yellow for matches, orange for the current one).
- Gaps: the DOM changes while a search is active (split text nodes and wrapping spans), so a page script that reads its own text nodes can see the change. Matches inside iframes, shadow roots and text generated by CSS are not found.
- Measurement: the Mac Catalyst WKWebView probe gives counts 5, 1, 0 and 5, and the backward wrap from none to 4, the same as native find on the same pages (`.cache/scratch/gaps-ui/find-app`, outside the repository). Not measured on iOS 6 UIWebView.
- Native find checked (2026-10-27): the engine's pin, WebKit commit c70a794, has native find in two places. WebKit2 has `-[WKWebView _findString:options:maxCount:]` and the `FindController` of the web process, and WebKitLegacy has `-[WebView findString:options:]` (`Source/WebKitLegacy/mac/WebView/WebViewPrivate.h`). Both are reached only through the engine's own WebKit. The backport's WKWebView runs on the system UIWebView, and the system WebKit of iOS 6.1.3 is not in the repository, so its find is unknown. The marker run on the phone probes `WebView` and `UIWebDocumentView` for `findString:options:` and `searchFor:direction:caseSensitive:wrap:`, and `UIWebView` for `_webView` (`/var/revenant/find-native-probe.txt`). Measured on an iPad2,2 (iOS 6.1.3) on 2026-10-27: `_documentView` returns a `UIWebBrowserView`, which answers `webView` with a `WebView` that answers `findString:options:` and `searchFor:direction:caseSensitive:wrap:`. On a plain UIWebView with the long test page, `findString:options:` (case-insensitive) returned 1 for "page" (three steps), 1 for "bottom" and 0 for "zzzz", and `markAllMatchesForText:caseSensitive:highlight:limit:` counted 3 for "page", the same as the JS search. `window.pageYOffset` stayed 0 after the "bottom" find, so whether the native find scrolls is not yet measured: the run that would have captured the scroll-view offset wrote no results. The system find reaches UIWebView, so C38 and C39 are to be replaced by it once that scroll is measured; until then they stay open.
- Removed by: a device run on the iPhone 4S (iOS 6.1.3) with the same counts, and a check that a page script still reads its text after the search is cleared.

### C39. Search results come by polling, not from the page

- Stands in for: the result callback of UIFindInteraction. The session starts a 0.05 s NSTimer that calls `poll()` in the page until the search reports done, then posts `RevenantFindSessionResultsDidChange`. A step asked for during a search waits for the search to finish.
- Gaps: up to 50 ms of latency after the last batch. The timer runs only while a search is active and stops on clear.
- Measurement: the Catalyst run gives the same counts as the synchronous search (C38). The polling period is not measured on a device.
- Removed by: a page-side notification from the batch loop in place of the timer, or a device run that shows the period is not visible.

### C40. The obstruction and the keyboard overlap are set by hand

- Stands in for: the bottom obstruction that UIFindInteraction computes from its navigator and the keyboard. The navigator places itself above the keyboard from `UIKeyboardWillChangeFrameNotification` (frame from `UIKeyboardFrameEndUserInfoKey`, converted to view coordinates) and gives the session its height plus the overlap through `revenant_setBottomObstruction:`.
- Gaps: the keyboard path is measured only by the frame that the notification reports, not by a keyboard on the device. The navigator's height is a constant, 44 pt.
- Measurement: the first-scroll centring uses innerHeight minus the obstruction. In the Catalyst probe it centres the middle page's first match at 713, native at 718. The 5 point difference is accepted by the coordinator and is not a crutch: native's innerHeight is 631 with its bar up, 54 below the page's 685, and the bar is 44 pt tall. Keyboard overlap is not measured on any device.
- Removed by: a device run with the keyboard up during a find session, comparing the centred position with native WKWebView on the same page.

### C41. The navigator is our own view, not Apple's find bar

- Stands in for: the find navigator of UIFindInteraction (iOS 16), which does not exist on iOS 6. `RevenantFindNavigator` is a plain UIView with previous and next chevrons (U+2039 and U+203A), a search field, a count label, a close control, and the replace row when it is requested.
- Gaps: the look, tint and spacing are ours, and the navigator does not use the system's find bar animation. Its colours follow the trait collection only as far as the UIKit backport delivers trait changes.
- Measurement: the Catalyst comparison and the layout dump in `find-app/main.m`. Not measured on a device.
- Removed by: a review of the navigator against a native find bar screenshot on iOS 16 and a device screenshot on iOS 6.1.3.

### C42. Page calls are synchronous on iOS 6

- Stands in for: the asynchronous `evaluateJavaScript:` of WKWebView, which the backport does not have on UIWebView. The backport evaluates `stringByEvaluatingJavaScriptFromString:` on the main thread, so each `poll()`, `step()` and `clear` call blocks the caller for its duration. The search itself is batched through `setTimeout` inside the page, 200 text nodes per tick, so no single call walks the whole page.
- Gaps: a `poll()` or `step()` call that runs during a long batch waits for that batch to finish on the page side. The batch size was chosen on the host, not on the device.
- Synchronous bridge checked (2026-10-27): `work/wk-telegram` has `RevenantSyncBridge.m`, which answers page-to-native calls synchronously. The page makes a synchronous request, an NSURLProtocol answers it on the main queue, and the answer is returned in the request's body. Find's calls run the other way, native to page, through `stringByEvaluatingJavaScriptFromString:`, which UIWebView already runs synchronously. The bridge does not serve C42, so this entry keeps its own mechanism, the UIWebView call.
- Measurement: the counts are identical with batching (Catalyst). The blocking time per call is not measured on iOS 6.1.3.
- Removed by: a device measurement of the blocking time per call and of the batch size, and a batch size chosen from it.

### C43. No behaviour of the find backport has run on an iOS 6 device

- Stands in for: the iOS 6 runtime of the find backport: `UIFindInteraction` and `UIFindSession` on the UIKit backport, WKWebView's `findInteraction` over UIWebView, and the page script on the iPhone 4S's WebKit.
- Gaps: no run on an iOS 6 device has written its results. The test app (`device-find/`, outside the repository) installed and launched on the iPhone 4S on 2026-10-27 and its results file was never written. On the iPad2,2 the native-find run wrote no `find-native-run.txt`; the only files from the iPad are the native probe and the method list (C38). The symbol gate (586 members, 180 objects, 26 areas) checks names, not behaviour.
- Measurement: none on a device for the backport. The iPad2,2 run measured the system find's methods (C38), not the backport's search. The host test passes (`backports_avfoundation`, `backports_uikit`, symbol gate).
- Removed by: a device run of the find test app whose results file has the counts of C38 and the centred offsets of C40.

### C44. WKWebpagePreferences stores JavaScript and content-mode choices the engine does not apply

- Stands in for: `WKWebpagePreferences.allowsContentJavaScript` (JavaScript off for one page) and `preferredContentMode` (desktop or mobile rendering for one page).
- Gaps: both values read back as set. The engine has one JavaScript state and one rendering mode for every page, so a page always runs JavaScript and renders the same way whatever the value. Setting `allowsContentJavaScript` to NO logs once, and setting `preferredContentMode` at all logs once (`src/WebKit/WKWebpagePreferences13.m`).
- Measurement: none. No test reads these two members back or loads a page with JavaScript off, and the effect is not measured, because there is none.
- Removed by: a per-page JavaScript switch in the engine, with a host or device test that loads a page with `allowsContentJavaScript` NO and checks that its script did not run; or the owner's decision to answer NO for both members as unsupported.

### C45. A document-start script that the rewrite does not reach runs after the page's own scripts

- Stands in for: `WKUserScriptInjectionTimeAtDocumentStart`, for a main-frame load the document rewrite does not claim: a load the engine starts itself without a link click or form post, and `file:` or `data:` loads (`docs/explanation/backports-open-members.md`).
- Gaps: the script runs after the page's own scripts, where Apple's runs before them. `revenant_installScripts:` logs once that the rewrite did not reach the page (`src/WebKit/WKWebView.m`).
- Measurement: the rewrite path is measured by the host case `webkit_document_start` (44 checks through the protocol and the rewrite, negative control detected 22). The fallback path is not measured.
- Removed by: a loader that tags every main-frame load before it starts, measured by `webkit_document_start` with those loads added; or a device run that shows a document-start script ordered before the page's scripts on each of those loads.

### C46. Swizzled AVCaptureMetadataOutput and AVCaptureSession methods add QR codes on iOS 6

- Stands in for: a QR path on the iOS 6 metadata output, which the release lacks; the class is present, so the overlay cannot add a type. `+load` in `frameworks/Backports/src/AVFoundation/AVCaptureMetadataOutput+MachineReadableCode7.m` replaces six implementations with `method_setImplementation`: `availableMetadataObjectTypes`, `metadataObjectTypes`, `setMetadataObjectTypes:` and `setMetadataObjectsDelegate:queue:` on `AVCaptureMetadataOutput`, and `addOutput:` and `removeOutput:` on `AVCaptureSession`. Each replacement calls the implementation it replaced.
- Why it cannot be avoided: an iOS 6 system class's existing methods have no link-time override, and the owner directed a standard-API shape, so an app's own `AVCaptureMetadataOutput` code gets QR unchanged.
- Widens: `availableMetadataObjectTypes` lists QR on iOS 6 whether or not the app asks for it. The getter and setter otherwise pass through to the system: while QR is not requested and no internal output runs, the native implementations receive the arrays the app passed. Each metadata output also keeps a weak session reference, which is inert.
- Measurement: the iOS 6.0 class inventory (`.cache/dyld/6.0/classes_armv7.json`, described in `docs/reference/backports/AVFoundation/README.md`) lists the owning classes of the six selectors and shows no QR path. `BackportsQRMetadataProbe` checks that a face request leaves the session with one output and a QR request adds one, and that the type reads back. Not run on a device.
- Removed by: a system hook that makes QR available on iOS 6 `AVCaptureMetadataOutput`, which the 6.0 inventory shows does not exist; or an explicit backport class the app opts into instead of the transparent standard API.

### C47. Non-UTF-8 charsets without a converter are replaced with U+FFFD

- Stands in for: the character conversion of a QR code whose ECI names a charset other than ISO-8859-1, UTF-8 or ASCII (Shift_JIS, Windows-125x, Big5, GB, EUC-KR and the rest). `append_converted` in `frameworks/Backports/src/AVFoundation/RevenantQRCode.c` replaces every non-ASCII byte with U+FFFD when no converter is registered.
- Why: no ECI converter is registered on the metadata path, and no Apple charset converter is wired into the engine yet.
- Behavior: the code is delivered with U+FFFD in place of each non-ASCII byte, so the text is wrong but valid UTF-8. A code whose declared UTF-8 or ASCII bytes are invalid is not delivered, and the drop is logged with a running count.
- Measurement: not measured with such a code. The host fixtures cover UTF-8 text without an ECI (`qr_decoder_test`, including Cyrillic, Chinese and accented Latin), which decodes exactly; no fixture carries an ECI or ISO-8859-1 bytes.
- Removed by: registering a converter in the metadata path that maps the ECI to the charset (CoreFoundation's encodings), measured with a fixture per charset in the host test.

## Removed

### C1. Member list generated from a stand-in SDK install

- Was: the member and device lists were generated from the `iphoneos-sdk 26.2` install `…/14632581444d4c67a8eee6a6172f4e0a` through `REVENANT_GEN_SDK`, while CI resolves `…/d322b52c69944e4a9c3f3d2a883a9259`.
- Measurement that removed it: with the same code, the two installs give identical member and device lists (0 changed lines). The 26 lines that differed came from a stale committed list after the deprecation rule changed, not from the installs.
- Removed in: `77cf0704e` (list regenerated from `d322…`, the package CI resolves).

### C5. Device check skipped on CI

- Was: `device_members_test` skipped on CI, because the checks job did not restore the iOS 6.0 armv7 shared cache that holds the inventory.
- Removed in: `e01213a11` (the checks job restores the cache with the key the other jobs use, fetches it on a miss, and asserts the inventory is in place), and `75413488d` (the cache restore lacks `classes_armv7.json`, so the job writes it with the firmware `classes` action when absent).
