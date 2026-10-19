# The AVAudioUnit effect subclasses of iOS 8

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), in `AVAudioUnitSubclasses8.m`. The
base classes — `AVAudioUnit`, `AVAudioUnitEffect`, `AVAudioNode`, `AVAudioEngine` — are carried in
`libAVFoundationBackports.dylib`, which this library links; none of their files is edited here.

## What each of these is

A **description of one of the release's own built-in units** plus **a set of the release's own
parameters**. Every subtype and every parameter id is out of `AudioUnitParameters.h` of the release:

| class | subtype | parameters |
| --- | --- | --- |
| `AVAudioUnitDelay` | `kAudioUnitSubType_Delay` | `kDelayParam_DelayTime`, `kDelayParam_Feedback`, `kDelayParam_LopassCutoff`, `kDelayParam_WetDryMix` |
| `AVAudioUnitVarispeed` | `kAudioUnitSubType_Varispeed` | `kVarispeedParam_PlaybackRate` |
| `AVAudioUnitTimePitch` | `kAudioUnitSubType_TimePitch` | `kTimePitchParam_Rate`, `kTimePitchParam_Pitch`, `kTimePitchParam_EffectBlend` |
| `AVAudioUnitReverb` | iOS's own reverb | `kReverb2Param_DryWetMix` |

A value set is an `AudioUnitSetParameter` on the real unit, so it changes what the release's unit
renders. A value read is an `AudioUnitGetParameter`. A value set before the node is attached is kept
and applied when the real `AudioUnit` arrives, which is the base class's own
`-charon_applyPendingParameters` — the same arrangement `AVAudioUnitEQ` already uses.

**`AVAudioUnitReverb` uses `kReverb2Param_*`, not `kReverbParam_*`.** iOS's reverb unit is a different
unit from the desktop one and carries a different parameter set: `AudioUnitParameters.h` has the
desktop `kReverbParam_*` under one heading and `kReverb2Param_*` under "Parameters for the iOS reverb
unit". Only the second exists on a release of this port, and using the first would be a parameter
id the unit does not have.

## The distortion members, and the reverb preset

`preGain`, `wetDryMix` and `loadFactoryPreset:` of `AVAudioUnitDistortion` are implemented over the release's own
parameters 14, 15 and the sixteen-parameter preset table. `AVAudioUnitReverb.loadFactoryPreset:` is owed: on the host a
preset sets the unit's present preset but none of parameters 0 to 16, through either parameter path, so no table can be
read from it, and the release's own reverb unit is a different one (`kReverb2Param` 0 to 6). Both
are written up in `AVAudioUnitDistortion.md`, which replaces the earlier reasoning that said the release's
distortion unit had no such parameters.


## Where the other classes are

`AVAudioUnitMIDIInstrument` is in `AVAudioUnitMIDIInstrument8.m` and `AVAudioUnitSampler` in
`AVAudioUnitSampler8.m`; `AVAudioEnvironmentNode` and its two parameter classes are in `AVAudioEnvironmentNode8.m`.
Their facts are in `AVAudioUnitMIDI.md`, `AVAudioUnitSampler.md` and `AVAudioEnvironmentNode.md`.

An earlier version of this section said iOS 6.1.3 exports no function that sends a MIDI event to an audio unit,
and that the sampler component is absent. Both were wrong: AudioToolbox exports `MusicDeviceMIDIEvent`,
`MusicDeviceStartNote`, `MusicDeviceStopNote` and `MusicDeviceSysEx`, and the sampler is a registered `aumu`
component (`AVAudioUnitMIDI.md` and `AVAudioUnitSampler.md` have the measurements). `MusicDeviceMIDIEventList` is
not exported, which is why the list form is decoded to `MusicDeviceMIDIEvent`.

`AVAudioSourceNode`, `AVAudioSinkNode` and `AVAudioMixingDestination` are not covered by this file.
