# AVAudioUnitDistortion: preGain, wetDryMix and the factory presets

Carried in `AVFAudio/AVAudioUnitSubclasses8.m`, with the preset table in `AVFAudio/CharonDistortionPresets.h`.
Checked by `tests/backports/host/avfaudio/distortion.sh` (`distortion.m`): the host's unit is read back parameter
by parameter, and the port's table and apply are run on a second host unit and held to it.

## The unit's parameters are the SDK's, at the ids the host uses

The release's distortion unit (`kAudioUnitSubType_Distortion`) has sixteen parameters, ids 0-15, in
`AudioToolbox/AudioUnitParameters.h`: `kDistortionParam_Delay` 0, `_Decay` 1, `_DelayMix` 2, `_Decimation` 3,
`_Rounding` 4, `_DecimationMix` 5, `_LinearTerm` 6, `_SquaredTerm` 7, `_CubicTerm` 8, `_PolynomialMix` 9,
`_RingModFreq1` 10, `_RingModFreq2` 11, `_RingModBalance` 12, `_RingModMix` 13, `_SoftClipGain` 14 and
`_FinalMix` 15.

The SDK's `preGain` is `kDistortionParam_SoftClipGain` (14) and its `wetDryMix` is `kDistortionParam_FinalMix`
(15). The host sets `preGain` and `wetDryMix` and reads the same two ids back (distortion.m, last check). An
earlier version of this file said the release had neither; that was wrong, and the two members were inert for
no reason.

## Factory presets are the sixteen parameters

The host's `loadFactoryPreset:` for presets 0-21 (`AVAudioUnitDistortionPreset`, in the SDK's order) leaves all
sixteen parameters at one row of a table, and the table was read back from the host unit after each preset.
`CharonDistortionPresets.h` is that table: row = preset, column = parameter id. A fresh unit holds row 0. A preset
outside 0-21 changes nothing, on the host and in the port (checked).

## The host's properties do not follow a preset

After `loadFactoryPreset:` the parameters 14 and 15 take the preset's values, but the object's `preGain` and
`wetDryMix` properties keep the values the object held (measured: presets 1-21 leave them at the row-0 values
-0.9 and 44.6). The port's object does the same: it holds `preGain` and `wetDryMix`, sends them to the unit when
they are set, and does not change them on a preset. Its `loadFactoryPreset:` is the table's sixteen values.

## Reverb: loadFactoryPreset: is owed

`AVAudioUnitReverb.loadFactoryPreset:` is declared by the SDK and is not implemented. On the host, the reverb's
presets change the v3 reverb parameters 8-16. The release's reverb unit carries `kReverb2Param_*` 0-7 only, and
those do not change with a preset on the host (measured), so there is no release parameter a preset could set.
The row is `owed` in `registry/AVFAudio/iosaudiounitsubclasses8.json`, and the selector is not answered.
The `preset` getter the earlier port had is not declared by the 26.2 SDK and is gone.
