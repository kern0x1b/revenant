# VTCompressionSessionPrepareToEncodeFrames, the H.264 profile levels of iOS 7, kVTDecompressionPropertyKey_RealTime

Ranks 15 and 30 to 42 of `coordination/corpus/band-frameworks.tsv`, all `LOAD-FAIL`: provenance and
telegram bind `_VTCompressionSessionPrepareToEncodeFrames`, session and telegram the thirteen
constants. iOS 6.1.3 carries `VideoToolbox.framework` at `/System/Library/Frameworks` with the whole
compression and decompression session API (94 exports, `_VTCompressionSessionCreate` among them, on
the armv7 cache ladder since 3.1.3); it lacks only these fourteen names.

## Releases

The armv7 cache ladder first exports `VTCompressionSessionPrepareToEncodeFrames` and the twelve
profile levels at 7.0 and `kVTDecompressionPropertyKey_RealTime` at 8.0. The SDK header says 8.0 for
all fourteen: VideoToolbox became public API in iOS 8, after the 7.0 release had exported them. The
registry follows the ladder. The profile levels are exactly the twelve 7.0 adds over 6.1.3;
`kVTProfileLevel_H264_Baseline_3_0` and the other levels 6.1.3 exports are the release's own.

## The values

A constant's value is the string the release's symbol points at, and the port carries the same:
each profile level is its name without `kVTProfileLevel_` (`H264_Baseline_4_0` and so on),
`kVTDecompressionPropertyKey_RealTime` is `RealTime`. Read from the host's VideoToolbox
(`tests/backports/host/vtvalues`), and held against the caches: the strings `H264_Baseline_4_0`,
`H264_High_5_2` and `H264_Main_5_2` are in the armv7 caches of 7.0 and 8.0 and in none of 6.1.3,
while the control `H264_Baseline_3_0`, a level 6.1.3 exports, is in all three.

## VTCompressionSessionPrepareToEncodeFrames

The encoder of a compression session sets itself up on its first frame; the function lets a caller
have that done before. The host answers `kVTParameterErr` (-12902) for `NULL` and `noErr` for
anything else - a fresh session, the same session again, an invalidated session (on which
`VTSessionCopyProperty` already answers -12903), a JPEG session, even a pointer to a string. The port
answers the same: `NULL` is refused, and anything else is left to set itself up on the first frame, as
it does on the release without the call. 6.1.3's VideoToolbox has no call that sets an encoder up
before its first frame to reach instead: none of its 94 exports (`.agent-work` ladder `vt-6.1.3.txt`)
names a preparation, a pass or a warm-up.

So the call is inert: it answers as the host does and prepares nothing. What an application that calls
it would learn early - that the encoder cannot get its resources - it learns on 6.1.3 from the status of
its first `VTCompressionSessionEncodeFrame`, where the release's encoder sets itself up.

## On the device

Measured on an iPad 2 running 6.1.3, 29 checks, 0 failures: a daemon linked against this package
(`avfoundation`, `tests/backports/device/h264decode.m`) builds format descriptions with `CMVideoFormatDescriptionCreateFromH264ParameterSets`
from the SPS and PPS of the host's encoder (320x240 baseline, 640x480 high), the release's
`VTDecompressionSession` takes them and decodes one IDR frame each to the right size and the
checkerboard that was encoded. Then:

- `VTCompressionSessionPrepareToEncodeFrames(NULL)` answers -12902; on a live 320x240 H.264 session
  it answers 0, and the session encodes a frame after it.
- The 6.1.3 encoder refuses each of the twelve 7.0 profile levels: `VTSessionSetProperty(session,
  kVTCompressionPropertyKey_ProfileLevel, level)` answers -12900 (`kVTPropertyNotSupportedErr`) and
  logs `VXE FIG ERROR: profile & level passed is not supported`; the session still encodes a frame
  (which level it encodes at was not read). The controls `H264_Baseline_3_1` and `H264_Main_AutoLevel`, levels 6.1.3 has,
  answer 0. So an application that asks for a level this hardware's encoder does not know gets the
  release's own refusal as the status, not a quiet substitute: the port does not map a level onto
  another.
- The 6.1.3 decoder refuses `kVTDecompressionPropertyKey_RealTime` the same way (-12900) and decodes
  as it always does.
