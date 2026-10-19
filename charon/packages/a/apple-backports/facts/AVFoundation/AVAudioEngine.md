# AVAudioEngine, AVAudioPlayerNode, AVAudioUnitEQ, AVAudioConverter - the node graph

**`AVAudioEngine`, `AVAudioPlayerNode` and `AVAudioUnitEQ` are built and measured: a real signal
passes through the graph, sample-for-sample, and a real `kAudioUnitSubType_NBandEQ` unit in that
graph measurably and predictably changes it.** `AVAudioConverter` is next (its C functions are
already confirmed present, below).

None of the four classes exist on iOS 6.0/6.1.3 (confirmed via `objc.inventory` against the real
armv7 shared cache before any code was written - no name collision the way `AVAudioBuffer` was,
see `facts/AVFoundation/AVFAudio.md`). What they sit on is real and complete, measured on-device,
not assumed from a header:

- Every AUGraph/AudioUnit/AudioConverterServices C entry point this port needs -
  `NewAUGraph`, `AUGraph{Open,Initialize,Start,Stop,AddNode,NodeInfo,ConnectNodeInput,
  DisconnectNodeInput,RemoveNode,Update,Close}`, `AudioComponent{FindNext,InstanceNew}`,
  `AudioUnit{SetProperty,GetProperty,Initialize,Render,AddRenderNotify}`,
  `AudioConverter{New,ConvertComplexBuffer,FillComplexBuffer,Get/SetProperty}` - resolves via
  `dlsym` in a running armv7 process on the 6.1.3 guest. A symbol resolving is not the same claim
  as a component being registered, so this was checked separately.
- The specific Audio Components this port's four classes need are each confirmed registered
  through `AudioComponentFindNext`, not just linkable: `kAudioUnitSubType_GenericOutput`
  (`auou`/`genr`/`appl`), `kAudioUnitSubType_RemoteIO` (`auou`/`rioc`/`appl`),
  `kAudioUnitSubType_NBandEQ` (`aufx`/`nbeq`/`appl`), `kAudioUnitSubType_MultiChannelMixer`
  (`aumx`/`mcmx`/`appl`) - all four found, `AudioComponentGetDescription` reading back the exact
  type/subtype/manufacturer requested, `OSStatus 0` throughout.

## The verification scheme this unlocks

The coordinator's standing warning for this cluster: a graph that compiles, runs and produces
silence reports nothing - no exception, no error code, a green gate. The only real proof is
reading the graph's actual output and comparing samples, the way `tests/backports/device/avfaudio.m`
already does for a bare buffer.

`AVAudioSession` needs a live `mediaserverd`, which the Shade emulator does not run at all
(measured: every `AVAudioSession` call there fails identically with `kAudioSessionNotInitialized`,
`'!ini'`, both as a bare daemon and as a real `.app` bundle - see
`facts/AVFoundation/AVAudioSessionCategoryModeOptions.md`). `kAudioUnitSubType_GenericOutput` does
not: it is Apple's own offline-rendering terminal, pulled by hand through `AudioUnitRender`, never
touching real hardware I/O or the audio daemon. A test graph terminated in `GenericOutput` -
`AVAudioPlayerNode` scheduling a known buffer, through real `AVAudioEngine` node/connection/format
plumbing, pulled and compared sample-for-sample at the far end - proves the actual graph mechanics
on the emulator, no device queue required for this part.

What this does **not** close, named up front rather than found out later: an application's real
`outputNode`/`mainMixerNode` runs through `RemoteIO`, not `GenericOutput`, and `RemoteIO` imposes
its own stream format - the hardware's own sample rate and channel layout - at the connection,
which a test graph built with formats of its own choosing never exercises. That is exactly where a
real device's graph tends to go silent instead of erroring. So the offline `GenericOutput` proof
covers the graph's own logic; a second, narrower measurement against a real `RemoteIO` output,
checking that the samples fed in are the samples that come out through actual hardware, still
needs a device and comes after this.

## What is built: `AVAudioEngine` and `AVAudioPlayerNode`

`AVAudioEngine` owns one real `AUGraph`, created in `-init`: a `kAudioUnitType_Output` node
(`kAudioUnitSubType_GenericOutput` in offline/test mode, `kAudioUnitSubType_RemoteIO` for a real
application - the switch is `CharonAudioEngineTestSupport`'s only job, never set outside a
device-probe) and a `kAudioUnitType_Mixer`/`kAudioUnitSubType_MultiChannelMixer` node, connected
mixer -> output before any application code runs - matching the real class's own default wiring.
`attachNode:`/`detachNode:`/`connect:to:format:`/`disconnectNodeOutput:`/`prepare`/
`startAndReturnError:`/`mainMixerNode`/`inputNode`/`outputConnectionPointsForNode:outputBus:`/
`autoShutdownEnabled` are all real, all registered (`registry/AVFoundation/ios8avaudioengine.json`).

`AVAudioPlayerNode` carries no `AudioUnit` of its own - there is no stock Apple component that
takes arbitrary `AVAudioPCMBuffer`s as input the way `scheduleBuffer:` needs. It is a buffer
queue (`CharonScheduledBuffer`), read frame-by-frame by a C render callback
(`CharonPlayerRenderCallback`, `AVAudioPlayerNode.m`) that `-connect:to:format:` wires directly
onto the destination node's real input bus through `AUGraphSetNodeInputCallback` - the callback
*is* the connection on that side, exactly the way a generator unit would be if this device shipped
one for this job. A raw byte copy moves samples from the scheduled buffer into `ioData`, correct
because `-connect:to:format:` has already forced the destination's format to match the source's -
same bytes-per-frame, same channel count, same (non-)interleaving, by the same rule the real class
documents.

**Two real bugs found and fixed while proving this, neither visible to `nm`/the build gate:**

- `AVAudioEngine`'s `-startAndReturnError:` originally always called `AUGraphStart`. On a
  `GenericOutput`-terminated graph this is wrong: `AUGraphStart` hands control to a hardware I/O
  thread that offline rendering, by definition, does not have. Measured directly: every setup
  call (`AUGraphOpen`/`AddNode`/`ConnectNodeInput`/`SetProperty`/`AUGraphInitialize`) returned
  `noErr`, and the *first* manual `AudioUnitRender` pull still failed with `-50` (`paramErr`) every
  time, only after `AUGraphStart` had run. `-startAndReturnError:`/`-pause`/`-stop` now skip
  `AUGraphStart`/`AUGraphStop` when the engine was constructed for offline output, mirroring how
  Apple's own real `AVAudioEngine` manual rendering mode (iOS 11+) never calls the live-device
  start path either.
- The output unit's own **Output**-scope stream format was never set - only its Input scope was
  (the scope the mixer feeds into). `AudioUnitRender` reads a unit's Output-scope ASBD to know how
  to lay out what it writes into `ioData`; without it, every setup call still returns `noErr` and
  only the render call itself fails with `-50`. Found by a standalone raw-`AUGraph` probe outside
  this class (`.agent-work/scratch/avaudio-build/raw-graph-probe.m`, not part of this port) that
  isolated the exact same eleven-call setup sequence with full status checking at every step -
  adding the missing `AudioUnitSetProperty(..., kAudioUnitScope_Output, ...)` call turned `-50`
  into an exact sample match on the very next run, before the fix was ported into
  `AVAudioEngine.m`'s real `-connect:to:fromBus:toBus:format:`.

**Measured, not assumed - `checks=13 failures=0`, `tests/backports/device/avfaudioengine.m`-style
probe** (currently `.agent-work/scratch/avaudio-build/engine-probe.m`, not yet promoted): attaches
a real `AVAudioPlayerNode`, connects it to the real `mainMixerNode`, schedules a 512-frame known
sine waveform, starts the engine, pulls the graph's real output by hand
(`AudioUnitRender` against the real `GenericOutput` unit, one call for the whole buffer - a
chunked pull with the `AudioTimeStamp` reset to sample time 0 on every call was tried first and
only matched for the first chunk, since the mixer tracks its own internal sample-time continuity
across calls), and compares every one of 512 samples against what was scheduled. Exact match, not
just non-zero - first eight of both: `+0.0000 +0.0250 +0.0499 +0.0747 +0.0993 +0.1237 +0.1478
+0.1714`, identical. Run against the fresh build twice, from a completely clean private package
cache both times, to rule out any stale-binary artifact.

A third symbol-visibility trap, found and fixed along the way, is recorded in
`AVFoundation/CharonAVAudioEngine.h` itself rather than here: this project deliberately hides every
symbol whose bare name starts with `charon_`/`Charon` from a dylib's exported table
(`modules/apple/backports.lua`'s `internal_symbol()`), and a brand-new such class needs to be
reached by runtime lookup (`NSClassFromString`/`objc_msgSend`) from a separate test binary, not
static linking - `CharonAudioEngineTestSupport`/`engine-probe.m` is the worked example.

## What is built: `AVAudioUnit` / `AVAudioUnitEffect` / `AVAudioUnitEQ`

`AVAudioUnit`/`AVAudioUnitEffect`/`AVAudioUnitEQ`/`AVAudioUnitEQFilterParameters` sit on the real
`kAudioUnitSubType_NBandEQ` component confirmed present above, not a stand-in. `AVAudioEngine`'s
`-attachNode:` now recognises any `AVAudioUnit` (`AVAudioUnitEQ` today, any future
`AVAudioUnitEffect` subclass the same way): it calls `AUGraphAddNode` with the node's own
`audioComponentDescription` on the already-open graph - the same "already open, so the component
instantiates immediately" fact `AVAudioEngine`'s own `-init` already relies on for its output/mixer
nodes - then hands the real `AudioUnit` back to the node. `-detachNode:` mirrors it with
`AUGraphRemoveNode`. `-connect:to:fromBus:toBus:format:` needed no change at all: an `AVAudioUnitEQ`
is just another real-`AudioUnit`-backed node to that method, exactly like the output/mixer nodes it
already wires.

A caller is free to configure `AVAudioUnitEQ`'s bands (`filterType`/`frequency`/`bandwidth`/`gain`/
`bypass`) and `globalGain` before the node is ever attached - matching real usage, and matching how
a real `AVAudioUnitEQ` is normally built and configured before `-attachNode:`. Every one of those
setters funnels through `-charon_setParameterID:bandIndex:value:`, which is a no-op until a real
`AudioUnit` exists; `-attachNode:` calls the base class hook `-charon_applyPendingParameters` right
after creating that real unit, which sets `kAUNBandEQProperty_NumberOfBands` (must happen before the
graph as a whole is initialized - it always does here, since `-prepare`/`AUGraphInitialize` only
runs later) and replays every kept parameter through the real `kAUNBandEQParam_*` IDs
(`AudioUnitParameters.h`) - one call per band per parameter, `paramID + bandIndex` per Apple's own
documented layout, `kAUNBandEQParam_GlobalGain` alone. `bypass` on `AVAudioUnitEffect` itself (the
whole-unit bypass, not a single band's) is `kAudioUnitProperty_BypassEffect` - a property every real
Apple effect unit is expected to honour, kept at the base class so any future effect subclass gets
it for free. A fresh `AVAudioUnitEQFilterParameters` defaults to `bypass = YES`, matching Apple's own
documented default (a fresh band does nothing until explicitly un-bypassed).

**Measured, not assumed - `checks=9 failures=0`, `tests/backports/device/avaudiouniteq.m`**,
run through `xmake emulate -d iPhone4,1 -r 6.1.3 run
/usr/libexec/charon-avaudiouniteq-test` (`pass ... in 0.1 guest s / 6.2 host s`, the same Shade offline
`GenericOutput` path `AVAudioEngine`'s own proof uses - no `mediaserverd`, no device queue for this
part): builds a `player -> AVAudioUnitEQ(2 bands) -> mainMixer -> (offline) output` graph, a 2 kHz
test tone scheduled through it, pulled by hand through `AudioUnitRender`. Two runs, same tone, only
the EQ's band configuration differs:

- band 0 `Parametric`, `gain = 0`, un-bypassed: real Apple peaking-filter coefficients collapse to
  an identity transfer function at 0 dB. Measured `max |output - source| = 0.000000` across all 512
  samples - bit-exact, not merely close, so the check written for "near-identity" (`< 0.01`) is
  actually the stronger claim, reported honestly rather than tightened after the fact.
- the same graph, band 1 added: real `LowPass` at 150 Hz against the 2 kHz tone, un-bypassed.
  Measured RMS: `source = 0.353003`, `zero-gain-band = 0.353003` (identical to source, confirming
  the first result independently), `150Hz-lowpass-on-2kHz-tone = 0.007011` - roughly a 50x drop,
  far past the `< half` bar the check demanded, the size and direction a 150 Hz cutoff against a
  2 kHz tone should produce.

This is the check the coordinator asked for, closed: a bypassed/0 dB band leaves the graph's real
output alone (bit-exact here, not just close), and a real, active band changes it in a large,
predictable, measured way - not a graph that compiles, runs, and produces silence or an unchecked
non-zero number.

One implementation bug the build itself caught before any of this ran: an early draft invented an
`active`/`isActive` property on `AVAudioUnitEQFilterParameters` that Apple's own real header
(SDK 16.4, `AVAudioUnitEQ.h`) does not declare - only `filterType`/`frequency`/`bandwidth`/`gain`/
`bypass` are real. Client-facing code compiles against the actual SDK framework headers, not this
port's own private `CharonAVAudioUnit.h`, so the mistake surfaced immediately as a hard compile
error in `eq-probe.m` ("property 'active' not found") the first time real client code tried to use
it - removed from the header, the implementation and the registry rather than worked around.

**This is a structural property of the test stand, not a one-off catch, and worth stating as a
standing fact: a device/emulator test built against the real SDK's own framework headers rejects a
fabricated member of this port's public API surface at compile time, before it ever reaches a
registry entry or a device** - one of this cluster's four fabricated-API-surface incidents this
shift, and the only one caught before it could reach a device at all.

## Not yet closed

- The narrower `RemoteIO`/hardware-format measurement named above (needs a device).
- `AVAudioConverter` - real work, not started; its `AudioConverterServices` C functions are already
  confirmed present, above.
- `AVAudioUnit.AUAudioUnit`/`+instantiateWithComponentDescription:options:completionHandler:` (the
  iOS 9+ async/`AUAudioUnit`-wrapping surface) - out of scope for a 6.1.3 minimum, not attempted.
- `-loadAudioUnitPresetAtURL:error:` honestly refuses (`kAudio_UnimplementedError`) - no application
  in the corpus needs a real `.aupreset` load yet.
- `AVAudioInputNode`'s real capture path (kept as a real object from construction, never exercised).
- Multi-input mixer topology (more than one `AVAudioPlayerNode` at once) - this pass wires one
  player and one effect node into the mixer, not several of either at once.
- `eq-probe.m`'s proof runs on the `GenericOutput` offline path only, same as `AVAudioEngine`'s own
  proof - the narrower `RemoteIO`/hardware-format measurement above covers this cluster too once a
  device is free.
