# Audio.swift: deleted, and what brings it back

`files/RealityFoundation/Audio.swift` was 468 lines carrying five public types - `AudioResource`,
`AudioFileResource`, `AudioListener`, `AudioPlaybackController`, `AudioEngine` - and the enums and event types
inside them. It is **not in this package any more**, and neither are the three registry rows that named its
types (`AudioResource`, `AudioFileResource`, `AudioPlaybackController`, each `implemented` and each a
declaration-only row), nor the 21 checks of the host differential that measured it. A file that is shipped and
never built is dead code under the owner's directive.

What this page keeps is why the file is gone and what would put it back.

## The cause, measured

`Audio.swift` writes `AVAudioPlayerNode.volume` twice:

- `AudioPlaybackController.gain`'s setter, which turns decibels into a linear level
- `AudioEngine.__place(_:on:)`, which does the same from the listener's position

The port has no such property on that class, and the SDK marks the protocol that declares it as iOS 8.0.
So the sources are wrong for the release this runtime is built for, not the flags:

- Apple's `AVFAudio.framework/Headers/AVAudioMixing.h:80` declares
  `@property (nonatomic) float volume;` and the same file at line 45 marks the protocol
  `API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0))`. `AVAudioPlayerNode`'s own header
  declares the conformance (`@interface AVAudioPlayerNode : AVAudioNode <AVAudioMixing>`) and no volume.
- The port's headers leave that protocol alone because no registry row names it. The header they keep,
  `AVAudioMixing.h` in the port's copy, differs from the SDK's in five places -
  `AVAudio3DMixingRenderingAlgorithmAuto` lowered, the `AVAudio3DMixingRenderingAlgorithm` enum's own
  `NS_ENUM_AVAILABLE`, `AVAudioMixingDestination`'s class mark, `init` un-unavailable, and two members
  added to it - and the protocol's own mark is not one of them.
- The port's own player node has no volume either.
  `frameworks/Backports/src/AVFoundation/RevenantAVAudioEngine.h:73` declares exactly six members on
  `@interface AVAudioPlayerNode`: `scheduleBuffer:completionHandler:`,
  `scheduleBuffer:atTime:options:completionHandler:`, `play`, `pause`, `stop` and `isPlaying`. The
  registry row for the class (`the deleted registry package registry/AVFoundation/ios8avaudioengine.json`)
  carries those six as `implemented` at `6.0` and no volume, so nothing claims it and nothing builds it.
  (`AVAudioUnitMixing9.m` answers the same surface on `AVAudioUnit`, where each value is the mixer's own
  `k3DMixerParam_`; a player node is not that - `AVAudioPlayerNode.m:4` says it carries no AudioUnit of
  its own, it is a buffer queue read from a render callback.)

The compile, at `armv7-apple-ios6.1.3` over this tree, says it twice and names nothing else:

    Audio.swift:178:49: error: 'volume' is only available in iOS 8.0 or newer
    Audio.swift:419:16: error: 'volume' is only available in iOS 8.0 or newer

One probe per member, at `armv7-apple-ios6.1.3` with this build's own port headers
(`probe-members.sh`, `probe-members-lift.txt`), which is what says that this one property and not the
protocol as a whole is what the sources reach:

    volume               exit 1  error: 'volume' is only available in iOS 8.0 or newer
    rate                 exit 0  clean
    pan                  exit 1  error: 'pan' is only available in iOS 8.0 or newer
    reverbBlend          exit 0  clean
    obstruction          exit 0  clean
    occlusion            exit 0  clean

`Audio.swift` writes `volume` and reaches nothing else the release lacks: with its two writes of that
property taken out in a copy of the file, the other 17 files of the overlay compile at the port's release
with 0 errors and 50 warnings (`probe-audio.sh`, `probe-audio/compile.txt`).

## Why nothing was marked away instead

`AudioPlaybackController.gain` is the level the sound is heard at. Marking the setter `@available(iOS
8.0, *)` would leave `gain` readable and unwritable at 6.1.3, or would take the whole controller out of
the module, and either way a caller who sets it would hear the sound at its own level - a silent fake.
Guarding the two writes with `if #available(iOS 8.0, *)` is the same fake with more ceremony. Neither is
what this port ships, so the sound half is not built.

## What brings it back

A registry row and an implementation for `-[AVAudioPlayerNode volume]` in the Backports, at the level the
release's own mixer parameters already use (the `k3DMixerParam_` set `AVAudioUnitMixing9.m` asks of scope 0),
applied to the samples the node's render callback delivers, with a host differential and a device call test.
That is the Backports' work, over API it owns, and this package's overlay is the consumer of it.

Nothing in the file was wrong for a release that carries the property: the same sources at that release would
compile and behave, because `AVAudioMixing` is what declares the property and what marks it, and both are of the
SDK's own making. So the file can come back whole once the row lands, with its checks - and the three registry
rows with it.

The two `absent` rows that name audio - `Scene.__audioListener` and `Scene.__addPostProcessingAudioEffect(_:)` -
stay where they are: neither says anything about this file, and both are still absent for the reasons they give
(`an audio listener needs the spatial-audio environment this port has not (see the AVFAudio audit)`, and
`a post-processing audio effect is a renderer attachment`).