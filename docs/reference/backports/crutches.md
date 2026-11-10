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

### C45. The document-start hook is assumed to run before the page's own scripts

- Stands in for: `WKUserScriptInjectionTimeAtDocumentStart`, for every main-frame load, through the WebKit1 `webView:didClearWindowObject:forFrame:` delegate callback (`src/WebKit/WKWebView.m`). The `NSURLProtocol` rewrite that stood in before was removed with `RevenantDocumentProtocol.m`.
- Gaps: the callback is meant to run before the page's own scripts. That order is not measured on a device, so the entry stands until it is.
- Measurement: none for the WebKit1 hook. The host case `webkit_document_start` and its macOS oracle measured the removed rewrite and were deleted with it.
- Removed by: a device run that shows a document-start script ordered before the page's scripts on a `file:` load, a `data:` load, a history load and a network load.

### C46. Swizzled AVCaptureMetadataOutput and AVCaptureSession methods add QR codes on iOS 6

- Stands in for: a QR path on the iOS 6 metadata output, which the release lacks; the class is present, so the overlay cannot add a type. `+load` in `frameworks/Backports/src/AVFoundation/AVCaptureMetadataOutput+MachineReadableCode7.m` replaces six implementations with `method_setImplementation`: `availableMetadataObjectTypes`, `metadataObjectTypes`, `setMetadataObjectTypes:` and `setMetadataObjectsDelegate:queue:` on `AVCaptureMetadataOutput`, and `addOutput:` and `removeOutput:` on `AVCaptureSession`. Each replacement calls the implementation it replaced.
- Why it cannot be avoided: an iOS 6 system class's existing methods have no link-time override, and the owner directed a standard-API shape, so an app's own `AVCaptureMetadataOutput` code gets QR unchanged.
- Widens: `availableMetadataObjectTypes` lists QR on iOS 6 whether or not the app asks for it. The getter and setter otherwise pass through to the system: while QR is not requested and no internal output runs, the native implementations receive the arrays the app passed. Each metadata output also keeps a weak session reference, which is inert.
- Measurement: the iOS 6.0 class inventory (`.cache/dyld/6.0/classes_armv7.json`, described in `docs/reference/backports/AVFoundation/README.md`) lists the owning classes of the six selectors and shows no QR path. The iOS 6.1.3 shared cache (`.cache/dyld/6.1.3/dyld_shared_cache_armv7`, read 2026-11-10) exports one metadata object type constant, `AVMetadataObjectTypeFace`, and no QR constant, so the release has no QR type to add to or report. `BackportsQRMetadataProbe` checks that a face request leaves the session with one output and a QR request adds one, and that the type reads back. Not run on a device.
- Removed by: a system hook that makes QR available on iOS 6 `AVCaptureMetadataOutput`, which the 6.0 inventory shows does not exist; or an explicit backport class the app opts into instead of the transparent standard API.

### C47. UIKeyboardAppearanceLight is the Default appearance on iOS 6

- Stands in for: `UIKeyboardAppearanceLight`, which the SDK declares as value 2 for iOS 7. The lowered header in `toolchain/modules/apple/lowered.lua` declares it `UIKeyboardAppearanceLight API_AVAILABLE(ios(6.0)) = UIKeyboardAppearanceDefault`, so the value is 0. On iOS 6 the keyboard has one light appearance, Default, and one dark one, Alert (value 1, the same as Dark).
- Gaps: the light and default appearances are one value on iOS 6, so an app cannot tell them apart there, and nothing else changes.
- Measurement: the iOS 27.2 SDK header `UIKit.framework/Headers/UITextInputTraits.h` declares `UIKeyboardAppearanceDefault`, `UIKeyboardAppearanceDark` and `UIKeyboardAppearanceLight` (the last two with `API_AVAILABLE(ios(7.0))`), and `UIKeyboardAppearanceAlert` as an alias of Dark. `toolchain/modules/apple/lowered.lua` (lines 131 to 137) lowers `Light` to `UIKeyboardAppearanceDefault`, so an iOS 6 build takes value 0 for it. The enum constants are not exported symbols, so the 6.1.3 cache cannot show them. Not run on a device.
- Removed by: none for iOS 6. The mapping is the iOS 6 behaviour, not a stand-in for a missing one.

### C48. The download status is Current or NotDownloaded from NSURLUbiquitousItemIsDownloadedKey

- Stands in for: `URLResourceValues.ubiquitousItemDownloadingStatus` and `NSURLUbiquitousItemDownloadingStatusKey`, which iOS 7 introduced. The Foundation overlay getter in `toolchain/modules/apple/lowered.lua` returns the status through `NSURLUbiquitousItemDownloadingStatusKey` inside an `#available(iOS 7.0)` branch, and otherwise reads `NSURLUbiquitousItemIsDownloadedKey` (iOS 5 to 7, deprecated in the SDK as equal to Current): `.current` when the item is downloaded, `.notDownloaded` when it is not, and nil when the key is absent. The fallback builds those two values from the status names `NSURLUbiquitousItemDownloadingStatusCurrent` and `NSURLUbiquitousItemDownloadingStatusNotDownloaded` rather than naming the constants: iOS 6 does not export them, and the Backports define them with those same string values (`frameworks/Backports/src/Foundation/NSURL+UbiquitousItemTransfer.m`). The names are also the values on macOS 27.
- Binding: iOS 6.0 and 6.1.3 do not have `NSURLUbiquitousItemDownloadingStatusKey`; no image in either dyld shared cache exports it. The header keeps it at iOS 7.0, so the import binds weakly and is NULL on iOS 6. Lowering it to iOS 6.0 makes the import strong, which stops the image from loading on iOS 6. Foundation exports `NSURLUbiquitousItemIsDownloadedKey` on both releases, so it binds strongly; the header lowers its iOS 7 deprecation, which the SDK imports as unavailable in iOS, to iOS 5.0.
- Gaps: `.downloaded`, a local copy that is not the newest version, is never returned, because iOS 6 does not report it. Downloading, uploading and their errors are not mapped. The deprecated key "has never behaved as documented in earlier releases" (SDK note), so the answer is only as exact as iOS 6 is.
- Measurement: the getter text was compiled against stand-in types at an iOS 7 target; not run on a device, and the Swift overlay itself was not typechecked for iOS 6. The iOS 6.1.3 shared cache (read 2026-11-10) exports `NSURLUbiquitousItemIsDownloadedKey`, `NSURLUbiquitousItemPercentDownloadedKey`, `NSMetadataUbiquitousItemIsDownloadedKey` and `NSMetadataUbiquitousItemPercentDownloadedKey`, and no downloading-status key. The percent key is not used: an iCloud item in each state cannot be made on the test device, so a `.current` or `.notDownloaded` answer read from it would be a guess.
- Removed by: none for iOS 6. A device-level check of `.current` and `.notDownloaded` against a real iCloud file would replace the assumption that the deprecated key is accurate.

### C49. IOSurface is a CPU buffer on iOS 6, with no kernel surface behind it

- Stands in for: the IOSurface C API (`IOSurfaceCreate`, lookup, lock and unlock, base addresses, plane accessors, values, use counts, purgeable state), which iOS 6 lacks. `src/IOSurface/IOSurfaceCPU.m` implements the SDK's `IOSurfaceRef.h` signatures over one `calloc`ed block per surface. The CF type is registered through CoreFoundation's `_CFRuntimeRegisterClass` and `_CFRuntimeCreateInstance`, which the iOS SDK exports but does not declare; the class descriptor is declared in the file.
- Gaps: a surface is visible to `IOSurfaceLookup` only inside its process; there are no global surfaces and no mach ports, so `IOSurfaceCreateMachPort`, `IOSurfaceLookupFromMachPort`, the property maximum and alignment queries, the component and subsampling queries and `IOSurfaceAllowsPixelSizeCasting` are not exported and fall to the skeleton's abort stub. A lock counts nested locks and bumps the seed on a write unlock, but does not exclude other threads. Unlocking an unlocked surface returns `kIOReturnBadArgument`, where the system returns `kIOReturnNotLocked`, which this SDK does not declare. `IOSurfaceSetPurgeable` records the state; volatile reclaims nothing, and empty zeroes the buffer. Rows are aligned to 16 bytes and the allocation is not page-rounded; macOS aligns rows to 128 and rounds allocations to pages, so the row stride differs from the system's while the values match. Without a bytes-per-element key, only BGRA (4), RGhA (8) and L008 (1) are inferred from the pixel format. Values are stored as given; the colour space is an opaque property.
- Measurement: `tests/IOSurface/main.c` prints the same output against the macOS framework and against this file. A probe covering half-float surfaces with a colour-space value, planar surfaces, seeds, purgeable state, lookup after use and missing keys matched the macOS framework except for the row stride and allocation size. Compiled with clang for armv7 and arm64 at `-target *-apple-ios6.0` against the iOS 26.2 SDK, with no warnings. Not run on a device.
- Removed by: none for iOS 6. The Metal path (C50) and the layer path (C51) copy this buffer to and from the GPU and the screen; a device with shared IOSurface memory would make both copies unnecessary.

### C50. An IOSurface texture is a GL texture copied from the surface and synchronised at commit

- Stands in for: `-newTextureWithDescriptor:iosurface:plane:`, which binds the surface's memory to the GPU. The surface is a CPU buffer on iOS 6 (C49), which CoreVideo cannot bind, so the texture is an ordinary GL texture filled from the surface's bytes (`src/Metal/RevenantMetalTexture.m`).
- Gaps: the texture is a copy. It is uploaded when it is created and again whenever the surface's seed changes, which happens on each write unlock. Rendering into it, or blitting into it, marks it dirty; a committed command buffer then reads each dirty texture back into the surface with `glReadPixels`, once per commit rather than per draw, and clears the mark. A CPU write without lock and unlock is not seen. A CPU write that lands while the GPU has unsynchronised rendering keeps the GPU result, and logs it. Only 8-bit RGBA and BGRA, 2D, one level and one plane are supported, as before.
- Measurement: all 81 `src/Metal/*.m` files compile for armv7 and arm64 with iOS 6.0 and the target's flags; the existing Metal host test `binary_archive_test` passes (23 checks). The surface path has not run against GL ES: there is no device or emulator run of it yet, and the host has no GL ES context.
- Removed by: none for iOS 6. The layer path (C51) reads the surface's bytes after the commit that rendered into it.

### C51. An IOSurface assigned to a layer's contents is shown as a CGImage copied from the surface

- Stands in for: `-[CALayer setContents:]` with an `IOSurfaceRef`, which iOS 6 does not show from a CPU buffer. `src/Metal/CALayer+IOSurfaceContents.m` swaps `setContents:` for a replacement in `+load`, the same way the other swizzles in the backports do. Only a value whose `CFGetTypeID` is `IOSurfaceGetTypeID()` is converted. `nil` and every other value, including a `CGImageRef`, reach the original method unchanged: same object, no copy, same arguments. Telegram's MetalEngine sets `layer.contents` to a surface only when its surface id changes (`MetalEngine.swift:975`) and to `nil` when the layer has no surface (`:986`), so the conversion runs on those changes; the refresh below covers the writes in between.
- Conversion: under `IOSurfaceLock` with `kIOSurfaceLockReadOnly` the bytes of the rows (`IOSurfaceGetBytesPerRow` times the height) are copied once into a `CFData`, which backs a `CGDataProvider` and a `CGImage` with 8 bits per component, 32 bits per pixel, device RGB and premultiplied alpha. BGRA is `kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst`; RGBA is `kCGImageAlphaPremultipliedLast`. The original method receives the image, which Core Animation retains; the converter releases its own reference at once. The layer keeps the surface, retained, and the seed it read under the lock, in an associated object. A `nil` value, or any value that is not a surface, drops that association and the layer's entry in a weak registry.
- Per frame: `RevenantIOSurfaceLayersRefresh()` runs at the end of `RevenantMetalSynchroniseSurfaceTextures()`, once per committed command buffer (C50), and rebuilds the image of each registered layer whose surface seed has changed since its last conversion. A layer whose seed is unchanged keeps its image and costs one seed read. Setting the same surface with the same seed does not rebuild the image either.
- Threads: a conversion runs on the main thread. A call from another thread, or a refresh from a commit made on another thread, is dispatched asynchronously to the main queue, so the layer changes after the call returns. The order of a background set against a later main-thread set is not kept. The registry is guarded by `@synchronized`.
- Gaps: the layer's `contents` reads back as the `CGImage`, not the surface. Formats other than 8-bit BGRA and RGBA (for example the 64-bit half-float surface Telegram creates for its extended-range pixel format, `MetalEngine.swift:594`) are passed on unchanged, as before, so they show nothing on iOS 6. The image has no scale, and `contentsScale` is left as the layer has it; how a Retina layer draws the image is not checked. A surface changed on the CPU without a lock and unlock is not seen until the next write unlock. The change reaches the screen at the next Metal commit, not at the write.
- Measurement: `tests/QuartzCore/iosurface_contents_test.m` runs on macOS against the native QuartzCore with the swizzle installed, 12 checks: a `CGImage` keeps its identity, `nil` clears, a BGRA surface becomes a `CGImage` with its bytes, the same surface and seed keep the image, a write is shown after the refresh, an unchanged seed keeps the image, a `CGImage` set after a surface stops the refresh, an unsupported format is passed on, and a surface set from a background thread appears on the main thread. Its negative run fails one check. `src/Metal/CALayer+IOSurfaceContents.m` compiles for armv7 and arm64 with `-target *-apple-ios6.0` against the iOS 26.2 SDK, with no errors and no warnings beyond the availability warnings the other Metal sources already give. Not run on a device.
- Cost per frame on an iPhone 4S (an estimate from the byte counts, not a measurement): a full-screen 960 by 640 BGRA surface is 2.46 MB. A refreshed layer adds one copy of that into the `CFData` and one read by Core Animation when it uploads the image, so about 5 to 7 MB of memory traffic per refreshed full-screen layer per commit, on top of the readback in C50. An unchanged layer adds only the seed read. The time is not estimated here: it depends on the A5's memory bandwidth, which has not been measured.
- Removed by: none for iOS 6. A Core Animation that shows an IOSurface from CPU memory would make the swizzle and the copy unnecessary; this is not known for iOS 6 and has not been checked.

### C52. AVPlayer volume and mute are a per-item gain, kept in place by swizzled player methods

- Stands in for: the player-level gain of iOS 7's `AVPlayer.volume` and `isMuted`. The iOS 6 player has only the private `_setVolume:`, which moves the volume of the whole device. `frameworks/Backports/src/AVFoundation/AVPlayerVolume7.m` stores the state on the player and applies it as the private `AVPlayerItem.volumeAdjustment` (the `kFigPlaybackItemProperty_Volume` of the item's playback item) of each item the player holds, and `+load` replaces `replaceCurrentItemWithPlayerItem:` on `AVPlayer` and `insertItem:afterItem:`, `removeItem:`, `removeAllItems` and `advanceToNextItem` on `AVQueuePlayer` with blocks that call the original and then re-apply or release the gain.
- Why the replaced methods cannot be avoided (checked in the shared caches of 6.0 and 6.1.3, reasoned for the rest): the FigPlayer properties of the system hold a user volume, a user mute and a full mute (the device's), and a volume only on a playback item, so there is no player-level gain to set; the player does not tell an item that it joined it, so the gain has to be set where the app attaches the item. Observing `currentItem` would set it after a queue player has made the item current, which can sound the first buffers at full gain, and an observer of a player needs a hook at its `dealloc` or the observation outlives it.
- Widens: while the volume is below 1 or the player is muted, every item of the player carries a changed `volumeAdjustment`; an app that reads that private value sees ours, and one that sets it afterwards is overwritten at the next application. The app's `audioMix` is not touched. An audio tap of the app sees the sound before the gain (measured: the tap's level did not change with the gain).
- Measurement: iPhone 4S, iOS 6.1.3, 2026-11-09, `PlayerSignalProbe` (`tests/device_probe/player_signal_main.m`): a 1 kHz tone played through the speaker (output volume 0.401) and read with `AVAudioRecorder` metering on the phone's own microphone, ambient -45 dB. The microphone path compresses (a gain of 0.25 reads 4 to 5 dB below full, not 12), so the levels order the cases and compare two mechanisms, they are not a calibrated gain. The backport's `volume` 1, 0.5, 0.25 read -5.2, -6.9 and -10.0 dB; `muted` -38.7 dB and 0.5 with `muted` -41.0 dB; a change during playback took effect within the 0.15 s that the probe waits (1 to 0.25 to muted to 1: -6.2, -10.4, -27.9, -3.3 dB); a queue player given a volume of 0.25 and then a second item plays the first at -10.2 and the second at -10.0 dB. The same probe compares the gain with the earlier audio-mix mechanism at 0.75, 0.5, 0.25 and 0.1: -6.2 and -6.2, -6.9 and -6.6, -10.1 and -10.0, -15.1 and -14.8 dB, both 0 read the ambient level, a gain of 2 reads 1.9 dB above full, and an audio mix of 0.5 with a gain of 0.5 reads -10.8 dB, which is the product. `tests/AVFoundation/player_volume_test.m`: 14 of 14 on the host (and its `--negative` run fails) and on the phone (target `PlayerVolumeTest`); the test reads the gain the items carry, the probe measures the sound.
- Removed by: none for iOS 6: a player-level gain, or a notification that an item joined a player, neither of which the 6.0 and 6.1.3 inventories show.

### C53. AVAssetTrack.minFrameDuration is the shortest sample duration, read from one pass over the track

- Stands in for: the stored minimum frame duration of an iOS 7 track. `frameworks/Backports/src/AVFoundation/AVAssetTrackFrameDuration7.m` reads every sample of the track once with a passthrough `AVAssetReader`, keeps the shortest positive duration and caches it on the track.
- A composition track (`AVCompositionTrack`, which the SDK redeclares for Swift, so it needs its own implementation) takes the shortest frame of the source tracks of its non-empty segments, each scaled by the segment's time mapping; that answer is not cached.
- Gaps: the first call on a track costs a pass over its samples, on the thread that asks (measured below: 0.3 to 0.9 s for a 30 s clip on the A5, growing with the bytes of the track); a track that cannot be read (no asset, reader failure) gives `kCMTimeInvalid`; a composition track costs one pass per distinct source track on every call.
- Why a pass is still needed (measured on 6.0 and 6.1.3, 2026-11-09, by `strings` on the dyld shared caches and by `RuntimeSurveyProbe` on the phone): the FigTrack, FigAssetReader and FigPlayer property lists of both versions hold no stored minimum frame duration (they have the nominal frame rate, the natural size, the time ranges and the format descriptions only); the sample cursor (`FigSampleCursor`) that a track keeps inside the media server is not an exported symbol and no AVFoundation class on the device holds one (`AVAssetReader` holds only a `FigAssetReader`); `-[AVAssetTrack samplePresentationTimeForTrackTime:]` exists on 6.1.3 but does not find samples: `FrameDurationProbe` called it at 0, 1, 5, 19, 20, 21, 39, 40 and 41 sixhundredths of a second on a clip whose frames start every 20 and it returned each time it was given unchanged (measured; reasoned: it maps a track time through the track's edit list, which is the identity for an unedited track), so it gives no sample boundary to step along, and it costs about 300 microseconds a call besides; a stored frame rate would also be a different answer (the nominal rate is the average, the shortest frame is the extreme).
- A track counts as visual when its media type is video or it has the visual characteristic: on the iPhone 4S a composition video track answers NO to `hasMediaCharacteristic:AVMediaCharacteristicVisual`, because it carries no format description, while its media type is video (the first device run of the composition checks failed on it with an invalid time).
- Measurement: 9 of 9 checks of `tests/AVFoundation/track_frame_duration_test.m` on the host and on an iPhone 4S (iOS 6.1.3, 2026-11-08), on a 320 by 240 clip with unequal frame durations, played by a composition track, with an empty segment, stretched to twice its length, and as an audio track. The pass is timed in the next item.
- Pass time: iPhone 4S, iOS 6.1.3, 2026-11-09, `FrameDurationProbe` (`tests/device_probe/frame_duration_main.m`), a 30 s clip of 900 frames at 480 by 360 written on the phone at three bit rates, the whole `minFrameDuration` call timed after the track is loaded: 0.29 s for 0.7 MB of samples, 0.57 s for 14.3 MB and 0.88 s for 42.9 MB; the same clips took 0.34, 0.61 and 1.04 s before the output was given `alwaysCopiesSampleData = NO`, which stopped the reader copying each compressed sample (about 15 percent). The time follows the bytes of the track more than the frame count. A clip of several minutes would take seconds; that was reasoned from the three points, not measured. Test: `TrackFrameDurationTest` 9 of 9 on the phone.
- Removed by: none for iOS 6; the system does not store the value, and no cheaper route exists (`samplePresentationTimeForTrackTime:` does not find samples).

### C54. CIContext render into a Metal texture draws through the GL framebuffer except with no colour space under the default working space, and draws nothing into RGBA32F

- Stands in for: `-[CIContext render:toMTLTexture:commandBuffer:bounds:colorSpace:]` (with `+[CIContext contextWithMTLDevice:options:]` and `-[CIImage initWithMTLTexture:options:]`) on the GL-backed Metal backport. `frameworks/Backports/src/Graphics/CIContextMetal9.m` binds the framebuffer of the texture, clears the covered part to transparent and calls `drawImage:inRect:fromRect:` on a context whose output colour space is the call's colour space (made once per colour space from the options the app gave and kept on the context). No copy through memory, no CPU pixel work.
- Open part 1, the memory route: a call with no colour space (`NULL`) on a context that was made without `kCIContextWorkingColorSpace` keeps the old route, `render:toBitmap:colorSpace:NULL` and `replaceRegion:` (a copy of the frame through memory, 8.9 ms at 512 by 384 and 27.3 ms at 1024 by 768 on the A5, against 1.8 and 5.7 ms drawn). Why `drawImage:` cannot do it (measured, iPhone 4S, iOS 6.1.3, 2026-11-09): with the default working space, a context whose output is `NSNull` converts to device RGB exactly like one with the default output (a 4 by 4 image: `db 00 bd` where the memory route with no colour space gives `b4 00 82`, a difference of 73), and the default working space cannot be named to set the output equal to it (`CGColorSpaceCreateWithName` gives NULL for `kCGColorSpaceGenericRGBLinear`, `kCGColorSpaceSRGB` and `kCGColorSpaceLinearSRGB` on the device; generic RGB gives 73 again). With a working space of `NSNull` or a given colour space the draw equals the memory route, so those take the framebuffer.
- Open part 2, RGBA32F: a render into an `MTLPixelFormatRGBA32Float` texture draws nothing, because the GPU has no framebuffer for it (`glCheckFramebufferStatus` 0x8cdd on the A5) and iOS 6.1.3 does not export `kCIFormatRGBAf` (`RuntimeSurveyProbe symbols` says absent; RGBAh, RGBA8, BGRA8 and ARGB8 are present), so the bitmap route has no format either. The code before this change read the missing constant and crashed (a segmentation fault in `CIMetalProbe`, measured); it now returns. Earlier docs listed RGBA32F as a working render target; that was never run on a device, and on the device the call crashed.
- Other differences kept: only the backport's own device and 2D textures work (the system has no other); the `commandBuffer` argument is not used because the backport's encoders and the draw both issue GL commands at once on the same context, so a render is ordered with the passes before and after it, and nothing remains for a `commit` to wait for. The first render with a colour space makes a `CIContext` (the time of that was not measured). The GL state restored afterwards is the framebuffer binding, viewport, scissor box and enable, clear colour and colour mask; other state that `drawImage:` changes is not restored (a Metal pass sets its own).
- Measurement: iPhone 4S, iOS 6.1.3, 2026-11-09, `CIMetalProbe` (`tests/device_probe/ci_metal_main.m`) 19 of 19, the `--negative` run fails 17. The values equal CoreImage's own memory render (largest difference 0 on a 256-level ramp) for three working spaces (none, generic RGB, default) with three colour spaces in the call (none, device RGB, generic RGB), eight of the nine through the framebuffer; a draw replaces what the texture held, as the memory route does (without the clear, a translucent image blended onto 0x77 differed by 119); a stale GL state (scissor of one pixel, colour mask, blend, depth, stencil and cull enabled) before the draw changed nothing (largest difference 0); a software-renderer context draws the same rows; no GL error is raised and the CoreImage render leaves the sampled texture's filter and wrap parameters as they were. Not measured: a Metal pass of the backport reading the texture after such a render (the probe reads it with `getBytes:`), and MediaEditor's own frames.
- Found, not caused by this change: a Metal texture of 4 by 2 or 8 by 2 texels does not read back what `replaceRegion:` wrote, while 4 by 4 and 2 by 2 do; the cause (texture backport or driver) is not diagnosed.
- Removed by: a way to make `drawImage:` write working-space values (a named linear colour space, or an output of none that CoreImage honours under a default working space), or a Metal texture that CoreImage reads and writes directly; iOS 6 offers neither.

### C56. The iOS 6 NSURL escapes what macOS keeps in a host or port, and does not split a fragment off a URL without an authority

- Stands in for: the `NSURL` of iOS 17 and later holding a URL string as written. `NSURL+Encoding17.m` (`URLWithString:encodingInvalidCharacters:`) and `revenant_url_reference` (what the markdown backport uses for link destinations: the initialiser with a base URL) pass the string the parser wrote to `CFURLCreateWithBytes`, the one system call that accepts raw characters (`+[NSURL URLWithString:]` returns nil for a space, `CFURLCreateWithString` too), and the iOS 6 CFURL escapes some of them.
- Gaps, both measured on an iPhone 4S, iOS 6.1.3, 2026-11-09, with `UrlHoldProbe` (`tests/device_probe/url_hold_main.m`): (1) a space, `|`, `[`, `]` or a lone `%` in a host or port, which macOS keeps in `absoluteString` (a no-break space or U+3000 in an `http` host becomes a space there), shows as `%20`, `%7C`, `%5B`, `%5D` or `%25` on the device; `host` returns the decoded text on both (`a b`). (2) A URL with a scheme and no `//` (`a:b#f`, `mailto:a@b.c#f`, `a:b?x#f`): the device holds the `#` as `%23`, `fragment` is nil and `resourceSpecifier` carries it, where macOS has the fragment; plain `+[NSURL URLWithString:]` of the system does the same, so this is the system's rule for such a URL, not a result of the backport. A relative reference that macOS resolves (`-a:b`, `+a:b`, `.mailto:a@b.c`, `1a:b`) is resolved with a `./` in front, so its `relativeString` is `./-a:b` where macOS has `-a:b`; the absolute string is the same.
- Measurement: `UrlDumpProbe` on the 705 corpus lines: 705 identical URL strings. On 4000 generated lines: 3920 identical, 80 equal after decoding the escapes, 0 of any other kind. `MarkdownDumpProbe` on `tests/device_probe/markdown_url_corpus.txt` (the output is kept in `markdown_url_dump.device`): 36 of the 279 lines differ from the host's `markdown_url_dump.expected`, 12 strings in the three syntaxes, every one a space in a host that the device shows as `%20`; the text, the ranges and the presence of every link agree with the host. Before the markdown backport used the new `NSURL` form the same run differed on 87 lines (links made with `%C2%A0` instead of the host's host, no link where the host has one, and punycode missing).
- Considered and not done: an `NSURL` subclass that keeps the written string and returns it from `absoluteString`. `UrlHoldProbe` shows the Objective-C accessors of such a subclass answer with the raw text and that an attribute keeps the subclass, but `CFURLGetString` and `CFURLCopyHostName` on the same object read the escaped base copy, so one URL would have two answers; the subclass would also have to carry the rest of `NSURL` (path methods, equality, bridging). It was not built.
- Removed by: an iOS 6 `CFURL` that keeps these characters, which the system does not offer.

## Removed
### C55. encodingInvalidCharacters: escaped by one character set outside the host, and NSURL followed NSURLComponents

- Was: `NSURLComponents+Encoding17.m` found the host of the string, escaped everything outside it with one character set and left the host to the components parser; `NSURL+Encoding17.m` parsed the string of the components. The `NSURL` form differed from macOS on 14 lines of the corpus (`1http://x/`, `1a:b`, `a_b:c`, three lines with a second colon in the user information, eight with a stray percent sign), and a generated run was never made.
- Measurement that removed it: macOS's `NSURLComponents` is the RFC 3986 parser of swift-foundation (`RFC3986Parser.parse` with the per-component allowed masks, and `compatibilityParse` for `encodingInvalidCharacters:NO`), and macOS's `NSURL` `encodingInvalidCharacters:` is a different algorithm over the same masks, so the two forms were fitted separately against macOS. `tests/url_components_oracle_test.lua` compares both forms with macOS on the 705 corpus lines and on 60000 generated lines (three seeds of 20000 from `tests/url_components/fuzz.lua`: schemes with the host-encoding list and a mixed-case `AddressBook`, ports with letters, percent escapes and non-ASCII, IP literals, zone IDs, userinfo with colons, empty and doubled delimiters): 0 differences in either form; its negative control (every line changed) differs on 672 and 675.
- Measurement on the device: iPhone 4S, iOS 6.1.3, 2026-11-09, `UrlDumpProbe` built from the same sources against the macOS output: the 705 corpus lines give 0 differences in the components and 0 in the URL form; 4000 generated lines give 0 differences in the components, 3920 identical URL strings and 80 that are equal once the percent escapes are decoded, none of any other kind. Those 80 are what the iOS 6 `NSURL` does to the string it is given, and are open as C56. ICU's UTS 46 (`uidna_nameToASCII` and `uidna_nameToUnicode` in `/usr/lib/libicucore.dylib`, found with `dlopen` and `dlsym`) is present on iOS 6.1.3 and gives the macOS results, so the host conversion is ICU's, not a copy of the punycode and mapping tables.
- Removed in: this change. `RevenantURLParser.m` carries the parser (the standard parse, the compatibility parse, the masks, the port rules, the IDNA host conversion through ICU and the NSURL layer); `NSURLComponents.m` keeps the string the parser accepted and returns it from `string` until a setter changes the components.

### C1. Member list generated from a stand-in SDK install

- Was: the member and device lists were generated from the `iphoneos-sdk 26.2` install `…/14632581444d4c67a8eee6a6172f4e0a` through `REVENANT_GEN_SDK`, while CI resolves `…/d322b52c69944e4a9c3f3d2a883a9259`.
- Measurement that removed it: with the same code, the two installs give identical member and device lists (0 changed lines). The 26 lines that differed came from a stale committed list after the deprecation rule changed, not from the installs.
- Removed in: `77cf0704e` (list regenerated from `d322…`, the package CI resolves).

### C5. Device check skipped on CI

- Was: `device_members_test` skipped on CI, because the checks job did not restore the iOS 6.0 armv7 shared cache that holds the inventory.
- Removed in: `e01213a11` (the checks job restores the cache with the key the other jobs use, fetches it on a miss, and asserts the inventory is in place), and `75413488d` (the cache restore lacks `classes_armv7.json`, so the job writes it with the firmware `classes` action when absent).
