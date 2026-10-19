# AVAudioUnitSampler

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), in `AVAudioUnitSampler8.m`, over the
release's own sampler.

## The measurement, from the guest

`tests/backports/device/sampler-probe` on the emulated **iPhone2,1 6.1.3 (10B329)**, verbatim from
`run/run.log` and `run/guest.log`:

```
probe: AudioComponentCount = 55
probe: minimum = 6.1.3
MusicDevice/Sampler/Apple: found, name=Apple: AUSampler type=0x61656d75 subtype=0x73616d70 manufacturer=0x6170706c version=0x10000
'aumu'/'samp'/any: found, name=Apple: AUSampler type=0x61656d75 subtype=0x73616d70 manufacturer=0x6170706c version=0x10000
anyType/Sampler/any: found, name=Apple: AUSampler type=0x61656d75 subtype=0x73616d70 manufacturer=0x6170706c version=0x10000
...
component 48: type=0x61656d75 subtype=0x73616d70 manufacturer=0x6170706c name=Apple: AUSampler
component 49: type=0x61756d78 subtype=0x3364656d manufacturer=0x6170706c name=Apple: AU3DMixerEmbedded
...
pass on iPhone2,1 6.1.3 (10B329) in 0.3 guest s / 24.6 host s at time scale 10
```

**iOS 6.1.3 carries the Apple sampler**, as a registered audio component: type `'aumu'`, subtype
`'samp'`, manufacturer `'appl'`, version `0x10000`, named `Apple: AUSampler`, and it is entry 48 of the
55 the release registers. All three of the probe's queries agree, and the whole-list walk finds it
independently, so it is not one lookup's answer.

**The same run confirms the environment node's substrate**: component 49 is
`Apple: AU3DMixerEmbedded` — type `'xmud'`, subtype `'med3'` — which is what
`AVAudioEnvironmentNode8.m` is built on.

This corrects what the band reported twice before that a cache grep could not settle. A component is a
*registration* and not an exported symbol, so the absence of a `Sampler` symbol among the 580
libraries of the armv7 6.1.3 cache was never evidence about the sampler either way — as
`facts/AVFAudio/AVAudioUnitMIDI.md` says. The only answer is the release's own registry, and the guest
has now given it.

## What the class is built on

`AVAudioUnitSampler` derives from `AVAudioUnitMIDIInstrument` in the header
(`AVAudioUnitSampler.h:23`), which is why its initializer asks the generator family for a
`kAudioUnitType_MusicDevice` / `kAudioUnitSubType_Sampler` unit.

- **`loadSoundBankInstrumentAtURL:program:bankMSB:bankLSB:error:`** and
  **`loadInstrumentAtURL:error:`** are the release's own `kAUSamplerProperty_LoadInstrument`
  (`AudioUnitProperties.h:3636`, Scope Global, Value Type `AUSamplerInstrumentData`, Access Write;
  the id is `:3651`). That struct is the release's own layout: a `CFURLRef`, an `instrumentType`, a
  `bankMSB`, a `bankLSB` and a `presetID` — the five things the method takes. A sound bank is an SF2,
  so the instrument type is `kInstrumentType_SF2Preset`; the header's enumeration has no member
  called "SoundBank", and using one would have been a name the release does not have.
- **`loadAudioFilesAtURLs:error:`** is the release's second property,
  `kAUSamplerProperty_LoadAudioFiles` (`:3639`, Value Type `CFArrayRef`, Access Write; id `:3652`).
  One file is that array of one; an empty list is refused with an error rather than answered as a
  load of nothing.
- A refused load is reported with the status the release returned, never as a load that quietly did
  nothing.
- `masterGain` and `overallGain` are both the unit's `kAUSamplerParam_Gain` (900), in decibels, one to one. The
  host's own probe (`overallGain` set to -20, -7, -95 and 30, parameter 900 and `masterGain` read back after each)
  gives the same value from all three, unclamped: `overallGain` is the replacement the SDK names for `masterGain`
  (`API_DEPRECATED_WITH_REPLACEMENT`, iOS 15), so the two rows share the parameter.
- `globalTuning` and `stereoPan` are implemented over `kAUSamplerParam_CoarseTuning` (901) and `kAUSamplerParam_Pan`
  (903), as the table below says.
## What is not carried, and why

The note-control half of the header — `startNote:velocity:channel:`, `stopNote:channel:`, `reset` and
their kin — is **not** implemented here. Those are the sampler's instrument interface, and the
release's property set does not name one for them; the corpus carries no row for any of them on
`AVAudioUnitSampler` (its seven rows are the class, three load methods and four gain properties), so
nothing is claimed for them. A caller that sends one gets an unrecognised selector, which is what an
unimplemented member is, and the header's own contract for a caller — check `respondsToSelector:` —
still holds.

## Reuse

searched: none. This is a property write and a struct layout the release defines;
there is no sampler or synthesis to vendor, and Resonance Audio and Steam Audio (both Apache-2.0)
carry DSP the release's own unit already has.

## The host's own measurement of the three parameters, and the mapping

The release names the parameters — `kAUSamplerParam_Gain` 900, `kAUSamplerParam_CoarseTuning` 901,
`kAUSamplerParam_FineTuning` 902, `kAUSamplerParam_Pan` 903 — and gives **no range for any of them** in
`AudioUnitParameters.h`. So the range and the mapping are asked of the host's own
`AVAudioUnitSampler`, by `tests/backports/host/avfaudio/run-sampler.sh`, which reads
`kAudioUnitProperty_ParameterInfo` for each id (there is no `AudioUnitGetParameterInfo` on the SDK;
the range is that property with the parameter id as the element — the same path the port's parameter
tree walks) and then sets the AVFAudio property and reads the parameter back. Measured:

```
stage the host's sampler: unit 0xe9c680de
globalTuning     id 901  status 0  infoStatus 0  current 0  range -24 .. 24
fineTuning       id 902  status 0  infoStatus 0  current 0  range -99 .. 99
masterGain       id 900  status 0  infoStatus 0  current 0  range -96 .. 12
stereoPan        id 903  status 0  infoStatus 0  current 0  range -100 .. 100
stage globalTuning = 100 -> parameter 901 reads 1 (status 0)
stage globalTuning = -100 -> parameter 901 reads -1 (status 0)
stage masterGain = -6 -> parameter 900 reads -6 (status 0)
stage stereoPan = 0.5 -> parameter 903 reads 0.5 (status 0)
```

So the mapping the port has to reproduce, and the reason `globalTuning` is the *coarse* one:

| property | parameter | the parameter's range | AVFAudio's own range | the mapping |
| --- | --- | --- | --- | --- |
| `globalTuning` | 901 | −24 … 24 | −2400 … +2400 cents | **a factor of 100**: `parameter = cents / 100` |
| `masterGain` | 900 | −96 … 12 dB | — | **1:1** in decibels |
| `stereoPan` | 903 | −100 … 100 | — | **1:1** |
| `fineTuning` | 902 | −99 … 99 | — | the ±99 remainder the coarse one leaves |
