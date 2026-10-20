# AVAudioApplication

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), with
`AVAudioSessionPortContinuityMicrophone` and the two notification strings of iOS 17.

**The record permission is the one thing here that has to be right**, because a caller that reads it
is deciding whether to show a prompt. Two cases, both honest:

- **The process has loaded the AVFAudio backports** - `libAVFoundationBackports.dylib` carries the
  record permission of iOS 7 as a category on `AVAudioSession` (`registry/AVFoundation/
  ios8avfaudio.json`, `facts/AVFoundation/AVAudioSessionRecordPermission.md`). The port asks that one,
  by message send: `NSClassFromString(@"AVAudioSession")` and `respondsToSelector:`, so a process
  that never loaded that library is not made to fail over a class it does not have, and the direction
  of the dependency stays dynamic.
- **The process has not** - iOS 6's own `AVAudioSession` has no permission API at all, the first
  being iOS 7, so there is nothing to read. The answer is
  `AVAudioApplicationRecordPermissionUndetermined`, which is what iOS 17 answers for an application
  that has not asked, and a request answers `NO`, which is what a device with no permission record
  gives.

So an application that reads the permission and falls back to asking behaves as it does on iOS 17, and
one that needs the answer without asking is told `Undetermined` rather than being given a `granted` it
did not earn.

**The mute state** is kept by the shared application object and read back by `isInputMuted`; a change
made through `-setInputMuted:error:` posts `AVAudioApplicationInputMuteStateChangeNotification` with
`AVAudioApplicationMuteStateKey` in its `userInfo`, and a handler set through
`-setInputMuteStateChangeHandler:error:` is called with the new state. Nothing on this release flips
the hardware switch on its own, so the handler fires only for a change this process made - which is
what the header's own note says the handler is for ("This handler should be set by the process doing
the call's audio I/O").

**`-init` answers the shared instance** rather than a second object: two `AVAudioApplication`
objects would each keep their own mute state, and this API has one mute state. `-init` is in the
corpus because the corpus is the whole SDK surface, so it is answered rather than absent.

**`microphoneInjectionPermission`** answers `Undetermined` and a request answers `Undetermined`:
injecting audio into the record path is a facility of the audio server of a release that has one, and
iOS 6.1.3 has neither the facility nor a C API that reports it. `Undetermined` is the permission a
session that cannot inject reports; it is not a refusal of the call.

`AVAudioSessionPortContinuityMicrophone` is `ContinuityMicrophone`, read out of the host's own
AVFAudio - see `AVFAudioStrings.md` for the reader and its control.

## Measured on the iOS 26.2 cache: the SDK annotation does not hold for the mute handler

The SDK declares `-setInputMuteStateChangeHandler:error:` macOS only (AVAudioApplication.h:104,
`API_UNAVAILABLE(ios, ...)`). The iOS 26.2 cache (23C55, iPhone17,1, arm64e) registers the selector on
AVAudioApplication: `REVENANT_ROOT=<tree> xmake l tools/corpus/objc-inventory.lua <cache>` lists it among
the class's 31 instance selectors, with `setInputMuted:error:` and `isInputMuted` as controls. The row
stays `implemented`. Its introduced release is the one the registry records; the iOS 18.0 and 6.1.3
caches were not read here (review F3).
