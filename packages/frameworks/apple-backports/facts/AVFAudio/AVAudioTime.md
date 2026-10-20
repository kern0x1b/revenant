# AVAudioTime

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), over the `AudioTimeStamp` the
release's own engine fills in and the machine's clock.

**The clock.** The SDK 26.2 `CoreAudio.framework` ships **no header at all** - `Headers` holds
`CoreAudioTypes.h` and nothing else - and neither `AudioGetCurrentHostTime` nor
`AudioGetHostClockFrequency` is declared in any header of the SDK, though the first is exported by
the framework's own `.tbd`. So the port does not write out a declaration of its own for them: host
time is `mach_absolute_time()` and the frequency is `mach_timebase_info()`, both from libSystem's
`mach/mach_time.h`. They are the same clock - `AudioFileSecondsToHostTime` is documented as
`seconds * mach_frequency()`, and an `AudioTimeStamp`'s `mHostTime` is what
`AudioGetCurrentHostTime()` returns.

**The conversion** `+hostTimeForSeconds:` is that multiplication with no rounding, and
`+secondsForHostTime:` its inverse, so a round trip through the two is the release's own arithmetic
and not the port's. `mach_timebase_info` is read once, under `dispatch_once`.

**The class is immutable**, as the header says, and every answer is read out of the one
`AudioTimeStamp` the instance holds. The four constructors differ only in which of the stamp's flags
they set, which is what makes `isHostTimeValid` and `isSampleTimeValid` agree with the header's
description of them: a time made with a host time and no sample rate is a host time and nothing else,
and one made with a sample time at a rate is a sample time and nothing else.

**`-extrapolateTimeFromAnchor:`** is the header's rule taken literally: the anchor must have both a
host time and a sample time valid, the receiver a sample rate and at least one of the two, and the
answer is a copy of the receiver with the missing field filled in. The two fields are related
through the sample rate, the same conversion the engine's own timestamps make, and the result is
rounded to the nearest tick - a host time is a tick count. Every other case answers `nil`, which is
what the header says it does.
