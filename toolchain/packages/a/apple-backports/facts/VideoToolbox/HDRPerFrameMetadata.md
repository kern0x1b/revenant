# The HDR per-frame metadata generation session, and the CFTypeID it hands out

SDK 26.2's `VTHDRPerFrameMetadataGenerationSession.h` declares a session that arrived with iOS 18.0: it
measures a frame, generates Dolby Vision per-frame metadata for it, and writes that metadata into the
pixel buffer's attachments and into the IOSurface behind it. Four names, and the 16.4 SDK this package
builds against declares none of them, so the port declares them in `CharonVideoToolbox.h` and exports
them from `VTHDRPerFrameMetadataGenerationSession18_0.m`.

## The zero that stands behind all of it

`dump-cache.lua` over `$HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7` finds no
`VTHDRPerFrameMetadataGenerationSession` symbol, and VideoToolbox's own header on the armv7 ladder
declares none of these four names. More than that: no armv7 release has Dolby Vision, and no armv7
release has the HDR metadata attachments the session writes into. There is nothing to generate and
nowhere to put the result.

## The two argument checks come first, because they do not depend on hardware

A caller that passes a zero frame rate or a NULL pixel buffer gets the same answer on a device that has
the hardware, so those checks are made before the capability question - and both are the HOST's own
answers, measured on 2026-10-03 rather than read out of a comment:

| call | host | port |
| --- | --- | --- |
| `Create(kCFAllocatorDefault, 0.0f, NULL, &out)` | `-12902` (kVTParameterErr), `out` left NULL | the same |
| `Create(kCFAllocatorDefault, 24.0f, NULL, &out)` | `0`, `out` set | `-12915`, `out` set to NULL |
| `AttachMetadata(session, NULL, false)` | `-12902` (kVTParameterErr) | the same |

`VTErrors.h` gives every code used here: kVTParameterErr -12902, kVTInvalidSessionErr -12903,
kVTVideoEncoderNotAvailableNowErr -12915. -12915 is the one Create answers when the arguments are
valid: it is the code the release's own header gives for the encoder that would consume this metadata
not being available now.

`Create` writes NULL into the caller's slot before returning the failure, so a caller that ignores the
status cannot read a stale pointer for a session. That is what the host does too - with a zero frame
rate it leaves the slot NULL.

`AttachMetadata` does not second-guess a NON-NULL session. This port hands out none, so there is no way
to tell a caller's pointer from a real one, and inventing a test for it would reject a session Apple's
own implementation accepts.

`sceneChange` is the one argument that changes what would be measured - it tells the session the frame
differs enough from the last to restart the analysis - and there is no analysis to restart.

## The type ID is NOT Apple's number

`VTHDRPerFrameMetadataGenerationSessionGetTypeID()` answers **75** on this host, and 75 is not copied.
A CFTypeID is a slot in a process-wide table; a literal would claim another type's slot in every process
that loads this library and already has a type there. What the port answers is a UUID-backed CFTypeID
from the process's own UUID space - `CFUUIDGetTypeID()`, the mechanism CoreFoundation itself uses for a
type it registers at run time - computed once and cached, so two calls answer the same value, which is
the property a caller compares it for.

## The string is Apple's own and measured

`kVTHDRPerFrameMetadataGenerationHDRFormatType_DolbyVision` is `CFSTR("DolbyVision")`, and the value is
read out of the host's own VideoToolbox rather than written from the constant's name:

```
$ ./probe-hdr
HDRFORMAT	DolbyVision
HDRKEY	HDRFormats
```

The sibling `kVTHDRPerFrameMetadataGenerationOptionsKey_HDRFormats` reads `"HDRFormats"` on the host too,
and is carried by `VideoToolboxConstants18_0.m` on an earlier commit.

A name is not a value on this framework's account already: `kVTCompressionPreset_HighQuality` is
`"HighQuality"` and `kVTViewPackingKind_OverUnder` is `"OverUnder"`, and neither is what its name
suggests.