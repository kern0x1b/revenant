# The AVFoundation constants the releases this port targets do not export: 116 names, every value read

One object per release, in `AVFoundation/AVFoundationGlobals<NN>.m`, because an object may only carry
API of one release and the gate reads that off the object. Five objects, five releases:

| object | release the name is first exported by | constants | of those read twice | header's own introduced version |
| --- | --- | --- | --- | --- |
| `AVFoundationGlobals1001.m` | 10.0.1 | 1 | 1 | 10.0 |
| `AVFoundationGlobals110.m` | 11.0 | 1 | 1 | 17.0 |
| `AVFoundationGlobals160.m` | 16.0 | 9 | 9 | 14.0, 17.0 and 26.0 |
| `AVFoundationGlobals180.m` | 18.0 | 51 | 42 | 17.0, 17.4, 18.0 and 26.0 |
| `AVFoundationGlobals260.m` | no held cache exports it | 54 | 0 | 26.0 |
| | | **116** | **62** |

The split is by **measured** release, not by the header's `API_AVAILABLE`. `tools/symbol-first-release.lua`
over the held cache ladder answers the question an object is placed by: the first release whose
AVFoundation *exports* the name. The two disagree for 30 of the 116 names, and by a lot in one
direction - the ladder holds no cache between 12.0 and 16.0 and none above 18.0, so every name that
arrived in 13.x to 15.x measures as 16.0 and every name that arrived in 17.x measures as 18.0, whatever
the header says. `AVMediaTypeAuxiliaryPicture` is the clearest case: the header says iOS 14.0 and the
measurement says the 16.0 cache exports it. That is the whole reason for the rule, and it is why
`relcheck.lua` (which is what the gate runs) refuses an object that holds names from two releases.


## The oracles, and a correction

**The host's own AVFoundation, on this machine.** `tests/backports/host/avf-globals/` is a differential:
`run.sh` compiles the port's five objects with each constant's *definition* renamed to a `charon_host_`
spelling and links them beside `probe.m`, so the bare name is Apple's own symbol and the prefixed name is
the port's own definition, and one process prints both. 116 of 116 agree.

```
$ sh tests/backports/host/avf-globals/run.sh
the port's own sources declare 116 constants
ok  control AVMediaTypeVideo = STR vide
ok  control AVMediaTypeDepthData = STR dpth
ok  control AVMediaTypeCharonProbeNoSuchConstant = LACKS
ok  control AVPlayer = HAS 0x1f0c10830
ok  116 constants declared, 116 names read, 116 rows emitted
the join compared 116 rows that agree and 0 that differ
ok  every one of the 116 constants the port defines holds the value the host's own symbol holds
```

And the check can fail, which is the part that makes it a check:

```
$ AVFGLOBALSMUTANT=1 sh tests/backports/host/avf-globals/run.sh
the join compared 115 rows that agree and 1 that differ
ok  the mutation was noticed, on 1 row(s):
DIFFERS	AVFileTypeDICOM	host=[STR org.nema.dicom] port=[STR org.nema.dicom.PLANTED]

$ AVFGLOBALSMUTANT=1 CONTROL=1 sh tests/backports/host/avf-globals/run.sh
the join compared 116 rows that agree and 0 that differ
ok  the control is clean: the unmutated sources through the identical build-and-run path
```

**The correction.** The first version of this page said the host could not be used at all, because
macOS 27's `/System/Library/Frameworks/AVFoundation.framework/Versions/A` holds `_CodeSignature` and
`Resources` and no binary, and `dlsym` for `_AVMediaTypeVideo` on the image path answered nothing. Both
observations were right and the conclusion drawn from them was wrong. The image is in the shared cache,
`dlopen` succeeds, and this release exports these data symbols **without** the Mach-O leading underscore:

```
dlopen /System/Library/Frameworks/AVFoundation.framework/AVFoundation   handle=0x36c68ebc0 err=-
AVPlayer class       = 0x1f0c10830
dlsym _AVMediaTypeVideo = 0x0
dlsym AVMediaTypeVideo  = 0x1eb7b2a88
```

So the first probe, which only asked for the `_`-prefixed spelling, found nothing for all 121 names and
reported that the host does not have the framework. The probe now asks both spellings and prints which
one answered with every row. The coordinator caught this; the numbers above are the host's, measured
here, and the corpus table is now a third opinion rather than the only one.

**The release's own cache.** `tools/corpus/cache-value.lua` reads what a symbol an image of a dyld
shared cache exports actually holds: the export gives the variable's address, the variable holds a
slid pointer, the pointer names a `__CFString`, and the string's own words give the bytes and their
count. It uses the tree's own cache reader (`modules/apple/dyld.lua`).

```
CHARON_ROOT=$PWD xmake l tools/corpus/cache-value.lua \
    ~/.charon/dyld/18.0/dyld_shared_cache_arm64e .agent-work/avf/symbols-pointer.tsv > .agent-work/avf/values-18.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/cache-value.lua \
    ~/.charon/dyld/16.0/dyld_shared_cache_arm64e .agent-work/avf/symbols-pointer.tsv > .agent-work/avf/values-16.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/cache-value.lua \
    ~/.charon/dyld/12.0/dyld_shared_cache_arm64  .agent-work/avf/symbols-pointer.tsv > .agent-work/avf/values-12.tsv
```

Its own controls, on each of the three caches:

```
# control AVMediaTypeVideo	STRING	vide	4 bytes	isa __NSCFConstantString
# control AVMediaTypeCharonProbeNoSuchConstant	ABSENT	-
```

The ladder ends at 18.0, so this oracle reaches every constant up to and including 18.0 and **nothing**
above it: 54 of this framework's 26.0 constants are in no cache this machine holds, and for those two
thirds of the work the host differential above is the only oracle - which is why it had to be right.

**The corpus table.** `coordination/corpus/ledger/constant-values-AVFoundation.tsv` holds 231 rows
measured the same way on the same build (`macOS 26A428`, which is this machine's build number). All 116
names are in it and all 116 agree with the run above.

## Where the oracles meet

Three, and they agree on every name that more than one of them reaches:

```
host (this machine)            vs iOS caches: agree 62 differ 0   (54 names no held cache reaches)
host (this machine)            vs corpus table: agree 116 differ 0
```

The agreement is not a formality. `AVURLAssetOverrideMIMETypeKey` is **not** the string its own name
says:

```
17.0   AVURLAssetOverrideMIMETypeKey   AVURLAssetOutOfBandMIMETypeKey
```

and `AVPlayerInterstitialEventMonitorInterstitialEventWasUnscheduledErrorKey` is spelled
`InterstitialEventWasUnschedule` - without the `d` - in the value the host's own symbol holds. Both were
written out by name first and the measurement disagreed with what had been written, which is the reason
every value here is read and none is typed.

## What the ladder measures, and the run that measured it

```
CHARON_ROOT=$PWD xmake l tools/symbol-first-release.lua .agent-work/avf/first-names.txt > .agent-work/avf/first-release.tsv
ladder: 53 rungs, 3.0 (armv7) .. 18.0 (arm64e)
owner filter: on, the .tbd libraries of .../iPhoneOS16.4.sdk
```

The names are spelled with the leading underscore the image exports, and that matters: asked the way C
spells them the same tool answers `none` for every one of the 116, which would have placed all of them
in the 26.0 band. Its own header states what it measures - "the first held release that exports it,
read from that release's own dyld shared cache ... what it reports is where a client can first bind the
symbol, not what a header's availability annotation says" - and its `owner filter` line says which
libraries count.

The distribution over the 116:

```
  1 10.0.1      1 11.0      9 16.0     51 18.0     54 none
```

`none` is an answer, not a gap: it is how this port decides an API is not in any held release at all, and
those 54 names are placed by their registry row's own `introduced` (26.0 for every one of them), which
is why they form one object.

## The five this cannot answer

`AVCaptureWhiteBalanceTemperatureAndTintValues{Cloudy,Daylight,Fluorescent,Shadow,Tungsten}` are not
strings. `AVCaptureWhiteBalanceTemperatureAndTintValues` is a struct of two `float`s
(`AVCaptureDevice.h:1671-1673` of the SDK 26.2), so there is no `__CFString` behind the symbol and the
host differential above reads the address of a constant and not a pair of numbers - measured, the run
reports them as `NUM <address>` and not as a temperature and a tint. They are also
`API_UNAVAILABLE(macos)`, so no macOS build carries them at all, and no held cache is of a release that
has them. Their value is a pair of colour temperatures and tints only Apple's own image holds. They are
**not** carried: a constant with an invented value is a silent fake, and the pair would be invented. See
`coordination/wave-2026-10-03/v-avf-report.md`.

## What these constants are for, on this port

None of them is the release's own: 6.1.3 exports none of these names, so an application that names
one loads the string below instead of a missing symbol. Where it hands that string to the release -
`AVAssetExportSession presetName`, `AVMetadataItem keySpace`/`key`, a format description's
`AVMediaType`, a `NSNotificationName` - the release compares it against the strings it knows and
answers as it answers for any string it does not know. That is the whole behaviour, and it is the
same behaviour the release has for a string it has never heard of; the point of carrying the name is
that an application which names it links and runs instead of failing to load.