# AUAudioUnit, its busses, its presets and its parameter tree

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config). Eight classes, 109 registry entries.

## The C base is the release's own

iOS 6.1.3 has **no AudioUnit.framework**: the whole AudioUnit C API lives in AudioToolbox, and it is
there in full. Measured on the real armv7 shared cache with `dyld.load` — AudioToolbox exports these
and no more of the family:

- discovery: `AudioComponentCount`, `AudioComponentFindNext`, `AudioComponentGetDescription`,
  `AudioComponentCopyName`, `AudioComponentGetVersion`, `AudioComponentInstanceNew`,
  `AudioComponentInstanceDispose`, `AudioComponentInstanceCanDo`, `AudioComponentInstanceGetComponent`,
  `AudioComponentRegister`
- the unit: `AudioUnitGetProperty`, `AudioUnitSetProperty`, `AudioUnitGetPropertyInfo`,
  `AudioUnitGetParameter`, `AudioUnitSetParameter`, `AudioUnitScheduleParameters`, `AudioUnitRender`,
  `AudioUnitInitialize`, `AudioUnitUninitialize`, `AudioUnitReset`, `AudioUnitProcess`
- the graph: `NewAUGraph`, `DisposeAUGraph`, `AUGraphOpen/Close/AddNode/RemoveNode/NodeInfo/
  ConnectNodeInput/DisconnectNodeInput/SetNodeInputCallback/Initialize/Uninitialize/Start/Stop`

It exports **no `AUAudioUnit` C entry point** — `AUAudioUnitInitialize`, `AUAudioUnitRender` and
`AUAudioUnitGetClass` are all iOS 9's — and **no `AudioUnitGetParameterInfo`**, which is why the
parameter walk below is written the way it is.

So the unit is a **v2 `AudioUnit`**, made with `AudioComponentInstanceNew`, and the render block is
installed the way a v2 host of this release installed one: `kAudioUnitProperty_SetRenderCallback`
with the unit's own pointer as the refCon. That is the same mechanism, and the same
`AUGraphSetNodeInputCallback` path, the already-carried `AVAudioEngine`'s player node uses.

**The pull block is built once, in `-init`, and never again.** It is handed to the render block and
is the release's own `AudioUnitRender` on the bus the block names. It is built once because a render
callback runs on the release's real-time thread, where a block allocation is latency the unit does
not owe, and because the header says outright that "all realtime operations are implemented using
blocks to avoid ObjC method dispatching".

**Render observers** are called with `kAudioUnitRenderAction_PreRender` and `..._PostRender`, which
is how the header says an observer tells the two apart, and with the four arguments
`AURenderObserver` declares.

## The parameter tree is the unit's own list

`kAudioUnitProperty_ParameterInfo` read through `AudioUnitGetProperty`, with the parameter's index as
the element, stopping where the unit answers an error — the only way in, and the way a v2 host of that
release did it. `AudioUnitParameterInfo` is **not declared by SDK 26.2 at all** (its
`AudioUnitProperties.h` names the property and its value type and nothing else); the struct in
`CharonAUAudioUnit.h` is transcribed from SDK 15.6's `AudioUnitProperties.h:1622`, whose field order
is the ABI the release answers.

Two names that must be kept apart, and were not at first: the fixed 52-byte `name` in the struct is
the parameter's **identifier** — what a key path and a KVC key are made of — and its **index** in the
walk is the v2 parameter id, which is what an `AUParameterAddress` is made of. Both are now separate
members.

A value is read with `AudioUnitGetParameter` and written with `AudioUnitSetParameter`, so an
`AUParameter` changes what the unit renders and not only what a caller reads back. A value set with a
host time goes through `AudioUnitScheduleParameters` with `kParameterEvent_Immediate` and
`AUParameterEventType`'s three cases, and each of the three observer kinds is told of the change in
the event shape its own header defines: `AUParameterObserver` gets the address and value, a recording
observer gets `AURecordedParameterEvent`s, an automation observer gets `AUParameterAutomationEvent`s
with the touch and release cases a gesture produces.

## Where SDK 26.2 declares nothing, and the port invents no property id

Three members would need a property id that neither the build SDK nor the release names. Each is
answered from what the release can actually do, and each difference is written down here rather than
papered over:

- **`canProcessInPlace`** answers `NO`. `kAudioUnitProperty_CanProcessInPlace` is a v3 property; it is
  not declared by SDK 26.2 and iOS 6.1.3 exports no name for it. A v2 unit of this release answers
  nothing that says it can, and the base class does not process in place.
- **`shouldBypassEffect`** is kept and read back, and the unit is **not** told:
  `kAudioUnitProperty_BypassRealtimeRender` is likewise absent from the SDK and the release. A host
  that sets it before it is rendered sees it come back, which is the header's contract; the audio does
  not change.
- **`setCurrentPreset:`** keeps the preset and reads it back without telling the unit, because
  `kAudioUnitProperty_LoadPreset` is absent too. What the unit really does publish is
  `kAudioUnitProperty_PresentPreset`, and that is where `currentPreset` reads from when the host has
  not set one — a real factory-preset name, matched against the list `factoryPresets` returns.
- **`virtualMIDICableCount`** answers `0`: a v3 unit publishes the count and a v2 unit of this release
  has no such property. Zero is the count a unit with no virtual cable has.
- **`isRenderingOffline`** answers `NO`, and the reason is worth stating plainly: the header's answer
  depends on whether the *engine* is rendering offline, and the engine's state lives in the
  `AVAudioEngine` the host owns, not in the unit. This unit reports the one thing it can measure about
  itself. Wiring it to a real engine is the engine family's business, not this file's.
- **`supportedChannelLayoutTags`** answers the layout of the format the bus really carries, read back
  from `kAudioUnitProperty_StreamFormat` — the SDK declares no `kAudioUnitProperty_ChannelLayout`, so
  there is no other property to ask.

## What is not carried yet

Named here so the gap is visible rather than inferred. `AUAudioUnit`: `allParameterValues`,
`+instantiateWithComponentDescription:options:completionHandler:`, `scheduleMIDIEventBlock`,
`supportsMPE`, `channelMap` (10.0); `audioUnitShortName`, `MIDIOutputNames`, `providesUserInterface`,
`MIDIOutputEventBlock`, `musicalContextBlock`, `transportStateBlock`, `contextName` (11.0);
`fullStateForDocument` (12.0); `userPresets`, `saveUserPreset:`, `deleteUserPreset:`,
`presetStateFor:`, `supportsUserPresets` (13.0); `MIDIOutputEventListBlock`, `AudioUnitMIDIProtocol`,
`hostMIDIProtocol`, `scheduleMIDIEventListBlock` (15.0); `messageChannelFor:`, `migrateFromPlugin`
(16.0). `AUAudioUnitBus`: `shouldAllocateBuffer` (11.0). `AUParameterNode`: none besides the 10.0
automation observer, which is carried.

## Two traps in this code

- **An `@implementation` in a header is emitted by every source that imports it.** `CharonAUParameterImpl`
  was defined in `CharonAUAudioUnit.h` and the link failed with a duplicate
  `_OBJC_CLASS_$_CharonAUParameterImpl` (and one per ivar) for every object. The `@interface` stays in
  the header; the `@implementation` and its explicit `@synthesize` lines are in
  `CharonAVFAudioCommon.m`, once.
- **The build SDK is 16.4, not 26.2.** `build-gate.lua` resolves `charon@iphoneos-sdk` to 16.4 and every
  gate log line says `sdk=16.4`, so an API newer than that has no `@interface` at all and an
  `@implementation` written without one is a root class — `[super init]` becomes an error and
  `[Class alloc]` undeclared. That is exactly what the gate said:
  `error: 'AVAudioSessionCapability' cannot use 'super' because it is a root class`.
  `CharonAVFAudioNew.h` declares the three such classes (`AVAudioApplication` 17.0,
  `AVAudioSessionCapability` 26.0, `AVAudioSessionPortExtensionBluetoothMicrophone` 26.0),
  transcribed from SDK 26.2 and checked absent in 16.4 first, so the day the build SDK moves past them
  the header can go away instead of shadowing the real declarations.

## Reuse

**searched: none, and here is what was looked for.** The work here is the glue to Apple's names over
audio units the release already has, so there is nothing to vendor: the queries were
`AVAudioUnit`, `AUParameterTree`, `AUAudioUnit` and `kAudioUnitProperty_ParameterInfo` on GitHub
repository search, and the permissive results are sample applications (MIT, single-digit to low-double-digit
stars) or a macOS-only Rust binding crate (Apache-2.0) — none re-implements Apple's classes, and all
call the same AudioUnit C API this library already calls. For the distance-attenuation maths, the
upstreams the brief names are **Resonance Audio** and **Steam Audio**, both Apache-2.0: nothing is taken
from either, because the three models the header defines are three closed forms and the mixer
already applies the result as its own gain. OpenAL Soft is LGPL and was not read.

## What the recording and automation observers are not told, and why

`tokenByAddingParameterRecordingObserver:` and `tokenByAddingParameterAutomationObserver:` register,
and an observer added to either is **not** called after a change on this release. They exist to report
what the *unit* did — a gesture it recognised, a touch and a release — and this release carries no
record of it. Measured on the build SDK's own `AudioUnitProperties.h`: the property set has
`kAudioUnitProperty_ParameterHistoryInfo` (id 53) and nothing else — **no**
`kAudioUnitProperty_ParameterHistory` and **no** `kAudioUnitProperty_ParameterValue`. The first says
how often a host *should* poll and how long it should keep what it polls; the thing it would poll is
not in this release. So there is nothing of the unit's to hand an observer.

An earlier version of this built an `AURecordedParameterEvent` and an `AUParameterAutomationEvent` in
the port and handed them over after a scheduled change. That was the port's echo of its own write
wearing the unit's name, and it is gone. What the value observers get is the value the unit **holds
after** the change, read back with `AudioUnitGetParameter` — a real read of the unit, which is what
`AUParameterObserver`'s own header asks for. The two record-shaped observers are silent here, and a
host that records a gesture on this release records nothing rather than being told the port's own
account of it.
