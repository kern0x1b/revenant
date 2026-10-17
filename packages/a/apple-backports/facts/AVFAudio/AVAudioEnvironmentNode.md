# AVAudioEnvironmentNode and its two parameter classes

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), in `AVAudioEnvironmentNode8.m`. The
base class `AVAudioNode` is carried in `libAVFoundationBackports.dylib`, which this library links.

## The unit is the release's own

`kAudioUnitSubType_SpatialMixer` — the SDK's name for `kAudioUnitSubType_AU3DMixerEmbedded`, the same
value, which the SDK deprecates only as a spelling. The evidence that the unit is really there is its
own parameter set in **the release's** `AudioToolbox/AudioUnitParameters.h`, marked iOS 2.0 and
thirty-odd entries long: `k3DMixerParam_Azimuth`, `_Elevation`, `_Distance`, `_Gain`, `_PlaybackRate`,
`_BusEnable`, `_MinGainInDecibels`, `_MaxGainInDecibels`, `_DryWetReverbBlend`,
`_GlobalReverbGainInDecibels`, `_OcclusionAttenuationInDecibels`,
`_ObstructionAttenuationInDecibels`, and the deprecated originals of each. A parameter set that size
only exists if the unit does.

The node carries a **graph of its own** — the mixer terminated into a `kAudioUnitSubType_GenericOutput`
— built with the release's own `NewAUGraph` / `AUGraphOpen` / `AUGraphAddNode` /
`AUGraphConnectNodeInput` / `AUGraphNodeInfo`, and initialized with `AUGraphInitialize` on the first
render rather than in `-init`, because a unit needs its formats first. It is there so the node can be
rendered offline with no engine at all, which is what makes its own output measurable.

## The coordinate model is the mixer's, not a translation of it

A bus's parameters are that source's azimuth, elevation, distance and gain **relative to a listener at
the mixer's origin**. `AVAudioEnvironmentNode` exposes the listener as a position, which is the same
statement read the other way round: moving the listener is the inverse transform applied to every
source. The port applies the former because that is the property the header exposes, and the
arithmetic is exact rather than fitted — a rigid transform and its inverse compose to the identity on
the positions the mixer is already given, and the listener's basis is orthonormal because its forward
vector is normalised and its up vector comes from the listener's own yaw and pitch.

## The only arithmetic the port does that the unit does not

The **distance attenuation model**. The header defines three laws — linear stops attenuating at
`maximumDistance`, exponential falls off by `rolloffFactor`, inverse is the reciprocal in units of
`referenceDistance` — and the mixer's own parameters for a source are a distance and a gain, so the
model is applied to the gain and the distance the unit is given. The unit still renders; the port only
decides the gain, which is exactly the parameter it has. The three laws are written out in
`-charon_gainForDistance:` from the header's own documentation, with the documented defaults (inverse
model, 1 m reference, 100000 m maximum, rolloff 1).

## What this unit cannot be

**The applicable rendering algorithms are the sound field and the stereo pass-through, and that is the
whole of what it is.** The mixer places a source in a sphere around the listener and sums the buses; it
has no head-related transfer function, and nothing in its thirty-odd parameters says where a listener's
ears are. So `AVAudio3DMixingRenderingAlgorithmHRTF`, `...HRTFHQ`, `...EqualPowerPanning` and
`...SphericalHead` are **not applicable** — they are absent from `applicableRenderingAlgorithms`, and
setting one leaves the unit where it is rather than quietly behaving like the sound field. The
algorithms that need an ear model need audio this device does not have, and saying so is the honest
answer, not a substitute.

## outputType and listenerHeadTrackingEnabled: implemented

- **`outputType`** is kept and read back, Auto by default. Auto is resolved against the route the release reports:
  `AudioSessionGetProperty(kAudioSessionProperty_AudioRoute)`, which is deprecated in the 16.4 and 26.2 SDKs and is
  present in the release. A wired route (`kAudioSessionOutputRoute_Headphones`, `_LineOut`, `_USBAudio`) resolves to
  headphones, the built-in speaker and receiver resolve to built-in speakers, and every other route to external
  speakers. The header's own rule is "wired output defaults to headphones". The resolved type goes to the mixer through
  `kAudioUnitProperty_SpatialMixerOutputType` (3100; 1 headphones, 2 built-in speakers, 3 external speakers, from the
  16.4 AudioUnitProperties.h). A refused set is recorded as inert.
  - Host, measured (macOS 27): the default is 0 (Auto), and each of 0 to 3 reads back as set. The host has no
    AudioSession, so the route read is not measured here.
  - Not measured, so not claimed: that the 6.1.3 mixer accepts the property (a refused set is inert, not an error);
    that the mixer renders differently for each type, since the port's algorithms are the sound field and the stereo
    pass-through and do not switch to `kSpatializationAlgorithm_UseOutputType` (7); a route change after the graph is
    initialized, which is not followed.
  - The route class `Receiver` resolves to built-in speakers: the header has no earpiece type, and the built-in
    hardware is the nearest answer. That is the port's choice, not a measurement.
  - Mapping and table: `AVFAudio/CharonEnvironmentOutput.h`, checked by `tests/backports/host/avfaudio/environment.sh`
    (`checks=environment-output failures=0`).
- **`listenerHeadTrackingEnabled`** (iOS 18) answers **NO** whatever is set; the value is not kept. This release's mixer has
  no head pose to take, and no motion sensor feeds one.
  - **Divergence, recorded:** the host keeps the value it is given. Measured on macOS 27: the default reads 0, YES
    reads 1, NO reads 0. The port answers NO after YES, which is the answer the 6.1.3 device can stand behind.

## The reverb filter band

`reverbParameters.filterParameters` is implemented (`CharonEnvironmentFilterParameters` in `AVFAudio/AVAudioEnvironmentNode8.m`,
with the defaults and the enable mapping in `AVFAudio/CharonEnvironmentFilter.h`). It is an `AVAudioUnitEQFilterParameters`, a band
of a filter. The host's band is not an `AVAudioUnitEQ` band's defaults: the port's band subclass takes the environment as its owner, and
the environment writes the band to the mixer's reverb filter, the SpatialMixer's parameters 14 to 18. Measured on the host, on the
environment node's own parameter tree (`tests/backports/host/avfaudio/environment.m` checks each of these, and a mutation of one
expected value fails):

- the band's defaults: frequency 800, bandwidth 3, gain 0, type parametric (0), not bypassed; the mixer's at the default: 14 800,
  15 3, 16 0, 17 0, 18 1 (enable is the bypass inverted);
- writing the band lands in those ids: frequency to 14, bandwidth to 15, gain to 16, the filter type to 17 (identity for every
  value 0 to 7), bypass YES to 18 = 0 and bypass NO to 18 = 1;
- the band keeps the value it was given (frequency 20000, bandwidth 5, gain 24 read back), and the mixer clamps it: frequency to
  10 to 10000 Hz, bandwidth to 0.05 to 4, gain to plus or minus 18 dB. The port writes the value raw and the mixer clamps it.

**Not measured:** whether the filter also acts on the dry output. The graph does not need an NBandEQ unit inserted to carry it; the
host does not insert one. The port's offline render through the filter is not compared to the host's render.

## Owed, not answered

These rows are `owed` in the registry. Each has its measured reason in `registry/AVFAudio/`.

- **`reverbParameters.loadFactoryReverbPreset:`**. Measured on the host, with the full state of each preset (`dump` of
  `AVAudioUnitReverb.AUAudioUnit.fullState` for presets 0 to 12, and of the environment's `AUAudioUnit.fullState` for
  `loadFactoryReverbPreset:` 0 to 12):
  - the presets leave every global parameter of the environment's mixer unchanged (the reverb gain, the reverb filter and the
    tree's global set), and the reverb object's `enable` and `level` read 0 after each;
  - the environment's full state carries the preset's index at `GlobalProperties` key 10 (0 to 12, one for each preset) and changes
    nothing else; the reverb's full state carries the preset's name (`Small Room` ... `Large Hall 2`, 13 names) and a 148-byte `data`
    blob that is identical for every preset.
  - So the presets' values are not observable from the state, the parameters or the tree, and there is no table of values to map onto
    `k3DMixerParam_GlobalReverbGainInDecibels` or the filter. The port keeps no preset index either, since nothing it could do with
    the index would be measured. Owed with that reason.

## Not yet measured here

The environment node's own offline pull — `-charon_renderOfflineToBuffer:frames:`, the release's
`AudioUnitRender` on its real generic output — is the hook the manual-rendering differential in
`AVAudioEngine.m` uses. The sample-by-sample comparison against macOS is the next piece of work and is
not in this delivery.
