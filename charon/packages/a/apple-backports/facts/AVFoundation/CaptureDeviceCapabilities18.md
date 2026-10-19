# The capture-device capabilities of iOS 18: 15 rows, one object

`AVFoundation/AVCaptureDeviceCapabilities18.m` carries all fifteen - five on `AVCaptureDevice`, six on
`AVCaptureDeviceFormat`, three on `AVCaptureDeviceInput` and the method `-isMultichannelAudioModeSupported:`.
Registry: `registry/AVFoundation/capabilities18.json`, fifteen rows, one per row the
`coordination/corpus/ledger-2026-10-03/AVFoundation.tsv` snapshot reads `missing` for these three classes at
18.0 (`$4=="18.0" && $6=="missing"`; the status is column six, `needs` is seven). Header:
`CharonAVCaptureDeviceCapabilities18.h`, transcribed from the SDK 26.2 because SDK 16.4 declares none of it.

## Open source checked

The coordinator's scout table (`charon/.agent-work/runs/oss-scout/oss-candidates.tsv`) was read; its
`framework_breakdown` column names AVFoundation once, in the `apple/swift-corelibs-foundation` row
(`Foundation=20;UIKit=4;SensorKit=3;AVFoundation=1`), and that one line is the table's only AVFoundation
mention - the reading `facts/AVFoundation/AVFoundationNotificationKeys.md` already recorded and corrected.
**Not used, because no candidate answers these rows.** They are the answers of three capture classes to
questions about the hardware on a camera and a microphone, and the one candidate that touches AVFoundation is
a Foundation implementation's own type definitions. The answers are measured from the host's own framework
instead, and the three rows whose value is a `nil` that the header itself documents are the header's own.

## The oracle is this Mac's own AVFoundation, and this Mac has a camera and a microphone

`tests/backports/host/avf-capabilities` asks both sides in one process and compares **both columns**. The
host's camera is a `MacBook Pro Camera` with seven formats, and its built-in microphone is a single one, which
is the same shape of hardware as the devices of this port's bands (an iPhone 4S and an iPad 2: a camera on each
side, one microphone, measured on both, `AVCaptureDeviceDiscovery.md`, "What the hardware has"). Measured:

| row | host | port | why the two differ, or that they do not |
| --- | --- | --- | --- |
| `autoVideoFrameRateEnabled` | 0 | 0 | they agree: the header's default is false and neither camera has the feature |
| `backgroundReplacementActive` | 0 | 0 | they agree: nothing is running |
| `backgroundReplacementEnabled` (class) | 0 | 0 | they agree: this Mac's Control Center has it off, and this release has no such setting to enable |
| `displayVideoZoomFactorMultiplier` | **0.5** | **1** | the display ratio: this Mac's Video Effects Menu shows the zoom at half the capture value, and this release has no system interface that displays one |
| `spatialCaptureDiscomfortReasons` | 0 reasons | 0 reasons | they agree: neither camera can capture spatially |
| `autoVideoFrameRateSupported` | 0 | 0 | they agree, for all seven of the host's formats |
| `backgroundReplacementSupported` | **1** | **0** | the hardware: this Mac's camera has the feature, all seven formats |
| `spatialVideoCaptureSupported` | 0 | 0 | they agree: one lens apiece |
| `systemRecommendedExposureBiasRange` | nil | nil | they agree |
| `systemRecommendedVideoZoomRange` | nil | nil | they agree |
| `videoFrameRateRangeForBackgroundReplacement` | **a range** | **nil** | the pairing the header states: the host's formats support the feature, these do not |
| `multichannelAudioMode` | 0 (None) | 0 (None) | they agree |
| `windNoiseRemovalEnabled` | 0 | 0 | they agree, and the setter phase below shows it is a value and not a refusal |
| `windNoiseRemovalSupported` | 0 | 0 | they agree: one microphone |
| `-isMultichannelAudioModeSupported:` for 0, 1, 2 | 1, 0, 0 | 1, 0, 0 | they agree on all three modes |
| `-setAutoVideoFrameRateEnabled:` | raises, `*** -[AVCaptureDALDevice setAutoVideoFrameRateEnabled:] Not supported - use -[AVCaptureDeviceFormat autoVideoFrameRateSupported]` | raises, the same tail with this port's own class | the class in the prefix is the only difference; see below |
| `-setMultichannelAudioMode:` for 1 and 2 | raises, `*** -[AVCaptureDeviceInput setMultichannelAudioMode:] Not supported` | the same string | they agree character for character |
| `-setMultichannelAudioMode: 0` | accepted, kept 0 | accepted, kept 0 | they agree: the supported mode is settable |
| `-setWindNoiseRemovalEnabled:` for YES and NO | accepted, kept 1 and 0 | accepted, kept 1 and 0 | they agree, even though `windNoiseRemovalSupported` is 0 on both sides |

**Twelve of the fifteen rows have the host's own answer identical to the port's**, including all three of
`AVCaptureDeviceInput`'s and all three of `-isMultichannelAudioModeSupported:`'s. The three that differ -
`displayVideoZoomFactorMultiplier`, `backgroundReplacementSupported` and
`videoFrameRateRangeForBackgroundReplacement` - do so for a reason stated per row, and this page says so rather
than dressing it up.

## The two refusals, and which part of each string is Apple's

Both come from the header's own rule rather than from a choice, and both use Apple's own reason string.

**`-setAutoVideoFrameRateEnabled:`** - "Setting this property throws an `NSInvalidArgumentException` if the
active format's `autoVideoFrameRateSupported` returns `false`" (`AVCaptureDevice.h:399`). Every format of this
port answers NO for that (the row below), so every set raises here; the port keeps the value for a format that
did support it, and the refusal is the format's answer rather than a constant. Measured on the host, Apple's
reason is

```
*** -[AVCaptureDALDevice setAutoVideoFrameRateEnabled:] Not supported - use -[AVCaptureDeviceFormat autoVideoFrameRateSupported]
```

and the tail after the class name is what the port raises verbatim. **The class in the prefix is not Apple's
and is not copied:** `AVCaptureDALDevice` is a private class of Apple's device-access layer, and the setter
belongs to `AVCaptureDevice` on this port - the class the port has and the one the header declares the member
on. Copying the whole string would name a class that does not exist in any band this port builds.

**`-setMultichannelAudioMode:`** - "The receiver's `multichannelAudioMode` property can only be set to a certain
mode if this method returns YES for that mode" (`AVCaptureInput.h:381`), so the setter asks
`-isMultichannelAudioModeSupported:` and refuses when it answers NO. Measured on the host, out of a session:

```
setMultichannelAudioMode: 0    returned, kept 0
setMultichannelAudioMode: 1    NSInvalidArgumentException: *** -[AVCaptureDeviceInput setMultichannelAudioMode:] Not supported
setMultichannelAudioMode: 2    NSInvalidArgumentException: *** -[AVCaptureDeviceInput setMultichannelAudioMode:] Not supported
setMultichannelAudioMode: 3    NSInvalidArgumentException: (the same)
setMultichannelAudioMode: -1   NSInvalidArgumentException: (the same)
```

The port raises that string unchanged, and here the class in the prefix **is** the port's own. (Sent to an
input inside a session, the host's own string names `AVCaptureDeviceInput_Tundra` - the same private class of
its device-access layer under a different name - which is why the out-of-session measurement is the one the
table carries.)

**One measurement withdrawn.** The first run of this probe reported that `-setMultichannelAudioMode:` raises
for `AVCaptureMultichannelAudioModeNone` as well. That was the probe's own error: it sent an `NSNumber` where
the setter takes an `NSInteger`, which put a pointer in the integer register, and a pointer is not 0. Sent
with a correctly typed argument the mode is accepted on the host and on the port. The run
`tests/backports/host/avf-capabilities/probe.m` now sends every setter value as an `NSInteger`, the way clang
does when a caller writes `setX:someEnum`.

## The three types, and what is and is not carried

- **`AVCaptureMultichannelAudioMode`** - the enum of three values (`AVCaptureInput.h:364-368`). The ledger
  reads the type and its three constants `header-ok`/`lift`, so this header's declaration is all that is owed;
  the values are the header's own (0, 1, 2) and the probe prints the number and the name beside each other.
- **`AVSpatialCaptureDiscomfortReason`** - the typedef of `AVCaptureDevice.h:2652`. **Its two constants are
  18.0 rows of their own** (`AVSpatialCaptureDiscomfortReasonNotEnoughLight`, `...SubjectTooClose`, both
  `code+lift` in the ledger) and are **not** carried here: this slice's fifteen rows are the members, and a
  constant is an exported symbol this slice does not carry. So
  nothing a caller can name is ever in the set this slice returns, and the facts say so.
- **`AVExposureBiasRange`** and **`AVZoomRange`** - **forward-declared** in this header and not defined.
  `AVExposureBiasRange` is 18.0's class (its class row, its two properties and its three methods are a family
  of their own in the ledger) and `AVZoomRange` is 17.2's (its own rows likewise), and this slice needs only
  the name to spell `-systemRecommendedExposureBiasRange` and `-systemRecommendedVideoZoomRange`. Both
  properties answer nil here, which is the header's own answer when no recommendation is available
  (`AVCaptureDevice.h:3309`, `:3277`), so no instance of either class is ever made.

## What the releases carry, measured

Read with the repository's own reader, `tools/corpus/objc-inventory.lua`, over the held caches. The
nineteen selectors these fifteen rows' accessors are (`-isAutoVideoFrameRateEnabled`,
`-setAutoVideoFrameRateEnabled:`, `-isBackgroundReplacementActive`, `+isBackgroundReplacementEnabled`,
`-displayVideoZoomFactorMultiplier`, `-spatialCaptureDiscomfortReasons`, `-isAutoVideoFrameRateSupported`,
`-isBackgroundReplacementSupported`, `-isSpatialVideoCaptureSupported`, `-systemRecommendedExposureBiasRange`,
`-systemRecommendedVideoZoomRange`, `-videoFrameRateRangeForBackgroundReplacement`,
`-isMultichannelAudioModeSupported:`, `-multichannelAudioMode`, `-setMultichannelAudioMode:`,
`-isWindNoiseRemovalSupported`, `-isWindNoiseRemovalEnabled`, `-setWindNoiseRemovalEnabled:`):

| cache | classes and protocols read | of the nineteen selectors, in the three owners' own method lists |
| --- | --- | --- |
| 6.1.3 armv7 | 12549 | **0** |
| 16.0 arm64e | 168686 | **0** |
| 18.0 arm64e | 221703 | **0** |

The owners' own lists, for the same three classes, so the reader's silence is not a reader that found nothing:

| cache | `AVCaptureDevice` | `AVCaptureDeviceFormat` | `AVCaptureDeviceInput` |
| --- | --- | --- | --- |
| 6.1.3 armv7 | 100 own instance, 5 own class | 11 own instance, 3 own class | 15 own instance, 1 own class |
| 16.0 arm64e | 289 own instance, 60 own class | 133 own instance, 1 own class | 48 own instance, 2 own class |
| 18.0 arm64e | 368 own instance, 122 own class | 168 own instance, 1 own class | 62 own instance, 2 own class |

So the fifteen rows are code to write and not a release's own member, and the 18.0 cache is the shape the
controls family found for its own API (facts/AVFoundation/CaptureControls.md): at 18.0 the classes are there
and their private machinery for these features is there too - `AVCaptureDeviceInput`'s own list at 18.0 holds
`-_audioCaptureModeForMultichannelAudioMode:` - while not one of the public selectors is. The class symbols
were exported at 17.0/18.0, which is why these are port rows and not "the release's own".

## The bands

One object, and one release: every member above is 18.0 in the header and in the ledger's classification of
the caches, so nothing here spans two releases. `modules/apple/backports.lua`'s `band()` keeps an object in a
band when that band's release exports none of its symbols, and this object is three categories on classes
every release already carries, so it exports none of its own and is kept in every band from the floor up -
which is what every other capture-device category in this package does, and what
`facts/AVFoundation/CaptureDeviceReactions.md` says for the same three classes. At 18.0 and above the
release's own classes would answer if it exported these selectors; the measurement above says it does not.

## Checks

```
sh tests/backports/host/avf-capabilities/run.sh        exit 0
  ok  control AVCaptureInput = HAS  microphone=one input=one
  ok  25 members are answered by both sides
  ok  36 answers are the ones expectations.tsv names, the host's and the port's columns both
  ok  8 preferred-camera steps are the ones the header's four rules give, computed here from the fixture each step used
  ok  the choice survives a launch and stays in the application that made it
  ok  over four Info.plists ...
AVFCAPSMUTANT=capabilities sh .../run.sh  ok  the mutation was noticed: 3 of 36 table answers ...
AVFCAPSMUTANT=multichannel sh .../run.sh  ok  the mutation was noticed: 4 of 36 table answers ...
CONTROL=1 AVFCAPSMUTANT=<each of the four> sh .../run.sh   ok  the control is clean
```

The two plants of this slice, both green through `CONTROL=1`: `capabilities` makes every format claim auto
video frame rate support, which is seen twice over - the format's own row and `-setAutoVideoFrameRateEnabled:`,
which refuses on this port only because that row answers NO - and `multichannel` makes
`-isMultichannelAudioModeSupported:` answer YES for every mode, which is seen in the three support rows and in
both setter refusals. The two plants of the 17.0 half (`reactions`, `prefcam`) still fire through the same
run, at 1 and 6 answers of their own phases.

### Three defects this extension found in the harness itself

1. **A row's name is a selector, and `grep` reads `[` `]` as a bracket expression.** The comparison loop
   looked its row up with `grep "^ANSWER\t$api\t"`, and every method row of this family is spelled
   `-[Class selectorWithArgument:]`, so the run reported "no ANSWER row" for rows the probe had printed.
   The lookup now compares whole fields with `awk -F'\t' -v wanted=... '$1 == "ANSWER" && $2 == wanted'`,
   which cannot read a pattern into a name. Before this, **the two refusal rows of this harness were never
   compared at all**: `-performEffectForReaction:` printed one side's exception name into a row no loop read.
   Both are compared now, and the row is printed with both columns.
2. **The member list's own regex never matched a method row.** `^-\[(\w+) (\w+)\]$` cannot match a selector
   that ends in a colon, so every method row of the 17.0 half was dropped from the list silently, and the run
   printed "0 refusal(s) of its own" - a count of its own list, not of the registry's rows. The pattern now
   takes the colon, and the member name is matched against the declaration's bare name.
3. **The "the macros have something to rename" assertion counted strings.** The 18.0 object spells two
   selector names inside string literals on purpose - that is what keeps the refusal reasons reading
   `-[AVCaptureDevice setAutoVideoFrameRateEnabled:]` rather than the harness's stand-in name - and the
   assertion counted those strings as sends. Comments and string literals are removed before the count now,
   with the reason in the code beside it.