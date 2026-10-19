# Manual rendering on the engine

`AVAudioEngine`'s manual-rendering surface, on the release's own audio units. Nine members in
`registry/AVFAudio/iosaudioenvironmentmixing9.json`:
`enableManualRenderingMode:format:maximumFrameCount:error:`, `disableManualRenderingMode`,
`renderOffline:toBuffer:error:`, `manualRenderingBlock`, `setManualRenderingBlock:`,
`manualRenderingMode`, `manualRenderingFormat`, `manualRenderingMaximumFrameCount` and
`manualRenderingSampleTime`.

## The output is a real unit either way; which one is the whole of the difference

In realtime the engine's output is the release's `kAudioUnitSubType_RemoteIO` and an I/O thread drives
it. In manual rendering it is a `kAudioUnitSubType_GenericOutput`, which needs no mediaserverd and is
**never started** — the caller pulls it. `-enableManualRenderingMode:…` does that switch on the live
graph: it removes the current output node, adds a generic output, and re-connects the main mixer,
which is the one connection the engine makes to its output in `-init`. So an application gets manual
rendering by calling the header's method, not by setting a flag before `-init`; the class-level
`CharonOfflineOutput` flag that the port's test support uses is still there for that older path, and
this one does not need it.

Both scopes of `kAudioUnitProperty_StreamFormat` are set on the new output, and it is worth saying
why: `AudioUnitRender` formats `ioData` by the **Output** scope, so a unit with only its Input scope
set fails the first pull with `-50` (paramErr). That was measured on this port's own engine before
this family existed — `facts/AVFoundation/AVAudioEngine.md` records it — and it is why the new output
gets the format the mixer is already carrying, asked of the mixer rather than kept a second copy of.

## `renderOffline:toBuffer:error:`

The release's own `AudioUnitRender` on that unit, at the caller's frame count, with the sample time
advanced by what was rendered. Nothing is started: a generic output has no I/O thread to start, and
`AUGraphStart` on it would be the call the offline test support already found returns `-50` on every
pull afterwards.

With a `manualRenderingBlock` set, the caller's block does the rendering, in the header's own shape:
`(frameCount, outBuffer, outError)` returning an `AVAudioEngineManualRenderingStatus` — **not** the
four-argument `AURenderBlock` shape, which is a different typedef for a different class. The block is
copied into the caller's thread and called from the caller's pull; the engine's own pull is not used
while one is set.

## The three types, and why they are transcribed

`AVAudioEngineManualRenderingStatus`, `AVAudioEngineManualRenderingMode` and
`AVAudioEngineManualRenderingBlock` are declared in `AVFoundation/CharonAVAudioEngineManual.h` rather
than imported, because `<AVFAudio/AVAudioEngine.h>` is reachable only through the umbrella and the
SDK's AVFAudio headers cannot be entered twice — `CharonAVAudioBuffer.h` has already imported
`<AVFAudio/AVAudioFormat.h>`, and the umbrella imports it again, giving `duplicate interface
definition for class 'AVAudioNode'`. They are spelled and valued exactly as `AVAudioEngine.h`
declares them (`:76-81`, `:83-86`, `:138`).

## What the host differential covers, and what it does not

`tests/backports/host/avfaudio/offline.m`, run from the same `run.sh` as the rest of the family,
compares the **arithmetic the port writes** against a real host 3D mixer and a real host engine:
the three distance laws (in range, falling with distance, three different curves), the mixer's
spherical source position surviving the round trip the listener transform performs, and an offline
pull through a host engine — which fills the frames asked for, is not silence and is not clipping,
and advances the sample time.

It does **not** run the port's armv7 code; comparing a *port* render sample for sample is the
emulator call test's job, and the file says so. The measured agreement is `peak 0.499998868` against
the 0.5 written in, tolerance 0.01, with three mutations shown to fail.
