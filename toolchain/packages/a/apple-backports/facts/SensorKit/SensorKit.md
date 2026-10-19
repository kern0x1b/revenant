# SensorKit, on a release that collects nothing

SensorKit arrived in iOS 14. This port deploys to iOS 6.1.3, and the release's armv7 6.1.3 cache
carries **no SensorKit surface at all**: `binary_inventory` at `modules/apple/objc.lua:395`, run over
the cache, finds no `SR*` class and no `SR*` symbol. There is no daemon, no usage database, and no
store a payload could be read out of. Everything below is that one fact and what follows from it.

## The witnesses this page's numbers come out of

**Every row of this family ends its `effect` with the same short clause** - *"Not a device measurement; no
device has been asked and the guest run is owed"* - and that is said once here rather than argued once per
row. It is true of every row of this file: what is measured anywhere in this framework is the HOST's own
SensorKit, the port's own compiled objects and the caches of real releases, and not one device has been
asked anything. The registry held one `absent` row when this page was written and holds none now - the
measurement below is what changed it.

Eight paths, and every count below is one of their outputs. A number on this page that names none of
them is not evidence, and this page used to carry several.

| what it answers | the path | what a run of it prints |
| --- | --- | --- |
| the 57 string constants, the port's against the host's own SensorKit | `tests/backports/host/sensorkit-names/run.sh` | `sensorkit-names: 57 names compared, 0 differing`, then three plants and the empty control |
| the four time functions, both sides in one binary | `tests/backports/host/sensorkit/run.sh` | the three relations, and the port's side `1, 1, 1` |
| which of the delegate's ten the reader sends, what the emitted protocol holds, and both read out of the armv7 object | `tests/backports/host/sensorkit-reader/run.sh` | `4 of 10 protocol methods sent`, `4 of 10 protocol selectors in the object`, `present, 10 optional, 0 required`, 6 plants |
| the deletion-record sensor name, the port's category against the host's | `tests/backports/host/sensorkit-tombstones/run.sh` | `58 inputs compared, 0 differing`, three mutations, the empty control |
| what the host answers for the five value members, and what the port's objects carry | `tests/backports/host/sensorkit-value/run.sh` | the three HOST lines, `5 of 5 accessors`, 5 plants |
| what the host's own eighteen classes do about the `-init`/`+new` pair they close, and what the port's objects carry | `tests/backports/host/unavailable-init/run.sh` | `18 of 18 classes as the table says`, `18 of 18 classes the host's answer`, 4 plants and the control |
| what one cache of one release carries, and what one image of it exports | `modules/apple/objc.lua`, `binary_inventory` at `:395` | the class and symbol inventory of a cache or an image |
| one symbol's release of first appearance, over the held ladder | `tools/cache-index/first-rung.lua` | one TSV line per name, or `NONE` |
| what release the SDK declares a name arrived in | `coordination/corpus/sdk-26.2-surface.tsv`, the `api` and `introduced` columns | 530 SensorKit rows; every one of this family's 35 matches |

**Every `introduced` in this family is checked against the registry's own source**, which is the
`api`/`introduced` pair of `coordination/corpus/sdk-26.2-surface.tsv` - the same file the queue rows
themselves are cut from. Filtered to `framework == SensorKit` it holds **530** rows, and **35 of 35** of
the rows this delivery adjudicated match their own registry entry: 35 matched, 0 mismatched, 0 absent
from the surface. A row's `introduced` means what that file says it means.

**Placement did not move.** `minimums()` in `modules/apple/backports.lua` reads `entry.minimum` and never
`entry.status`, so a row's placement is load-bearing whatever its status says. Across this series the
registry diff adds exactly **one** `minimum` - `6.0`, on the new `SRSensorReaderDelegate` protocol row -
and changes none, so no existing row of this family moved band. **The 4.3 rung has not been gated**: a
placement defect there is invisible at 6.1.3 by construction, and the coordinator runs the gates.

`tools/cache-index/first-rung.lua` answers **presence, not version**, and that limit is load-bearing
here: the ladder it walks (`dyld.held_ladder` in `modules/apple/dyld.lua`) has a hole above 12.0, so a
`NONE` from it for a SensorKit name is not evidence about the release that introduced it and is not
used on this page as such. What introduced a SensorKit name comes from the SDK's own
`API_AVAILABLE(ios(...))` on the declaration, and every row's `source` names the header and the line.

## What is real, and what is not

**The 38 classes are real value objects.** Each is made, and each of its properties is kept in a
store keyed by the property's own name - the store `RevenantValueStore.h` describes and MetricKit already
uses. A property reads back exactly what an application put there, and the archiver walks the same
property list, so a value archived and read back lands under the name it went in under. Nothing in this
framework is measured by the port: there is no sensor to measure.

**The four time functions are real, over the clocks the release actually has**, and one limit is
named rather than papered over. Measured over the cache's 158 520 exports: `mach_absolute_time`,
`mach_timebase_info` and `CFAbsoluteTimeGetCurrent` are all present and **`mach_continuous_time` is
not** - it arrived in iOS 10. So:

- `SRAbsoluteTimeGetCurrent()` reads `mach_absolute_time`, which **stops while the device sleeps**.
  The header promises "This timestamp ticks across sleeps and reboots", and this release cannot keep
  that promise: the clock that would is a symbol it does not have. The reading is still monotonic, so
  it never goes backwards and the two conversions are exact inverses of it.
- the two bases are joined by **one anchor**, read from the release's own `CFAbsoluteTimeGetCurrent`
  the first time it is needed. Neither number is invented: the anchor is a wall-clock reading the
  release produced, and every conversion after it is arithmetic on the two clocks it has.
- `SRAbsoluteTimeFromContinuousTime` takes the nanosecond count its name says and measures it from
  this boot session's anchor, which is the header's own rule about where a continuous time may come
  from. Nothing here can check that a count came from this session, and the code says so rather than
  pretending to.
- the wall-clock pair is the header's stated behaviour: if the system time is five seconds fast, so is
  the answer.

**`SRSensorReader` answers as the SDK documents for a device with no permission, and that is denied.**
Not `notDetermined` - that would promise a prompt still to come, and none is coming, because there is
no store behind the question. Not `authorized` - that would claim data there is not. There is nothing
for a user's answer to be about, and `denied` is what that is. Each of the three ways of asking the
system to collect something is answered with the SDK's *own* failure callback rather than left hanging,
and `+requestAuthorizationForSensors:completion:` **runs** its block with SensorKit's own
`SRErrorDataInaccessible` (read out of the 16.4 `SRError.h`, "Data is not accessible at this time"),
because a caller waiting for a prompt this release never shows would wait forever. `+sharedReader` is
made through `-initWithSensor:`, the only way the header leaves open, with the accelerometer: a reader
for a sensor that exists on some devices and not others, and one that cannot be asked for data either
way. No device list is fabricated.

## The four measurements the build forced, and what follows from them

The lowered **16.4** SDK this package compiles against is four minor versions behind the one this
package develops against, and the gap is the whole reason `RevenantSensorKit.h` exists:

| what the build cannot see | measured how | what the port does |
| --- | --- | --- |
| **19 of the 38 classes** | compiling a probe of all 38 names against the 16.4 headers | declared in `RevenantSensorKit.h` - same superclass, selectors, property types, no ivars, and the availability annotations left out, as the other three redeclarations in this package do |
| **15 of 25 property types** | the same probe, then the header compiled and read for collisions | declared; the other ten, including nine integer enumerations the 26.2 headers spell differently from the 16.4 ones, are left to the SDK |
| **13 properties on 6 classes** | a per-class diff of the two headers' property lists | declared in `(RevenantSensorKitNNN)` categories, one per release, because a class the SDK declares cannot be declared again |
| **4 property types from frameworks this package does not carry** | a probe naming `ARFaceAnchor`, `SNClassificationResult`, `SFSpeechRecognitionResult`, `SampleType` against the build's headers | **declared as `id` and carried, all four**: `SRFaceMetrics.faceAnchor`, `SRSpeechMetrics.soundClassification`, `SRSpeechMetrics.speechRecognition`, `SRFetchResult.sample`. The TYPE is still not here - there is no `ARFaceAnchor`, `SNClassificationResult` or `SFSpeechRecognitionResult` in this package - but the property is, and that is the part that matters: the archiver walks the DECLARED property list, so a property this package does not declare cannot be read back and an archived reading silently loses that field. `SampleType` is a generic parameter rather than a class, which is why `SRFetchResult.sample` was already carried this way and the other three were not; see the section on the five value members |

## The 57 string constants, and why the eighteen newest could not be carried before

All of SensorKit's string constants are **const object-pointer variables**, never macros. `SRSensor`,
`SRDeviceUsageCategoryKey`, `SRPhotoplethysmogramSampleUsage` and
`SRPhotoplethysmogramOpticalSampleCondition` are each a typedef of `NSString *`, and each constant is
declared `SR_EXTERN <type> const <name>` with no initializer anywhere. So no header this package
builds against spells a value, and the release's own cache holds no SensorKit symbol to read one from:
the value has to come from somewhere, and the only honest somewhere is Apple's own framework.

**It is on the host.** `/System/Library/Frameworks/SensorKit.framework` exports every one of them, so
`tests/backports/host/sensorkit-names/run.sh` measures each value rather than writing it down: one
process `dlopen`s the framework and `dlsym`s each name **dereferencing once** - these are variables,
so `dlsym` returns the address of the variable and the address of the variable is the string - and
another process links the port's own definitions and prints those. The two are independent because an
object wins at link time.

A run of it prints:

```
sensorkit-names: 57 names compared, 0 differing
sensorkit-names: 57 names compared, 57 differing      <- the all-wrong plant
the one-wrong plant of SensorKitNames14.m is red and names exactly 1 row: SRDeviceUsageCategoryBooks
the one-wrong plant of RevenantSensorKitNames.h is red and names exactly 1 row: SRSensorSiriSpeechMetrics
sensorkit-names: 0 names compared, 57 differing  <- COMPARED NOTHING   <- the empty-host control
```

Those three plants and that control are what make the comparison falsifiable rather than decorative: a
value that differs is red, a name one side did not print is red, and **a host file with no rows at
all is red**, so a run that compared nothing cannot come out green. There are two one-wrong plants
rather than one because there are two port-side sources now, and a mutation that reached only the
first would leave the second unwatched.

The **57** is `names.txt`, and the count is not the interesting part. The interesting part is the
eighteen that were `absent` before this change and are `implemented` now, in six objects:

**The object a constant lives in is named for the release the HELD LADDER gives it, which is not always
the release the header declares** - and the 6.1.3 gate is what says so:

```
error: 2 objects hold API no single release introduced:
  SensorKitBackports: SensorKit170.m defines SRSensorHeartRate SRSensorOdometer from iOS 16.0 and
    SRAudioLevel ... SRSpeechMetrics SRWristTemperature SRWristTemperatureSession from iOS 17.0 and
    SRSensorFaceMetrics SRSensorWristTemperature from iOS 18.0; an object carries API the same
    release must not hold
```

`modules/apple/backports.lua`'s `check_releases` asks `dyld.first_releases` which **held release first
exports** each symbol. `SRSensors.h` declares all four of those `API_AVAILABLE(ios(17.0))`, and the
registry says `introduced 17.0`, and `sdk-26.2-surface.tsv` agrees - and the ladder answers 16.0 for two
of them and 18.0 for the other two. An object carries the API of one release *as the ladder measures it*,
so the object is named for the measurement and **the header's own date stays what the header says**: no
row's `introduced` moved, and no measurement moved. Re-measuring after the split, over the built armv7
objects, every one of the fifteen reports a single release:

| the object | the ladder's release | what it holds of the constants |
| --- | --- | --- |
| `SensorKit150.m` | 15.0 | `SRSensorSiriSpeechMetrics`, `SRSensorTelephonySpeechMetrics` |
| `SensorKit154.m` | 15.4 | `SRSensorAmbientPressure` |
| `SensorKit160.m` | **16.0** | `SRSensorHeartRate`, `SRSensorOdometer` - *both 17.0 in the header* |
| `SensorKit164.m` | 16.4 | `SRSensorMediaEvents` |
| `SensorKit170.m` | 17.0 | the 17.0 classes; no constants |
| `SensorKit174.m` | 17.4 | the six `SRPhotoplethysmogram...` |
| `SensorKit180.m` | **18.0** | `SRSensorFaceMetrics`, `SRSensorWristTemperature`, `SRSensorElectrocardiogram`, `SRSensorPhotoplethysmogram` - *17.0 and 17.4 in the header* |
| `SensorKit260.m` | 26.0 | `SRSensorAcousticSettings`, `SRSensorSleepSessions` |

What the host's framework holds for them: `com.apple.SensorKit.speechMetrics.siri`,
`...speechMetrics.telephony`, `...ambientPressure`, `...heart.rate`, `...odometer`, `...mediaEvents`,
`SignalSaturation`, `UnreliableNoise`, `ForegroundHeartRate`, `DeepBreathing`, `ForegroundBloodOxygen`,
`BackgroundSystem`, `...faceMetrics`, `...wristTemperature`, `com.apple.SensorKit.ECG`,
`com.apple.SensorKit.PPG`, `...hearing.acousticSettings`, `...sleep.sessions`.

Two of these deserve their own sentence, because they are the cases a rule written from the shape of
the name would have got wrong, and the harness is the only reason they are carried at all:

- **the six photoplethysmogram values are the SUFFIX of the constant's own name, not the name.**
  `SRPhotoplethysmogramSampleUsageDeepBreathing` is the string `DeepBreathing`. They look exactly
  like `#define NAME @"NAME"` constants and are not macros at all, which is why the older version of
  this page refused to guess them: there was nothing to check a guess against. There is now.
- **two of the values are Apple-internal shapes the name does not suggest**: `SRSensorHeartRate` holds
  `com.apple.SensorKit.heart.rate`, and `SRSensorElectrocardiogram` and `SRSensorPhotoplethysmogram`
  hold `com.apple.SensorKit.ECG` and `com.apple.SensorKit.PPG`. The port does not construct these
  strings; it carries what the host's framework holds, and the comparison is what says they are right.

**The values are the HOST's, not a device's.** No iOS device has been asked what its SensorKit holds,
and every row says so in its own `effect`. This is the limit of this measurement and it is a real one.

**Where the values live, and why they are not written six times.** An object carries the API of exactly
one release, so the eighteen belong to six objects; their values, though, are one list, and the
harness has to walk that whole list from a single host-compilable source. They are therefore defined
once, in `RevenantSensorKitNames.h`, behind one guard per release: each release object defines its own
guard and imports the header, and the harness's `names-extra.m` defines all seven and imports it. One
definition of each string in the tree, read eight ways.

## The one method the host answered that no rule could have been derived from

**`-[NSString sr_sensorForDeletionRecordsFromSensor]`**, `SRSensors+SRDeletionRecord.h:15`, iOS 14.0. The
row was `absent` with the reason *"the port adds no category to a Foundation class: it would have to read
a deletion record's sensor, and there is no record to read on this release"*. Both halves of that were
wrong, and the first is contradicted by this framework's own folder: `NSDate+SensorKit14.m` is a category
on `NSString`'s sibling `NSDate` and is the row for `+[NSDate dateWithSRAbsoluteTime:]`. The second
confused the method with the store: it is a string-to-string mapping that reads no record, asks for no
sensor and needs no device.

**The host's own `SensorKit.framework` carries the category and answers it**, over fifty-eight inputs,
and `tests/backports/host/sensorkit-tombstones/run.sh` compares the port's answers to the host's input by
input - two processes, because both sides are a category on `NSString` and one process would have the
port checked against itself. Its own lines:

```
sensorkit-tombstones: 58 inputs compared, 0 differing
sensorkit-tombstones: 58 inputs compared, 26 differing     <- the nil half removed
sensorkit-tombstones: 58 inputs compared, 32 differing     <- the suffix appended twice
sensorkit-tombstones: 58 inputs compared, 31 differing     <- the receiver ignored
sensorkit-tombstones: 0 inputs compared, 58 differing      <- the empty-host control
sensorkit-tombstones: OK - 58 inputs, 2 processes, 3 mutations noticed, the empty control red
```

The rule the host holds is short and is not the obvious one:

- a string that does **not** already end in `.tombstones` -> the string with `.tombstones` appended
- a string that **does** already end in `.tombstones` -> **`nil`**

and it holds for inputs that are not sensor names at all. `""` answers `.tombstones`; `hello` answers
`hello.tombstones`; `tombstones`, which has no leading dot and so is not already suffixed, answers
`tombstones.tombstones`. Case and whitespace are preserved verbatim, so it is a suffix test and not a
lookup table - which is why the twenty-two inputs in the harness are the port's own sensor names and the
thirty-six others are the empty string, words that are not sensors, already-suffixed strings, case
variants and whitespace variants. **The `nil` half is the whole reason the header declares the return
`nullable`**: a deletion record's own sensor name handed back would be a sensor that collects nothing,
and asking twice gives `nil` the second time.

Two instrument facts from building that harness, both of which cost a run:

- **the `dlopen` is load-bearing and its order matters.** Asked *before* `/System/Library/Frameworks/SensorKit.framework`
  is opened, all fifty-eight inputs raise `NSInvalidArgumentException` "unrecognized selector sent to
  instance", because the category lives in the framework and has not been loaded. A harness that forgot
  it would have reported 58 failures and looked like the port disagreeing with the host.
- **`performSelector:` cannot carry an `NSInteger` return.** The first attempt at the counts below went
  through it and printed ten lines of `(nil)` for `wordCountForSentimentCategory:`, which is garbage, not
  an answer - and a garbage number read as zero would have agreed with the port for the wrong reason.

## The five value members, and what the host answers for them

`tests/backports/host/sensorkit-value/run.sh` measures the host once and holds the port to it, then holds
the port twice over - in its source and in its compiled armv7 objects - because a source check alone
passes on a method the compiler never emitted and an object check alone passes on one that returns a
constant. Its own lines:

```
HOST COUNTS   10 categories, every word and emoji count 0: yes
HOST PROPERTY speechRecognition and soundClassification both nil: yes
HOST INIT     RAISES NSInternalInconsistencyException: Use initWithSensor:
sensorkit-value-host: 0 failures
sensorkit-value: 5 of 5 accessors in the source and in the object, 0 failures
sensorkit-value: OK - 5 accessors in the source and in the object, 5 plants noticed
```

| member | the port answers | the host answers |
| --- | --- | --- |
| `-[SRKeyboardMetrics wordCountForSentimentCategory:]` | the count in the store, `0` when none | **`0`**, for all ten categories |
| `-[SRKeyboardMetrics emojiCountForSentimentCategory:]` | the count in the store, `0` when none | **`0`**, for all ten categories |
| `SRSpeechMetrics.speechRecognition` | the value in the store, `nil` when none | **`nil`** |
| `SRSpeechMetrics.soundClassification` | the value in the store, `nil` when none | **`nil`** |
| `SRFaceMetrics.faceAnchor` | the value in the store, `nil` when none | **no oracle**: it declares the property and does not implement it, so sending it raises |

Zero and nil are the SDK's own answers, and for the two counts that matters: a count of nothing typed in
a category is **zero**, not nil and not an error. The port invents no classification of a keyboard
session - a count is whatever an application archived under the key, which is the selector and the
category together, because a count per category is ten numbers and one key per method would hold one of
them.

**Two of the five plants survived the first version of this harness and the check was fixed rather than
the plants.** A count that answered a constant `7`, and a count whose key had forgotten the category so
that all ten answered the same number, both passed a check that only asked whether the method existed and
used `longLongValue`. `check_values.lua` now checks the three things that make the key right - that the
selector is in it, that the category is in it, and that both reach the string - and the run says
`2 plants survived; this check proves nothing` when it does.

**`SRFaceMetrics.faceAnchor` has no oracle, and the row says so rather than implying one.** A face
reading needs the TrueDepth camera, and this fleet has no device with one: the iPhone 4S and the iPad 2
have no sensor of that kind at all. The port carries it anyway, as `id`, because the archiver walks the
declared property list - a property this package does not declare cannot be read back, and an archived
reading would silently lose the field that ties a face reading to the camera frame it came from.

## The pair every class closes: `-init` and `+new`, and what the framework does about them

Eighteen of this framework's classes declare the pair unavailable in their own SDK 26.2 header, each in
the last two lines before its `@end` - `SRSensorReader.h:98` and `:99` for the reader,
`SRDeviceUsageCategories.h:67` and `:68` for SRSupplementalCategory, and the same two lines in each of
the other sixteen. `NS_UNAVAILABLE` is a promise about **source**: it is `__attribute__((unavailable))`,
a compile-time diagnostic that adds nothing to behaviour. So what a caller reaches at run time is a
separate question, and the corpus row is a third one - whether the selector is in **the class's own**
method list, which an inherited selector is in no class's.

All three were measured on the host's own `SensorKit.framework`, over all eighteen classes, by
`tests/backports/host/unavailable-init/`. Its `expectations.tsv` is the transcription and its own lines:

```
sensorkit-init-host: 18 of 18 classes as the table says, 0 failures
sensorkit-init-port: 18 of 18 classes the host's answer, in the source and in the object, 0 failures
sensorkit-init: OK - 18 classes against the host's answer, 4 plants noticed, the control red
```

**Fourteen of the eighteen classes implement both and both raise `NSInternalInconsistencyException`**,
and the reason string is per class and is Apple's own: `"Not available"` for the four that have no other
door (SRFaceMetrics, SRFaceMetricsExpression, SRFetchResult, SRSupplementalCategory), `"Use
initWithSensor:"` for SRSensorReader, which has one, and **a reason of zero length** for the other nine.
`+new` is `+alloc`/`-init`, so one raise answers both rows.

**Four implement neither** - SRAcousticSettings, SRSleepSession, and the two photoplethysmogram samples
that are channels of the sample their parent already guards - so a caller that reaches the pair reaches
NSObject's and gets a new empty value object. **The port gives those four no definition at all**, and
that is the rule the coordinator settled on the same day for the classes that only inherit
(`coordination/wave-2026-10-03/QUEUE.md`, the answer to v-audio): a definition would put the selector in
the port's class metadata where Apple's has neither, which changes what the class IS and answers the
caller exactly what NSObject's already answers. Their eight registry rows are `absent` with this
measurement as the reason, the way v-metal's five MetalKit rows are.

**What iOS itself holds, measured over the arm64e cache of iOS 16.0** with
`tools/corpus/objc-inventory.lua` - the newest held cache that still carries SensorKit's classes as
exports (`_OBJC_CLASS_$_SRSensorReader` and `_OBJC_CLASS_$_SRFetchResult` are both in it, and neither is
in the cache of 18.0, where SensorKit's public classes are no longer exported at all):

| class | iOS 16.0's own lists | the host's own lists | at run time |
| --- | --- | --- | --- |
| `SRSensorReader` | `-init` and `+new` | both | raises, `"Use initWithSensor:"` |
| `SRFetchResult` | `-init`, and `+new` inherited | both | raises, `"Not available"` |

That table is also why the rule is per selector and not per class: Apple's SensorKit classes define both
selectors and Apple's HealthKit classes define `-init` while inheriting `+new`, so one rule for "the
class" would answer one framework right and the other wrong.

That is the one place the two disagree, and it is a difference about **where** the implementation sits,
not about what a caller sees: an inherited `+new` is `+alloc`/`-init`, so on iOS 16.0 `+[SRFetchResult
new]` reaches the same `-init` and raises the same exception. The port carries both selectors, so both
its rows are answered by the class's own list, and both raise what iOS raises.

**The two copies that could not go through `-init`.** `SRFetchResult` and `SRSupplementalCategory` are
the two of the fourteen the port gives a `-copyWithZone:`, and a copy is a new object, so it cannot be
made by a `-init` that raises. Both take a door the class keeps for itself,
`-initWithRevenantValues:` - a name no SDK header declares, registered as the `revenant_` row the shape
`registry/MetalPerformanceShadersGraph/graph.json` uses, and written once in `RevenantValueStore.h`'s
`REVENANT_VALUE_COPY_INITIALISER` so that there is one spelling of the copy rule in the package.

**`-[SRSensorReader init]` was `absent` until this measurement, and the reason it gives for staying that
way is now answered.** It said: *"`+[SRSensorReader new]` is already an `implemented` entry in this same
file, and `+new` calls `-init`, so implementing `-init` to raise would change what that row answers."* That
is right about the consequence and wrong about the conclusion: the host says `+new` raises too, so the
change makes both rows answer what the framework answers. It is `implemented` now, with the host's own
exception and the host's own reason string.

**What this is not.** The host is not a measurement of iOS: the two caches above cover two of the
eighteen classes, and the framework is the same family rather than the same binary - under Mac Catalyst
`SRSensorReader` is declared and implements nothing at all, which `SRSensorReader.m`'s own header
comment records. A device run would be the iOS measurement proper, and it is the one thing this harness
cannot do: the port's own configuration is a cross-compile for `armv7-apple-ios6.1.3`.

## What the delegate's ten methods are, and which four the port reaches

**There are ten of them, all `@optional`, and the port's reader sends four.** That is the whole shape
of this corner, and the numbers are the SDK 26.2 header's own: `@protocol SRSensorReaderDelegate
<NSObject>` at `SRSensorReader.h:21`, `@optional` at `:22`, and ten declarations between `:40` and
`:84`, the protocol's `@end` at `:86`.

`tests/backports/host/sensorkit-reader/run.sh` is what produces that split, twice over, and its own
output is the claim:

```
sensorkit-reader: 4 of 10 protocol methods sent, 0 failures
sensorkit-reader-object: 4 of 10 protocol selectors in the object, 0 failures
sensorkit-reader: OK - 10 protocol methods, 4 sent and 4 in the object, 5 plants noticed
```

The first line reads the port's own `SRSensorReader.m` and names all ten, SENT or NEVER. The second reads
the **compiled armv7 object** - built `armv7-apple-ios6.1.3` against the 16.4 SDK and dumped with
`otool -v -s __TEXT __objc_methname` - and is a different claim: an object's `__objc_methname` is what
the linker binds `@selector()` references against, so a selector in that section is one the reader can
actually send. Both halves have plants: three change the source (a send removed, a send swapped for one
of the six, the authorization no longer `denied`), a fourth hands the check a reader that sends nothing
at all, and a fifth is the swap again carried through the compiler, so the object check is not merely
agreeing with the source check by construction. All five are noticed.

**Why this is not a differential, and that is measured rather than assumed.** There is no behavioural
oracle for `SRSensorReader` on this machine. The host's own `SensorKit.framework` declares the class and
implements nothing - `respondsToSelector:` is 0 for `+authorizationStatus` and `+sharedReader` - and the
port's `RevenantSensorKit.h` cannot be compiled against the host's newer SDK at all: clang answers
`typedef redefinition with different types ('NSInteger' vs 'enum SRAcousticSettingsSampleLifetime')`
for the fifteen enumerations it redeclares, because the host's SensorKit spells them `NS_ENUM`. Building
the port's reader for Catalyst against the 16.4 SDK instead was tried and does not work either, on this
SDK: `Foundation/NSURL.h:10` imports `Foundation/NSURLHandle.h`, which the store's 16.4 SDK does not
carry.

The four, and the six, are these:

| sent by the port's reader | from | why it is the answer |
| --- | --- | --- |
| `sensorReader:startRecordingFailedWithError:` | `-startRecording` | there is no store to start recording into |
| `sensorReader:stopRecordingFailedWithError:` | `-stopRecording` | nothing is recording, so this is a stop that did not happen |
| `sensorReader:fetchingRequest:failedWithError:` | `-fetch:` | no store, no readings, no payload |
| `sensorReader:fetchDevicesDidFailWithError:` | `-fetchDevices` | the device list is the one fetch that could succeed without a database, and the port will not invent one |

Each of the four carries SensorKit's own `SRErrorDomain` and its own `SRErrorDataInaccessible` from
`SRError.h` - "Data is not accessible at this time", which is exactly what is true here - and each is
guarded by `respondsToSelector:` on the delegate, so a subscriber that implements one is messaged and
one that does not is not messaged at all, never messaged wrongly.

| never sent, and `implemented` as the answer | why the real system sends nothing here |
| --- | --- |
| `sensorReader:fetchingRequest:didFetchResult:` | it hands over a result and `-fetch:` has none: the request fails instead |
| `sensorReader:didCompleteFetch:` | it says a fetch finished, and no fetch in this port ever does |
| `sensorReader:didChangeAuthorizationStatus:` | `-authorizationStatus` answers `SRAuthorizationStatusDenied` and nothing writes to it, so there is no change to report |
| `sensorReaderWillStartRecording:` | it says a recording is about to begin, and none ever does |
| `sensorReaderDidStopRecording:` | it says a recording stopped, and `-stopRecording` answers with the failure callback because there was never a recording |
| `sensorReader:didFetchDevices:` | it hands over a device list, and the port will not fabricate one |

Every one of the six is `@optional`, so a conformer may leave it out and the compiler accepts that. A
conformer that implements one is never called, which is the SDK's own behaviour on a device that collects
nothing - **the port does not fabricate a result, a device list or a status change to make a callback
fire**, and that is the line every one of those six rows rests on. Each row's `reason` carries its own
mechanism and each one's `source` names the harness that measured the absence.

**Those six are `implemented`, because the real system does nothing for them on this device.** The
registry's README lets a row be `implemented` when the real system does nothing on a device without the part,
with facts that say so. Each of the six is documented by the SDK as a callback for a success or a change:
`sensorReader:didCompleteFetch:` after a fetch has completed successfully, `sensorReader:fetchingRequest:didFetchResult:`
once for each result, `sensorReader:didFetchDevices:` as the success of `-fetchDevices`, and
`sensorReader:didChangeAuthorizationStatus:` when the status has changed (SRSensorReader.h, the doc comment on
each declaration). The port fails or refuses every request that would produce one of those, and sends the failure
the SDK gives for it, so none of the six is ever sent. The four failure callbacks are the ones the reader sends.

The two recording callbacks rest on a reading, which is not a measurement. The header says
`sensorReaderWillStartRecording:` and `sensorReaderDidStopRecording:` come "after" a request to start or stop, and
does not say whether a refused request is announced before the failure. The port reads a refused request as not
announced. The reading is named here so a later check can overturn it; the registry rows say the same.

Why `implemented` and not `owed`: an owed row would claim the port will build the callback, and the port will not
build one that a success would send, because a success does not occur on this device. The owed status would
keep the six red forever and hide that they are answered.

**The protocol itself is now carried, and it is the header that had to be real.** The delegate is the
application's own object, so nothing in the port adopts `SRSensorReaderDelegate` - which is why the port
emitted no `__OBJC_PROTOCOL_$_` for it at all, and an application compiled against the SDK found no such
protocol on the device. `RevenantSensorKitProtocols.h` declares it and the object
`modules/apple/backports.lua` generates from the registry row, `SensorKitBackportsProtocols14.0.m`, makes
clang emit the metadata.

**Three things about that were measured, and two of them were wrong first.**

- **A forward declaration emits the protocol and leaves it EMPTY.** Measured by taking
  `@protocol(SRSensorReaderDelegate)` into a `Protocol *` and counting method descriptions: with the
  header forward-declared the protocol is found and carries **0** optional methods; with the ten members
  declared it is found with **10** optional and **0** required. An application asking
  `[objc_getProtocol("SRSensorReaderDelegate") conformsToSelector:@selector(sensorReaderWillStartRecording:)]`
  got a NO for a method its own class implements - and each of the ten member rows would have been a
  promise with nothing behind it. The port's first version of this header forward-declared, and its own
  comment claimed the opposite. `tests/backports/host/sensorkit-reader` now counts the emitted metadata
  from the same generated file the build compiles, and its plant forwards the protocol to turn the count
  to zero:
  `sensorkit-protocol: present, 10 optional, 0 required, 0 failures` and, for the plant,
  `present, 0 optional, 0 required, 1 failures`.
- **The probe has to USE what it measures.** The first version put `(void)@protocol(X)` in a `static`
  function `main` never called; the linker dead-stripped it and the probe printed `protocol ABSENT` for
  **both** shapes - a confident wrong answer about a port that emits the protocol perfectly well. This is
  the third time in this family a runtime answer was read off something that was not there (the
  `objc_getClass` "0 of 10" in slice 1, and `class_getInstanceMethod` finding an instance method where a
  class method lived). A probe must hold the thing it measures.
- **The header must NOT import `<SensorKit/SensorKit.h>`.** Measured on the generated object's own compile
  for `armv7-apple-ios6.1.3` against the 16.4 SDK: with the umbrella in scope clang reports
  `duplicate protocol definition of 'SRSensorReaderDelegate' is ignored [-Wduplicate-protocol]` and uses
  **Apple's** declaration, so the metadata emitted would carry references into a framework this release
  does not have. The header therefore declares four `@class` lines and one untyped
  `typedef NSInteger SRAuthorizationStatus` - the same shape `RevenantSensorKit.h` uses for its fifteen
  enumerations - and compiles with no diagnostic and **no undefined reference into SensorKit**, read back
  with `nm -u`.

**What is still not claimed.** That a device reaches a subscriber. The call test on the emulator has not
been run; what is proven here is that the armv7 object carries the four selectors, the source sends
exactly those four, and each carries SensorKit's own error.

## The four shapes in the source, each forced by something measured

- a class is implemented in the class itself, **except** `SRKeyboardMetrics`, which the SDK declares
  over four categories of its own: a property one of those declares can be neither `@dynamic`-able in
  a category of ours (the name would be declared twice on the class) nor implemented in a class
  implementation, so its 69 such accessors are written out by hand and only the five the class declares
  are `@dynamic`;
- a property the header declares in a category is implemented in that category;
- a property of a class the port *owns* has its class's `@dynamic` name every property the header
  declares for it, whichever release it arrived in - otherwise the compiler auto-synthesises the
  missing ones, and a synthesised getter on a store-backed class reads an ivar nothing ever writes;
- a struct-valued property (`CMTimeRange`, a chromaticity) is an `NSValue` over its own bytes, since
  it can be neither cast out of the store the way an object can nor put in a dictionary.

**Eight properties carry a getter of their own, and that is measured, not a naming choice.** Apple's
`SRAcousticSettings.h` declares them with the property's own name and the `is...` form as the getter -
lines 65, 75, 91, 115, 132, 145, 195 and 225 - so the selector the release's class carries is not the
one the property is spelled with:

| property | getter the release declares |
| --- | --- |
| `SRAcousticSettings.environmentalSoundMeasurementsEnabled` | `isEnvironmentalSoundMeasurementsEnabled` |
| `SRAcousticSettingsAccessibility.monoAudioEnabled` | `isMonoAudioEnabled` |
| `SRAcousticSettingsAccessibilityBackgroundSounds.enabled` | `isEnabled` |
| `SRAcousticSettingsAccessibilityBackgroundSounds.playWithMediaEnabled` | `isPlayWithMediaEnabled` |
| `SRAcousticSettingsAccessibilityBackgroundSounds.stopOnLockEnabled` | `isStopOnLockEnabled` |
| `SRAcousticSettingsAccessibilityHeadphoneAccommodations.enabled` | `isEnabled` |
| `SRAcousticSettingsMusicEQ.lateNightModeEnabled` | `isLateNightModeEnabled` |
| `SRAcousticSettingsMusicEQ.soundCheckEnabled` | `isSoundCheckEnabled` |

`RevenantSensorKit.h` said none of that, so the port carried `-soundCheckEnabled` and seven more of the
same shape: a selector the release's class does not have, and none of the eight it does. The header now
declares each getter, and the accessor is `REVENANT_SCALAR_GETTER(Type, name, getter)` - both spellings,
because the name is what the store is keyed by and what a caller writes, and the getter is the selector
that goes into the class's own method list. The property rows in `registry/SensorKit/ios14.json` are
unchanged by this: a property row names the property, and the property kept its name.

Measured on the object this produces, with the repository's own reader
(`tools/corpus/objc-inventory.lua` over an armv7 build of `SensorKit/SensorKit260.m`): the five classes
carry `-isEnvironmentalSoundMeasurementsEnabled`, `-isMonoAudioEnabled`, `-isEnabled`,
`-isPlayWithMediaEnabled`, `-isStopOnLockEnabled`, `-isLateNightModeEnabled` and `-isSoundCheckEnabled`
between them, and none of the eight property-name selectors.

Six classes the SDK's own headers declare as conforming - `SRDeletionRecord`, `SRDevice`,
`SRMediaEvent`, `SRSupplementalCategory`, `SRFetchRequest`, `SRFetchResult` - carry the three archiving
methods and, where the header says `NSCopying`, `-copyWithZone:`. The obligation is in each class's
own implementation, not in a category: a category *may* satisfy a protocol, but clang checks the primary
class for it, and that is also where a contract belongs.

## The one thing this framework shares with another

`RevenantValueStore.h` - the property walk, the conversion table, the archiver walk and the store. Its
recognition test is **"a class that answers `revenant_valueForKey:` is one of ours"**, because
SensorKit has thirty-eight value classes and MetricKit has two, every one of both an `NSObject`
subclass: there is no common superclass left to name, and the accessor the store adds is the test both
frameworks already have.

## Not measured, and what a differential could hold

**The host's SensorKit is in the host's SDK, and under Mac Catalyst the `SRSensorReader` class is
declared - and implements nothing.** `respondsToSelector:` is 0 for both `+authorizationStatus` and
`+sharedReader`, and sending either raises `unrecognized selector`. So there is **no oracle for the
reader**: its answers cannot be held to anything but the header, and this file says so rather than
claiming a comparison that is not possible.

What the host *does* answer is the four time functions, and that is the differential that exists
(`tests/backports/host/sensorkit`): one binary carries both, the port's four renamed, and three
relations from the header are asked of each - never backwards, the pair naming the same instant as
`CFAbsoluteTimeGetCurrent` within a second, and the round trip within a microsecond. Two mutations of
the port's file must each change a record.

Two things the host's own answers measured, which is why those relations are the ones chosen:

- **the round trip is not bit-exact, on the host either.** Its measured drift is `1.162e-07` seconds,
  and that is not a defect: an `SRAbsoluteTime` is a `CFTimeInterval`, and a double near 8e8 cannot
  resolve better than about 120 ns. A value that comes back within a microsecond came back exactly as
  far as these clocks can tell, which is all the header claims.
- **two readings in a row may be equal.** The host's own do it, for the same 120 ns. So the relation
  is "never less", and a third reading after a nap must be greater - which both halves satisfy.

**The device call test has not been run.** It would be the one thing that could catch a mistake in the
store's key for a property, and the delivery says so.

**The `NSDate(SensorKit)` category is the same clock on the other side, and its three rows are carried.**
`+[NSDate dateWithSRAbsoluteTime:]`, `-[NSDate initWithSRAbsoluteTime:]` and `NSDate.srAbsoluteTime` are
three wrappers over the two conversions this file already measures - `SRAbsoluteTimeToCFAbsoluteTime` and
`SRAbsoluteTimeFromCFAbsoluteTime`, each the other's inverse through the one anchor - so nothing new is
computed and the numbers are the ones the time functions already answer. The header's declaration is in
`SensorKit.framework/Headers/NSDate+SensorKit.h` of the SDK 16.4, and `SRAbsoluteTime` is
`CFTimeInterval` (`SRAbsoluteTime.h:14`).

`tests/backports/host/sensorkit` now asks three more relations of **both** builds - the round trip through
the two instance methods within a microsecond, a date and the clock agreeing within a second, and two
dates made from two readings never in the wrong order - and the port's side answers 1, 1, 1 on six
consecutive runs.

**A measurement of mine that was wrong, and what it cost.** A probe I wrote to see whether the host's own
build has `+[NSDate dateWithSRAbsoluteTime:]` answered **no**, and I built the comparator on it as an
expected difference. The suite said otherwise: the host has all three. The probe used
`class_getInstanceMethod`, which finds an **instance** method - the class method lives on the metaclass,
so the probe could not see it. That is the second time in these two families a runtime lookup answered a
question it was not asked (`SRSensor*` "0 of 10" from `objc_getClass`, in slice 1). The expected
difference is gone and both sides are held to the same three relations.

**The host's account of that surface, measured through the runtime rather than assumed:**
`SRSensorReaderDelegate` is present on the host and declares **exactly ten** methods, all `optional`,
with the type encodings `v24@0:8@16`, `v32@0:8@16q24`, `v32@0:8@16@24` (x3), `B40@0:8@16@24@32`,
`v40@0:8@16@24@32` and `v24@0:8@16` - so the surface is Apple's and it is exactly the ten rows above.
What this page used to conclude from it - that the port's not declaring the protocol is the measured
right answer - is no longer what the tree does: the protocol is carried now, and the ten are split four
sent and six never sent, each row saying which. The one row of the reader's own surface still `absent`
is `-[SRSensorReader init]`, and the section above says why.

**And the host's relation `roundTripWithinAMicrosecond` is flaky**, which is why the numbers above are
"on six consecutive runs" and not "always": the HOST's own round trip failed once in eight runs of this
suite (`DIFFERS the host's does not satisfy roundTripWithinAMicrosecond ('0')`). The relation is
pre-existing and the host's own; this slice neither added it nor relaxed it, and it is named here
because a gate that runs this suite may catch it red for a reason that is not the port's.

Open source checked: swift-corelibs-foundation 6.x - not used. The arithmetic is Foundation's own
`NSTimeInterval` read through this package's existing conversion pair, and the surface is Apple's.
