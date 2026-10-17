# AudioToolbox's constants: two symbols defined, twenty-four enumerators declared

Carried in `libAVFAudioBackports.dylib`, with the registry in `registry/AVFAudio/iosaudiotoolboxconstants.json` (26 rows).

## The two notification names: symbols, defined

`kAudioComponentRegistrationsChangedNotification` (iOS 7) and `kAudioComponentInstanceInvalidationNotification` (iOS 9) are
exported `const CFStringRef` variables. The release does not export either (6.1.3 armv7 cache, `tools/image-exports.lua`).
The port defines both, in `AVFAudio/AudioComponentNotifications7.m` and `AVFAudio/AudioComponentNotifications9.m`, from the
strings in `AVFAudio/CharonAudioToolboxNames.h`:

- `com.apple.coreaudio.AudioComponentRegistrationsChanged`
- `com.apple.coreaudio.AudioComponentInstanceInvalidated`

The oracle is the host's own symbol. `tests/backports/host/audiotoolbox-constants/constants.m` compares each host string with the
header's, and `constants.sh` runs it (`checks=audiotoolbox-constants failures=0`). A change of one expected value fails
(`FAIL k3DMixerParam_BusEnable is 20 ...`, exit 1).

## The twenty-four enumerators: cases, declared by the SDK

Each one is an enumerator of an anonymous or named `enum` in the SDK's headers. Nothing exports an enumerator, so there is no
symbol to define: an application compiled against the SDK gets the value inline. The row's `kind` is `case`, and the port's
answer is the header the build reads, which declares it.

Their values and iOS availability, as the 26.2 declarations give them (`spec/AudioToolbox/declarations.tsv`):

| iOS | enumerators | values |
| --- | --- | --- |
| 9.0 | `kAudioQueueProperty_ChannelAssignments` | 1634820961 |
| 13.0 | `k3DMixerParam_BusEnable` 20, `_MinGainInDecibels` 21, `_MaxGainInDecibels` 22, `_DryWetReverbBlend` 23, `_GlobalReverbGainInDecibels` 24, `_OcclusionAttenuationInDecibels` 25, `_ObstructionAttenuationInDecibels` 26 | as listed |
| 15.0 | `kAUVoiceIOProperty_MutedSpeechActivityEventListener` | 2106 |
| 16.0 | `kAUSoundIsolationParam_WetDryMixPercent` 0, `_SoundToIsolate` 1, `kAUSoundIsolationSoundType_Voice` 1, `kAudioUnitSubType_AUSoundIsolation` 1987012979, `kAudioUnitType_SpeechSynthesizer` 1635087216 | as listed |
| 17.0 | `kAUVoiceIOProperty_OtherAudioDuckingConfiguration` | 2108 |
| 18.0 | `kAUSoundIsolationSoundType_HighQualityVoice` 0, `kAudioUnitProperty_SpatialMixerEnableHeadTracking` 3111, `_PersonalizedHRTFMode` 3113, `_AnyInputIsUsingPersonalizedHRTF` 3116 | as listed |
| 26.0 | `kAUAudioMixParameter_Style` 0, `_RemixAmount` 1, `kAUAudioMixProperty_SpatialAudioMixMetadata` 5000, `_EnableSpatialization` 5001, `kAudioUnitSubType_AUAudioMix` 1634560376 | as listed |

`tests/backports/host/audiotoolbox-constants/constants.m` checks each value against the macOS headers the host compiles
against: the test is built with the host's `AudioToolbox` and `AudioUnit` frameworks, and every `check` compares the enumerator
the host header names with the 26.2 value.

**Not measured:** whether the release's mixer or audio units accept these enumerators' values. A value passed to an older
release is a call that release may refuse, and the case row says only that the constant exists.
