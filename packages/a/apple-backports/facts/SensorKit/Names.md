# The names of SensorKit, all 57 of them

**57 names, in one list, compared name by name against the host's own SensorKit** — the 39 that arrived
in iOS 14.0 and the 18 that arrived between 15.0 and 26.0. The count is `names.txt` in the harness and
the list is the one both processes walk, so a name neither side printed is a failure rather than a row
quietly missing from the comparison.

**Every value was read out of the host's own SensorKit** and none was written from memory, by
`tests/backports/host/sensorkit-names/run.sh`: one process links the port's own sources and prints
what the port defines, a second links a reader that opens the host's framework and prints what it
holds, and a comparator puts the two side by side. The two are different sources by construction — the
first is this repository's objects, the second is Apple's own dylib — so a value that were wrong in the
port would have to be wrong in Apple's framework to pass.

**The run's own verdict lines**, which are what make that comparison falsifiable rather than
decorative:

    sensorkit-names: 57 names compared, 0 differing
    sensorkit-names: 57 names compared, 57 differing          <- every value replaced
    the one-wrong plant of SensorKitNames14.m is red and names exactly 1 row: SRDeviceUsageCategoryBooks
    the one-wrong plant of CharonSensorKitNames.h is red and names exactly 1 row: SRSensorSiriSpeechMetrics
    sensorkit-names: 0 names compared, 57 differing  <- COMPARED NOTHING

## Where the names live in this repository, which is six objects and not one

| release | the object that defines them | how many |
| --- | --- | ---: |
| 14.0 | `SensorKitNames14.m` | 39 |
| 15.0 | `SensorKit150.m` | 2 |
| 15.4 | `SensorKit154.m` | 1 |
| 16.4 | `SensorKit164.m` | 1 |
| 17.0 | `SensorKit170.m` | 4 |
| 17.4 | `SensorKit174.m` | 8 |
| 26.0 | `SensorKit260.m` | 2 |

An object carries the API of exactly one release and `tools/release-split.lua` refuses a file whose
symbols first appear in two, so the eighteen later names cannot live in `SensorKitNames14.m`. Their
**values**, however, are one list, and the harness has to walk that list from a single host-compilable
source — so they are defined once, in `CharonSensorKitNames.h`, behind one guard per release. Each of
the seven release objects defines its own guard and imports the header; the harness's `names-extra.m`
defines all seven and imports it. **One definition of each string in the tree, read eight ways**, rather
than a copy per object that could drift from what the harness proves.

## The four value shapes, and a rule written from the name would get three of them wrong

This is the part worth keeping. The names look like one family and their values are four different
things:

| family | what the value is | an example |
| --- | --- | --- |
| the 29 device-usage category keys | **the string equal to the constant's own name** | `SRDeviceUsageCategoryBooks` → `"SRDeviceUsageCategoryBooks"` |
| the 22 `SRSensor*` identifiers | **an Apple-internal dotted identifier**, not derivable from the name | `SRSensorAccelerometer` → `"com.apple.SensorKit.motion.accelerometer"`; `SRSensorHeartRate` → `"com.apple.SensorKit.heart.rate"` |
| the 6 `SRPhotoplethysmogram*` values | **the SUFFIX of the constant's own name** | `SRPhotoplethysmogramSampleUsageDeepBreathing` → `"DeepBreathing"` |
| — | and two identifiers whose spelling is an abbreviation nothing in the name suggests | `SRSensorElectrocardiogram` → `"com.apple.SensorKit.ECG"`, `SRSensorPhotoplethysmogram` → `"com.apple.SensorKit.PPG"` |

The third family is the dangerous one, because it looks exactly like `#define NAME @"NAME"` — and is not
a macro. That is why these eighteen rows were `absent` until this change: they are const
object-pointer **variables**, so no header spells their value, the release's cache has no SensorKit
symbol to read one from, and a guess had nothing to be checked against. Now there is something: the
host's framework, and a comparison that fails when the guess is wrong.

## Two instrument facts, and both cost a round

  * **These are `const` object-pointer VARIABLES, not functions.** `dlsym` returns the ADDRESS OF THE
    VARIABLE, so the result is dereferenced once. Read straight through it is a pointer to a pointer,
    and the first attempt took SIGBUS — the ImageIO trap, which is why the reader carries a comment
    saying so.
  * **They are not classes.** `SRSensorAccelerometer` and its siblings are `SR_EXTERN SRSensor const
    … API_AVAILABLE(ios(14.0)) API_UNAVAILABLE(watchos, macos)`, an `NSString` constant, and this
    registry's own row says `kind=constant`. Asking the runtime for a class of that name answers 0 of 10
    and says nothing at all about the name; the dlsym path answers all ten with their values.

## What is NOT measured

What an iOS 14 device's SensorKit holds, or any device's. No device has been asked and no emulator run
has been made, and the two could differ; the guest measurement is owed, and no row in
`registry/SensorKit/ios14.json` is a claim about a device — each of the 18 rows says so in its own
`effect`. What IS measured here, for all 57: the host's SensorKit exports the name, and the value it
holds is the one this package defines.

**The reader's control** is `kCFAllocatorDefault`, a CoreFoundation constant VARIABLE read by the same
dlsym-and-deref path, so a reader that had the path wrong would be caught by the control rather than
believed: it prints `matches the host's own symbol`. The comparator's own control is an empty
`HOST` file, which must be red — a comparison of nothing is not a comparison.

**What is deliberately not used here.** `tools/cache-index/first-rung.lua` answers the first held rung
that carries a name, and its ladder has a hole above 12.0, so a `NONE` from it says nothing about a
SensorKit name's release and is not used as such here. What introduced each name comes from the SDK's
own `API_AVAILABLE(ios(...))` on the declaration, and every row's `source` names the header and line.

Open source checked: swift-corelibs-foundation 6.x — not used. What is carried is Apple's own
SensorKit surface, which no permitted project implements, and the values are Apple's own; the only
honest source for them is Apple's framework.