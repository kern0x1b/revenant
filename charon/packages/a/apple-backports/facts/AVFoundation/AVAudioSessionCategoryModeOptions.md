# AVAudioSession.setCategory:mode:options:error:, the session setup before the graph

`-setCategory:mode:options:error:` (iOS 10.0) is a category on `AVAudioSession`, not a new class:
the release already has the class (`AVAudioSession` predates iOS 6, and this port already uses it
in `CallKit/CharonCallAudio.m`), and it already has both real calls this method folds together -
`-setCategory:withOptions:error:` (iOS 6.0) and `-setMode:error:` (iOS 5.0) - measured, not
assumed, three independent ways: the real SDK header, `objc.inventory` against the real armv7
`iOS 6.1.3` shared cache (`.charon/dyld/6.1.3/dyld_shared_cache_armv7`), and `respondsToSelector:`
on a live `[AVAudioSession sharedInstance]` on the guest. All three agree: `-setCategory:error:`,
`-setCategory:withOptions:error:`, `-setMode:error:`, `-category`, `-categoryOptions` and `-mode`
are all there; `-setCategory:mode:options:error:` is not.

## The wall inside the bridge, measured on hardware

The two real calls exist, but what a caller passes through them does not travel unchanged - this
is the coordinator's warning about "accepted and silently ignored" made concrete. Measured on a
real iPad 2, iOS 6.1.3 (`org.charon.session-probe`, not a class this port carries - a throwaway
device probe that only ever reads `categoryOptions`/`mode` back, never records or touches an audio
sample), against `AVAudioSessionCategoryPlayAndRecord`:

| Option bit (value) | Documented since | Verdict |
| --- | --- | --- |
| `AVAudioSessionCategoryOptionMixWithOthers` (0x1) | iOS 6.0 | accepted, round-trips exactly |
| `AVAudioSessionCategoryOptionDuckOthers` (0x2) | iOS 6.0 | accepted, round-trips exactly |
| `AVAudioSessionCategoryOptionAllowBluetooth` (0x4) | iOS 6.0 | accepted, round-trips exactly |
| `AVAudioSessionCategoryOptionDefaultToSpeaker` (0x8) | iOS 6.0 | accepted, round-trips exactly |
| all four iOS 6.0 bits together (0xf) | - | accepted, round-trips exactly - no truncation from combining |
| `AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers` (0x11) | iOS 9.0 | **accepted without error, then silently masked**: readback is `0x1` (only the `MixWithOthers` low bit survives) |
| `AVAudioSessionCategoryOptionAllowBluetoothA2DP` (0x20) | iOS 10.0 | **accepted without error, then silently masked**: readback is `0x0` |
| `AVAudioSessionCategoryOptionAllowAirPlay` (0x40) | iOS 10.0 | **accepted without error, then silently masked**: readback is `0x0` |
| `AllowBluetooth (0x4) \| AllowBluetoothA2DP (0x20)` combined | - | mixed within the same call: the 6.0 bit round-trips, the 10.0 bit is silently masked off (readback `0x4`, not `0x24`) |

The release's own `-setCategory:withOptions:error:` accepts any `NSUInteger` bitmask without
complaint and quietly keeps only the four bits it understands - `BOOL ok` and the absence of an
`NSError` say nothing about which bits actually took. This is not a version gate refusing a
younger bit; it is measured, on-device masking, and it is the exact shape of defect the
coordinator asked this cluster to be checked for: a call that succeeds and drops data with no
signal at all.

Mode is the opposite shape, and needs no mask: `-setMode:error:` either accepts a mode and reads
it back exactly (`AVAudioSessionModeDefault`, `AVAudioSessionModeVoiceChat`,
`AVAudioSessionModeMeasurement`, `AVAudioSessionModeGameChat`, all measured round-tripping), or
refuses it with a real `NSError` - `AVAudioSessionModeMoviePlayback` against
`AVAudioSessionCategoryPlayAndRecord` was refused this way on the iPad, `OSStatus 'what'`
(`2003329396`), a genuine Core Audio rejection, not silence.

## What the bridge does about it

`AVAudioSession+CategoryModeOptions.m`'s `-setCategory:mode:options:error:` calls the real
`-setCategory:withOptions:error:` with the caller's options exactly as given (masking nothing
itself - the release already does that), then compares what was asked against what
`-categoryOptions` reads back afterward. Any bit the release silently dropped is named once, not
per call, the same one-time `NSLog` pattern `CoreLocation/CLLocationManager+Background.m` already
uses for a kept-but-inert property - loud instead of quiet, but not spammy. Mode is forwarded to
the real `-setMode:error:` unmodified; whatever `NSError` it returns (or none) is the bridge's own
answer, since the release is already honest there.

## The one caveat this measurement does not close

**Measured on an iPad 2 - no telephony.** Every bit and mode above is settled for this device.
Anything tied to the phone path specifically - an interruption from an incoming call, routing
tied to the cellular receiver - is not exercised by anything above and needs the same measurement
repeated on an iPhone (a 4S) before it is trusted for that path. Nothing here claims otherwise.
