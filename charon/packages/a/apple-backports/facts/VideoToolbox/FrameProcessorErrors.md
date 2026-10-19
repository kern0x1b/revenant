# VTFrameProcessor's error domain and codes

## The domain string is measured, not written from the name

SDK 26.2 writes the declaration and never the value:

```c
extern NSErrorDomain _Nonnull const VTFrameProcessorErrorDomain;      /* VTFrameProcessorErrors.h:17 */
```

An `NSErrorDomain` is an `NSString *`. No header anywhere spells what it holds, so
`@"VTFrameProcessorErrorDomain"` written from the name would be a guess, and a name is not a value on
this framework's account already: `MTLCommonCounterSetStageUtilization` is `"stageutilization"` and
`kVTCompressionPreset_HighQuality` is `"HighQuality"` (`VideoToolboxConstants7_0.m`), and neither is
what its name suggests.

So the string is APPLE'S OWN and it is MEASURED. The host's
`/System/Library/Frameworks/VideoToolbox.framework` exports the symbol, which
`tools/corpus/probe` does not need any private knowledge to find:

```
$ cat probe-domain.c
    void *h = dlopen("/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox", RTLD_LAZY);
    dlsym(h, "VTFrameProcessorErrorDomain");
$ clang -o probe-domain probe-domain.c && ./probe-domain
/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox: VTFrameProcessorErrorDomain = 0x1eb405fe0
```

and reading the NSString it points at (this machine, 2026-10-03):

```
$ ./probe-domain2
VTFrameProcessorErrorDomain = "VTFrameProcessorErrorDomain" (class __NSCFConstantString)
```

The string is the constant's own name. That is the answer, and it is recorded as measured because it is
one that could have been different.

`tests/backports/host/videotoolbox-frameprocessor` repeats both measurements on every run: it
`dlsym`s the host's copy, builds an `NSError` in the PORT's own `VTFrameProcessorErrorDomain` and
compares `.domain` against Apple's string byte for byte.

## Why this file's `GetTypeID` is not the pattern the tree already uses

The tree already has a mechanism for a CF type the 16.4 SDK lacks, and it is used by
`AVFoundation/CMTaggedBufferGroup17.m` and `Graphics/CVMetalTexture80.m`: a `Charon`-prefixed NSObject class
plus `(CFTypeID)objc_getClass("Charon...")` for the type ID. That is one mechanism and it is the right one
for a type that HAS objects - the class pointer is unique, stable and cannot collide with a numeric slot.

This file does not use it, and the difference is deliberate rather than a second mechanism invented by
accident: **this type has no objects.** `VTHDRPerFrameMetadataGenerationSessionCreate` returns
`kVTVideoEncoderNotAvailableNowErr` on every path, so no instance of this type can ever exist and there is
no class whose `isa` could answer for it. A `CharonVTFrameProcessorSession` class with no instances would be
dead code, and a dead class is worse than a UUID: it would need a registry row (a seam the port owns still
needs one, per AGENTS.md) for a class nothing instantiates.

So `CFUUIDGetTypeID()` is used, which is the mechanism CoreFoundation itself uses for a type it registers at
run time, and it cannot collide with a slot any other type holds. If a session ever becomes creatable on a
release that has the hardware, that is the moment this changes - and it should change to the `Charon` class
pattern, which is the one to reuse.

## The codes are an NS_ERROR_ENUM, so there is no symbol for a case

`VTFrameProcessorErrors.h:26` gives fourteen codes with Apple's own values, -19730 through -19743.
They are transcribed into `CharonVideoToolbox.h` as `VTFrameProcessorError`, because a caller compares
a code against those NAMES - `VTFrameProcessorSessionNotStarted` is a call site, not a number - and
there is nothing else that would give an application compiling against this port the same names.

They get no registry rows: an enumerator is not a symbol, so `check_registry` has nothing to place it
by, and the 26.2 surface carries no row for a case of an `NS_ERROR_ENUM` either (measured: the surface
has `VTFrameProcessorErrorDomain` and no `VTFrameProcessor*Error` case).

Which codes the port actually builds, and why:

| code | value | where | why that code |
| --- | --- | --- | --- |
| `VTFrameProcessorInvalidParameterError` | -19741 | `startSessionWithConfiguration:error:`, `processWithParameters:error:` and both block variants, on a nil argument | SDK 26.2 reserves it for "one of the provided parameters is not valid". Decided BEFORE the hardware question, because a caller passing nil gets the same answer on a device that has the hardware. |
| `VTFrameProcessorInitializationFailed` | -19736 | `startSessionWithConfiguration:error:` | "the session failed to initialize the processing pipeline". The release has no frame processor, so initialization is what fails; this is not a generic "unsupported", which is not in the enumeration. |
| `VTFrameProcessorSessionNotStarted` | -19732 | `processWithParameters:error:`, and through it both block variants | "the session is used to process frames without being started". No session ever starts on this release, so no session is ever started. |
| `VTFrameProcessorAssetDownloadFailed` | -19743 | `-downloadConfigurationModelWithCompletionHandler:` | "download of a required model asset for the processor failed". Nothing can be downloaded, and SDK 26.2 ties the error to `configurationModelStatus` returning to `DownloadRequired`, which is the enumeration's own first value, so the error and the status agree. |

`VTFrameProcessorSessionAlreadyActive` (-19733) is the one code with no path: a session can never
start, so it can never already be active. It is declared because an application compares against it,
and nothing builds it.