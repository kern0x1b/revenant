# The four AVFoundation functions this worker's list holds, against the host

`AVFoundation/AVFoundationFunctions180.m`, one object, because an object may only hold API of one
release and all four measure the same: `tools/symbol-first-release.lua` puts the three caption
constructors at 18.0, which is what their header says, and `AVCaptureReactionSystemImageNameForType` at
18.0 as well **though its header calls it iOS 17.0** - the ladder holds no cache between 12.0 and 16.0,
so a 17.0 name measures as 18.0. Measured, not annotated, is the rule.

| function | header says | measured first exported by |
| --- | --- | --- |
| `AVCaptionDimensionMake` | 18.0 | 18.0 |
| `AVCaptionPointMake` | 18.0 | 18.0 |
| `AVCaptionSizeMake` | 18.0 | 18.0 |
| `AVCaptureReactionSystemImageNameForType` | 17.0 | 18.0 |

## The types the port has to declare

`AVCaptionUnitsType`, `AVCaptionDimension`, `AVCaptionPoint` and `AVCaptionSize` are iOS 18 and SDK 16.4
declares none of them, so `CharonAVFoundationCaption18.h` transcribes 26.2's own declarations. Two
departures from 26.2's text, both forced by the SDK the toolchain resolves and both stated in the header:

- **`API_UNAVAILABLE(visionos)` is dropped from every declaration.** SDK 16.4's `availability.h` does not
  know the word, and expanding it there is `error: expected ','` on the line after the macro's own
  `visionos` argument - three errors, one per declaration. Nothing is lost: the annotation marks platforms
  this port does not build for.
- **the eight `AVCaptureReactionType` constants are declared here too.** They are the port's own carried
  constants - SDK 16.4 declares neither the type nor any of the names, and
  `AVFoundationGlobals180.m` defines the strings - so the lookup compares against the carried value
  instead of a second copy of the text written out beside it.

## The differential

`tests/backports/host/avf-globals/functions.m`, in the same binary as the constants phase: the port's
object is compiled with its four definitions renamed to `charon_host_` names and with the eight reaction
constants it compares against renamed too, and linked beside a probe that calls Apple's own symbols
under the bare names. Both sides are read with the SDK's own `AVCaptionDimension` / `AVCaptionPoint` /
`AVCaptionSize`, which are 26.2's layout - the layout the port's own header transcribes - so the port's
function returns what the host's does.

```
$ sh tests/backports/host/avf-globals/run.sh
the port's AVFoundationFunctions180.m defines 4 functions
ok  control AVCaptionNoSuchConstructor = LACKS
ok  control AVCaption = HAS 0x1f1ffb970
ok  control AVCaptionDimensionMake(0,Percent) port and host = 0/2 0/2
ok  21 struct rows agree with the host and 8 reaction types answer the same string
note: the type the port does not carry, measured on both sides: image host=[(null)] port=[(null)]
```

21 struct rows: five values (0, 1, 42.5, 100, -3.25) against each of the three `AVCaptionUnitsType`
values for `AVCaptionDimensionMake`, and three mixed-unit pairs each for `AVCaptionPointMake` and
`AVCaptionSizeMake`. The constructors are not a re-implementation of anything: each field holds exactly
what it was handed, and the host says so over that spread.

The reaction table is a lookup in Apple's own table of SF Symbol names, which is not something this
repository can derive. All eight were read by calling the host's own function:

```
AVCaptureReactionTypeBalloons     balloon.2.fill
AVCaptureReactionTypeConfetti     party.popper.fill
AVCaptureReactionTypeFireworks    fireworks
AVCaptureReactionTypeHeart        heart.fill
AVCaptureReactionTypeLasers       laser.burst
AVCaptureReactionTypeRain         cloud.rain.fill
AVCaptureReactionTypeThumbsUp     hand.thumbsup.fill
AVCaptureReactionTypeThumbsDown   hand.thumbsdown.fill
```

A reaction type the port does not carry answers nil, and that is **measured on both sides**, not assumed:
`image host=[(null)] port=[(null)]`. The host answers nil for a string it has never heard of, and so does
the port.

## The plants

Two, one per phase, because one variable drove both and the first phase reported its verdict and exited
before the second was reached:

```
$ AVFGLOBALSMUTANT=constant sh tests/backports/host/avf-globals/run.sh
the join compared 115 rows that agree and 1 that differ
DIFFERS	AVFileTypeDICOM	host=[STR org.nema.dicom] port=[STR org.nema.dicom.PLANTED]

$ AVFGLOBALSMUTANT=function sh tests/backports/host/avf-globals/run.sh
# the mutation applied: one returned string in one function, changed and gone afterwards
ok  the mutation was noticed: 0 struct row(s) and 1 reaction row(s) differ
AVCaptureReactionTypeHeart	host=[heart.fill]	port=[heart.PLANTED]

$ AVFGLOBALSMUTANT=function CONTROL=1 sh tests/backports/host/avf-globals/run.sh
ok  the control is clean: the unmutated sources through the identical build-and-run path
```

With a function mutation the constants phase runs first and must be clean, or the function verdict
would be read on a tree whose constants are already wrong. That check is in the script and it fires:

```
FAIL: the constants differ on 1 row(s) before the function mutation is even applied
```

## Four mistakes this harness made before it worked

Left here because each of them reads as a green run rather than as a failure.

1. **The rename was anchored at the start of a line.** The three constructors are written
   `AVCaptionDimension AVCaptionDimensionMake(...)` and the lookup `NSString
   *AVCaptureReactionSystemImageNameForType(...)`, so neither has its name at column 0. The anchored
   pattern renamed nothing, the four symbols then resolved against the linked AVFoundation, every
   `charon_host_` pointer stayed NULL, and the probe segfaulted on the first call.
2. **A second, private spelling of the structs.** The first version declared its own `CharDimension`,
   `CharPoint` and `CharSize` with the same field types and the same widths, and called through function
   pointers cast to them. Same segfault, same place. A second spelling of a struct this file then calls
   through a pointer is an ABI mismatch with no compiler to notice it.
3. **`-c` on a file whose suffix the driver does not recognise.** The copies are named `.fn`; clang takes
   that for something to link, and with `-c` it exits 0 having written nothing - no error, no log line,
   no object. The next step fails with `no such file or directory` and names the wrong thing. Fixed with
   `-x objective-c`, and with a guard that a compile which reported success and wrote no object stops the
   run rather than letting the link measure nothing.
4. **`AVCaptureReactionType` matched the parameter's TYPE.** Renaming the reaction constants with a plain
   `AVCaptureReactionType` pattern also rewrites `NSString *f(AVCaptureReactionType reactionType)`. The
   rename is anchored on `isEqualToString:` instead, and the copy is checked for all eight before it is
   compiled.

A force-included header is read *before* the source's own `#import`, which is why `renamed.h` imports
Foundation itself: without that every line of it is `unknown type name`.

## The four functions still to do

`AVCaptureTimecodeAdvancedByFrames`, `AVCaptureTimecodeCreateMetadataSampleBufferForDuration` and
`AVCaptureTimecodeCreateMetadataSampleBufferAssociatedWithPresentationTimeStamp` (iOS 26) and
`CMTagCollectionCreateWithVideoOutputPreset` (17.2 by its header, 18.0 measured). The first adds frames
with an overflow rule for seconds, minutes and hours; the two sample-buffer builders produce Timecode
Media Description metadata whose exact bytes are Apple's, and the last needs
`CMTagCollectionVideoOutputPreset`'s own tag set. None of the four is started; see
`coordination/wave-2026-10-03/v-avf-report.md`.