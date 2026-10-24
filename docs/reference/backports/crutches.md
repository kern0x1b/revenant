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

### C6. Reduced check for the two weak classes in the lowering test

- Stands in for: a compile-time check of the members of `NSDateInterval` and `NSURLComponents`. Both classes keep their class-level guard by design (the guard table records them as weak imports), so the IMPLEMENTED probe refers to them through `id` receivers.
- Measurement: the rest of the probe still checks typed receivers and the lowered headers at armv7 iOS 6.0.
- Removed by: the export dependency for these classes (the Backports library that exports them, linked into the runtime); the probe then returns to typed receivers.

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
- Measurement: host readback of the send through `alcASAGetSource` (`audio_test.m`). Device: pending the runtime case (C16).
- Removed by: the runtime case reporting that `alcGetProcAddress` resolves the three procedures on 6.1.3.

### C16. The OpenAL device path, the audio session and streaming are not run on iOS 6.1.3

- Stands in for: the output path of AVAudioSession and AVAudioPlayer, which SceneKit uses on the device. The OpenAL device, the ExtAudioFile decode, source playback and stream playback run only on the macOS host.
- Gaps: no AVAudioSession category is set, so output follows the default session (mute switch, other audio). The image check shows the symbols exported on 6.1.3, including `ExtAudioFileSeek` for stream loops, but nothing has run on the device or the emulator. The runtime case `tests/runtime/cases/scenekit_audio.m` is built for the device and reaches the emulator, but the app stops in the probe of the missing-class case before any case runs (a null read in `libRevenantMissingProbe.dylib`, outside this change), so its results are not in yet.
- Measurement: host tests of the same paths (`audio_test.m`, `action_run_test.m`). Device: pending.
- Removed by: the runtime case passing on the emulator, and a run on a real iPhone 4S with the mute switch set and other audio playing.

### C17. SCNView adopts SCNSceneRenderer, and 21 of its 64 members raise

- Stands in for: the rest of SCNSceneRenderer on a GLES view. Telegram needs the protocol as a type and the delegate callbacks, which SCNView already gives; the other members are Metal, SpriteKit, ray picking, or GPU features the GLES renderer does not have.
- Gaps: `presentScene:withTransition:incomingPointOfView:completionHandler:`, `hitTest:options:`, `isNodeInsideFrustum:withPointOfView:`, `nodesInsideFrustumWithPointOfView:`, `prepareObject:shouldAbortBlock:`, `prepareObjects:withCompletionHandler:`, and the properties `loops`, `autoenablesDefaultLighting`, `temporalAntialiasingEnabled`, `showsStatistics`, `debugOptions`, `overlaySKScene`, `usesReverseZ`, `workingColorSpace`, `currentRenderPassDescriptor`, `colorPixelFormat`, `depthPixelFormat`, `stencilPixelFormat`, `audioEnvironmentNode` and `currentViewport`. Each raises `NSInternalInconsistencyException` naming the member, so a call is loud and `respondsToSelector:` answers yes.
- Measurement: the members test (`lowered_members_test.lua`) passes with the list regenerated; the library compiles against the armv7 iOS 6.0 SDK with no diagnostics for the stubs. The stubs are not run by any test.
- Removed by: a native implementation of each member on the GLES renderer, or a decision to drop the adoption and the stubs.

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

## Removed

### C1. Member list generated from a stand-in SDK install

- Was: the member and device lists were generated from the `iphoneos-sdk 26.2` install `…/14632581444d4c67a8eee6a6172f4e0a` through `REVENANT_GEN_SDK`, while CI resolves `…/d322b52c69944e4a9c3f3d2a883a9259`.
- Measurement that removed it: with the same code, the two installs give identical member and device lists (0 changed lines). The 26 lines that differed came from a stale committed list after the deprecation rule changed, not from the installs.
- Removed in: `77cf0704e` (list regenerated from `d322…`, the package CI resolves).

### C5. Device check skipped on CI

- Was: `device_members_test` skipped on CI, because the checks job did not restore the iOS 6.0 armv7 shared cache that holds the inventory.
- Removed in: `e01213a11` (the checks job restores the cache with the key the other jobs use, fetches it on a miss, and asserts the inventory is in place), and `75413488d` (the cache restore lacks `classes_armv7.json`, so the job writes it with the firmware `classes` action when absent).
