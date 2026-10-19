# The sixteen rows of iOS 8.0's corpus this group registers, and what each one is measured to be

Sixteen rows of `registry/HealthKit/ios8.json` were registered by this group. Eight of them, the `-init`
methods of the classes whose SDK header marks them unavailable, are measured at run time and are
`implemented` now (section 4). The other eight stay `absent`: the four workout-session methods of `HKHealthStore`
and the four states-of-mind predicates of `HKQuery`, measured in section 2 and section 3.

The `-init` answers in section 4 come from a run on the macOS host (`tests/backports/host/init-inherited/host.sh`).
That host has HealthKit, and the run asks the host's class and the port's class the same question in one
process. An earlier draft of this file read the refusal out of the iOS 8.0 image and its branch. That reading
is withdrawn: nothing in section 4 rests on disassembly.

**The reader, and its control, once.** Every path in the output quoted below is written `$HOME` where
the run prints this machine's own home; the run prints the absolute cache it read, and that is the one
thing in it a repository may not carry. Sections 1 to 3 are read by

```
CHARON_ROOT="$PWD" xmake l packages/a/apple-backports/facts/HealthKit/rows-code-map.lua 8.0 6.1.3 4.3 9.0 18.0
```

through `modules/apple/objc.lua`'s `code_map()`, which gives every method a rung declares as
`{owner, is_class_method, selector, imp, category}` - so an answer can say **which class** declares a
selector, whether it is a class method, and whether the class declares it of its own or a category adds
it. `objc.inventory()` cannot: its `method_list()` keys *both* of a class's method lists with a leading
`-` and nothing says whether an entry came from the class or from a category. That is not a
hypothetical: a first differential built on `inventory()` answered `no` for all sixteen owners **and
`no` for all sixteen controls**, and could not tell a real zero from a blind reader, so it reported
`CONTROL FAILED` and no row was written from it. The count beside every answer in the output is that
control, and the last line of each rung says what it was:

```
== 8.0  armv7  $HOME/.charon/dyld/8.0/dyld_shared_cache_armv7
   812 images, 380422 methods
   +HKQuery                predicateForStatesOfMindWithValence:operatorType:  own-methods-of-owner=54     NOT DECLARED BY THIS CLASS
   +HKQuery                predicateForStatesOfMindWithKind:               own-methods-of-owner=54     NOT DECLARED BY THIS CLASS
   +HKQuery                predicateForStatesOfMindWithLabel:              own-methods-of-owner=54     NOT DECLARED BY THIS CLASS
   +HKQuery                predicateForStatesOfMindWithAssociation:        own-methods-of-owner=54     NOT DECLARED BY THIS CLASS
   -HKHealthStore          startWorkoutSession:                            own-methods-of-owner=95     NOT DECLARED BY THIS CLASS
   -HKHealthStore          endWorkoutSession:                              own-methods-of-owner=95     NOT DECLARED BY THIS CLASS
   -HKHealthStore          pauseWorkoutSession:                            own-methods-of-owner=95     NOT DECLARED BY THIS CLASS
   -HKHealthStore          resumeWorkoutSession:                           own-methods-of-owner=95     NOT DECLARED BY THIS CLASS
   -HKObject               init                                            own-methods-of-owner=24     own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKObjectType           init                                            own-methods-of-owner=28     own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKQuantity             init                                            own-methods-of-owner=15     own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKSource               init                                            own-methods-of-owner=28     own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKStatistics           init                                            own-methods-of-owner=38     own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKStatisticsCollection init                                            own-methods-of-owner=21     own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKCategorySample       init                                            own-methods-of-owner=11     own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKWorkoutEvent         init                                            own-methods-of-owner=15     own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   anywhere predicateForStatesOfMindWithValence:operatorType:  no class in this rung
   anywhere startWorkoutSession:                            no class in this rung
   anywhere endWorkoutSession:                              no class in this rung
   anywhere pauseWorkoutSession:                            no class in this rung
   anywhere resumeWorkoutSession:                           no class in this rung
   control: every owner class this rung holds declares methods of its own
```

`own-methods-of-owner=54` is the control reading out loud: HKQuery *does* declare 54 methods of its own
in that cache, so a `no` beside it is about the selector and not about the reader. The eight `-init` rows
are in the same table for completeness - they are the subject of section 4.

## 1. Both band ends

`modules/apple/backports.lua`'s `band_ranges()` checks a band against the **first and last release of
its range**, so the 8.0 band is checked against the port's deployment release and against the last held
release before the next band point. Neither carries any of these sixteen names, and neither carries the
framework at all:

```
== 6.1.3  armv7  $HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7
   524 images, 206216 methods
   ... all sixteen: NOT DECLARED BY THIS CLASS, own-methods-of-owner=0
   anywhere <each of the eight selectors>  no class in this rung
   this rung holds none of: HKCategorySample, HKHealthStore, HKObject, HKObjectType, HKQuantity, HKQuery,
                            HKSource, HKStatistics, HKStatisticsCollection, HKWorkoutEvent
```

and the same for 4.3 (354 images, 123684 methods). That last line is the honest form of the zero on
those two rungs: **the ten owner classes are not there**, which is a different statement from "this
reader cannot see them", and the tool now says which of the two it is instead of printing a control that
is vacuously true when no class was found at all.

## 2. The four states-of-mind rows: iOS 18's, and 18.0 is the only rung that has them

`+[HKQuery predicateForStatesOfMindWithValence:operatorType:]`, `-predicateForStatesOfMindWithKind:`,
`-predicateForStatesOfMindWithLabel:` and `-predicateForStatesOfMindWithAssociation:`. The SDK header
leaves all four unannotated, inside `@interface HKQuery (HKStateOfMind)`, so the corpus dated them from
the class - its `via=class-floor` - and filed them under 8.0. They are not 8.0's, and the old reason
("no release from 8.0 to 10.0 carries it") named a range where a measurement names an owner.

```
$ xmake l tools/cache-index/first-rung.lua --rungs predicateForStatesOfMindWithKind:
predicateForStatesOfMindWithKind:	18.0

$ xmake l tools/cache-index/first-rung.lua --rungs HKStateOfMind
HKStateOfMind	18.0
```

18.0 is the **first and the only** held rung carrying any of the four, and `rows-code-map.lua` says who
declares them there:

```
== 18.0  arm64e  $HOME/.charon/dyld/18.0/dyld_shared_cache_arm64e
   3692 images, 2896455 methods
   +HKQuery                predicateForStatesOfMindWithValence:operatorType:  own-methods-of-owner=155    own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   +HKQuery                predicateForStatesOfMindWithKind:               own-methods-of-owner=155    own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   +HKQuery                predicateForStatesOfMindWithLabel:              own-methods-of-owner=155    own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   +HKQuery                predicateForStatesOfMindWithAssociation:        own-methods-of-owner=155    own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   anywhere predicateForStatesOfMindWithValence:operatorType:  +HKQuery predicateForStatesOfMindWithValence:operatorType: [own]
   control: every owner class this rung holds declares methods of its own
```

**`own`, not a category** - worth saying, because the release-split script's own blind-spot note is that
a category's methods compile to no nm-visible symbol and a category is the usual reason a method list
cannot be attributed. These four are HKQuery's own. And they are absent from 8.0, from 9.0 (HKQuery
declares 75 methods of its own there and not these), and from every rung in between: the reader above
reports `no class in this rung` for all four on 8.0 and 9.0.

## 3. The four workout-session rows: watchOS's surface, and the strings are in iOS caches anyway

`-[HKHealthStore startWorkoutSession:]`, `-endWorkoutSession:`, `-pauseWorkoutSession:`,
`-resumeWorkoutSession:`. The header settles what they are, one line each
(`System/Library/Frameworks/HealthKit.framework/Headers/HKHealthStore.h`, lines 305, 314, 323, 332):

```
- (void)startWorkoutSession:(HKWorkoutSession *)workoutSession API_DEPRECATED("Use HKWorkoutSession's start method", watchos(2.0, 5.0)) API_UNAVAILABLE(ios, macCatalyst, macos);
- (void)endWorkoutSession:(HKWorkoutSession *)workoutSession API_DEPRECATED("Use HKWorkoutSession's end method", watchos(2.0, 5.0)) API_UNAVAILABLE(ios, macCatalyst, macos);
- (void)pauseWorkoutSession:(HKWorkoutSession *)workoutSession API_DEPRECATED("Use HKWorkoutSession's pause method", watchos(3.0, 5.0)) API_UNAVAILABLE(ios);
- (void)resumeWorkoutSession:(HKWorkoutSession *)workoutSession API_DEPRECATED("Use HKWorkoutSession's resume method", watchos(3.0, 5.0)) API_UNAVAILABLE(ios);
```

Two are **of watchOS 2.0** and two of **watchOS 3.0**, all four **deprecated from watchOS 5.0**, all four
`API_UNAVAILABLE(ios)`. That is more than the rows said: the old reason was "the watch application and
app extensions both arrived after this release", which is true and says nothing about which release the
API belongs to.

**And the strings are in iOS caches, which is why the reason was rewritten instead of trusted.** A
selector's rung says nothing about its own owner, so both questions were asked:

```
$ xmake l tools/cache-index/first-rung.lua startWorkoutSession: endWorkoutSession: pauseWorkoutSession: resumeWorkoutSession: HKWorkoutSession
startWorkoutSession:	9.0
endWorkoutSession:	9.0
pauseWorkoutSession:	10.0.1
resumeWorkoutSession:	10.0.1
HKWorkoutSession	9.0

$ xmake l tools/cache-index/first-rung.lua --rungs startWorkoutSession:
startWorkoutSession:	9.0,9.0.2,9.1,9.2,9.2.1,9.3,9.3.5,9.3.6,10.0.1,10.1.1,10.2,10.2.1,10.3,10.3.1,10.3.2,10.3.3,10.3.4,11.0,12.0,16.0,18.0
```

**Control for this reader, in the same run**, because a `NONE` and a broken index look the same:

```
$ printf '%s\n' predicateForObjectsFromWorkout: predicateForSamplesWithStartDate:endDate:options: \
      zzNoSuchCharonSelectorControl: | xmake l tools/cache-index/first-rung.lua
predicateForObjectsFromWorkout:	8.0
predicateForSamplesWithStartDate:endDate:options:	8.0
zzNoSuchCharonSelectorControl:	NONE
```

Two HealthKit class methods of 8.0 read 8.0 and a nonsense name reads `NONE`, so the index sees
HealthKit's own selectors and the rungs above are the ladder's and not the reader's.

So the absence is **not** "the image has no such string". `rows-code-map.lua` says which class, on
which rung:

```
== 9.0  armv7  $HOME/.charon/dyld/9.0/dyld_shared_cache_armv7
   905 images, 515998 methods
   -HKHealthStore          startWorkoutSession:                            own-methods-of-owner=155    own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKHealthStore          endWorkoutSession:                              own-methods-of-owner=155    own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKHealthStore          pauseWorkoutSession:                            own-methods-of-owner=155    NOT DECLARED BY THIS CLASS
   -HKHealthStore          resumeWorkoutSession:                           own-methods-of-owner=155    NOT DECLARED BY THIS CLASS
   anywhere startWorkoutSession:                            -HKHealthStore startWorkoutSession: [own]
   anywhere pauseWorkoutSession:                            no class in this rung
   control: every owner class this rung holds declares methods of its own

== 18.0  arm64e  $HOME/.charon/dyld/18.0/dyld_shared_cache_arm64e
   -HKHealthStore          pauseWorkoutSession:                            own-methods-of-owner=283    own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   -HKHealthStore          resumeWorkoutSession:                           own-methods-of-owner=283    own in /System/Library/Frameworks/HealthKit.framework/HealthKit
   anywhere endWorkoutSession:                              -CMWorkoutManager endWorkoutSession: [own], -HKHealthStore endWorkoutSession: [own]
   control: every owner class this rung holds declares methods of its own
```

Three facts out of that, each of which the old reason did not have:

1. **8.0 has none of the four.** Its `HKHealthStore` declares 95 methods of its own and not one of
   these, and no class of the 8.0 cache declares them anywhere. So this file, the surface of 8.0, is
   right that they are not 8.0's - and it is now measured rather than asserted.
2. **`startWorkoutSession:` and `endWorkoutSession:` are 9.0's**, HKHealthStore's own from that rung.
   **`pauseWorkoutSession:` and `resumeWorkoutSession:` are 10.0.1's** - 9.0 does not have them at all,
   on any class. The four are therefore two releases apart and the rows now say which is which, where
   before all four shared one sentence.
3. **`-endWorkoutSession:` has a second owner.** In 18.0 `CMWorkoutManager` declares it too, which is
   the concrete case of the rulebook's warning that a selector's rung is not an owner: a first-rung
   answer of 9.0 for `endWorkoutSession:` says nothing about whether it is HealthKit's.

## 4. The eight `-init` rows: measured at run time, and implemented

The eight rows are `-[HKCategorySample init]`, `-[HKObject init]`, `-[HKObjectType init]`, `-[HKQuantity init]`,
`-[HKSource init]`, `-[HKStatistics init]`, `-[HKStatisticsCollection init]` and `-[HKWorkoutEvent init]`. Each
of the eight carries an `-init` of its own in the iOS 16.0 and 8.0 caches (the reader table above, and
`tools/objc-init-members.lua` over 16.0), and the SDK header marks it `NS_UNAVAILABLE`. Which selectors a class
carries says nothing about what a caller gets. This section measures that.

### The measurement

`tests/backports/host/init-inherited/host.sh` builds the port's HealthKit classes under `CharonHost<Name>`,
links them beside the system's HealthKit in one process, and asks each class two questions, the way a caller
asks them: `[[cls alloc] init]` and `[cls new]`. The probe is `tests/backports/host/init-inherited/probe.m`.
Its output on the macOS host, built against the Command Line Tools' macOS 27.0 SDK:

```
SAME HKCategorySample init host=raises NSInvalidArgumentException (The -init method is not available on HKCategorySample) port=raises NSInvalidArgumentException (The -init method is not available on HKCategorySample)
SAME HKCategorySample new host=raises NSInvalidArgumentException (The -init method is not available on HKCategorySample) port=raises NSInvalidArgumentException (The -init method is not available on HKCategorySample)
SAME HKObject init host=raises NSInvalidArgumentException (The -init method is not available on HKObject) port=raises NSInvalidArgumentException (The -init method is not available on HKObject)
SAME HKObject new host=raises NSInvalidArgumentException (The -init method is not available on HKObject) port=raises NSInvalidArgumentException (The -init method is not available on HKObject)
SAME HKObjectType init host=raises NSInvalidArgumentException (The -init method is not available on HKObjectType) port=raises NSInvalidArgumentException (The -init method is not available on HKObjectType)
SAME HKObjectType new host=raises NSInvalidArgumentException (The -init method is not available on HKObjectType) port=raises NSInvalidArgumentException (The -init method is not available on HKObjectType)
SAME HKQuantity init host=raises NSInvalidArgumentException (The -init method is not available on HKQuantity) port=raises NSInvalidArgumentException (The -init method is not available on HKQuantity)
SAME HKQuantity new host=raises NSInvalidArgumentException (The -init method is not available on HKQuantity) port=raises NSInvalidArgumentException (The -init method is not available on HKQuantity)
SAME HKSource init host=raises NSInvalidArgumentException (The -init method is not available on HKSource) port=raises NSInvalidArgumentException (The -init method is not available on HKSource)
SAME HKSource new host=raises NSInvalidArgumentException (The -init method is not available on HKSource) port=raises NSInvalidArgumentException (The -init method is not available on HKSource)
SAME HKStatistics init host=raises NSInvalidArgumentException (The -init method is not available on HKStatistics) port=raises NSInvalidArgumentException (The -init method is not available on HKStatistics)
SAME HKStatistics new host=raises NSInvalidArgumentException (The -init method is not available on HKStatistics) port=raises NSInvalidArgumentException (The -init method is not available on HKStatistics)
SAME HKStatisticsCollection init host=raises NSInvalidArgumentException (The -init method is not available on HKStatisticsCollection) port=raises NSInvalidArgumentException (The -init method is not available on HKStatisticsCollection)
SAME HKStatisticsCollection new host=raises NSInvalidArgumentException (The -init method is not available on HKStatisticsCollection) port=raises NSInvalidArgumentException (The -init method is not available on HKStatisticsCollection)
SAME HKWorkoutEvent init host=raises NSInvalidArgumentException (The -init method is not available on HKWorkoutEvent) port=raises NSInvalidArgumentException (The -init method is not available on HKWorkoutEvent)
SAME HKWorkoutEvent new host=raises NSInvalidArgumentException (The -init method is not available on HKWorkoutEvent) port=raises NSInvalidArgumentException (The -init method is not available on HKWorkoutEvent)
SAME HKSample init host=raises NSInvalidArgumentException (The -init method is not available on HKSample) port=raises NSInvalidArgumentException (The -init method is not available on HKSample)
SAME HKSample new host=raises NSInvalidArgumentException (The -init method is not available on HKSample) port=raises NSInvalidArgumentException (The -init method is not available on HKSample)
SAME HKQuantitySample init host=raises NSInvalidArgumentException (The -init method is not available on HKQuantitySample) port=raises NSInvalidArgumentException (The -init method is not available on HKQuantitySample)
SAME HKQuantitySample new host=raises NSInvalidArgumentException (The -init method is not available on HKQuantitySample) port=raises NSInvalidArgumentException (The -init method is not available on HKQuantitySample)
SAME HKWorkout init host=raises NSInvalidArgumentException (The -init method is not available on HKWorkout) port=raises NSInvalidArgumentException (The -init method is not available on HKWorkout)
SAME HKWorkout new host=raises NSInvalidArgumentException (The -init method is not available on HKWorkout) port=raises NSInvalidArgumentException (The -init method is not available on HKWorkout)
SAME HKCorrelation init host=raises NSInvalidArgumentException (The -init method is not available on HKCorrelation) port=raises NSInvalidArgumentException (The -init method is not available on HKCorrelation)
SAME HKCorrelation new host=raises NSInvalidArgumentException (The -init method is not available on HKCorrelation) port=raises NSInvalidArgumentException (The -init method is not available on HKCorrelation)
SAME HKQuantityType init host=raises NSInvalidArgumentException (The -init method is not available on HKQuantityType) port=raises NSInvalidArgumentException (The -init method is not available on HKQuantityType)
SAME HKQuantityType new host=raises NSInvalidArgumentException (The -init method is not available on HKQuantityType) port=raises NSInvalidArgumentException (The -init method is not available on HKQuantityType)
SAME HKDeletedObject init host=ok HKDeletedObject port=ok HKDeletedObject
SAME HKDeletedObject new host=ok HKDeletedObject port=ok HKDeletedObject
SAME CharonHostHKStatistics copy made=yes copied=yes
SAME CharonHostHKStatisticsCollection copy made=yes copied=yes
failures=0
```

Read as a caller reads it: the eight `-init` answers are `NSInvalidArgumentException` with the reason
`The -init method is not available on <class>`, and so is `+new`, because NSObject's `+new` is `alloc` then
`init`. The classes that inherit the raise (`HKSample`, `HKQuantitySample`, `HKWorkout`, `HKCorrelation`,
`HKQuantityType`) raise the same way on the host, so the port's raising `-init` on `HKObject` and on
`HKObjectType` is the answer for them too. `HKDeletedObject` is the one of the family that answers an object,
because it inherits NSObject's `-init` and not a class's own.

### What the port does

- Each of the eight `@implementation` blocks carries `CHARON_HEALTHKIT_UNCREATABLE_INIT`, the macro
  `HealthKit/CharonHKStore.h` defines for the port's other uncreatable classes. It raises the host's exception
  with the host's reason.
- No part of the port builds one of these classes, or a subclass of them, through `-init`. The internal
  constructors call `[super init]` only where the superclass is NSObject: `HKObject`'s `charon_initWithUUID:`,
  `HKObjectType`'s `charon_initWithIdentifier:`, and the `initWithCoder:` methods. Subclasses of `HKObject`
  and `HKObjectType` reach their superclass through `charon_init...` constructors and never through `-init`.
- `HKStatistics` and `HKStatisticsCollection` had four call sites that built through `[[X alloc] init]`: the
  two factories and the two `-copyWithZone:` methods. Those were the only internal calls that reached the
  raise. They now call a bare `charon_init`, which is `[super init]` with NSObject as the superclass. The probe
  builds and copies both (`copy made=yes copied=yes`).
- `tests/backports/host/init-inherited/check.lua` holds the source to this: the macro is in each of the eight
  blocks, and no `alloc] init]` or `new]` in `HealthKit/*.m` names one of the eight or a subclass of them.

### What is not measured here

- The host is macOS, not an iOS release. The reason string and the raise are the host's, from the macOS SDK's
  HealthKit. iOS 8.0 and 16.0 are not run here. The release's own answer is the 6.1.3 emulator through the
  gate, which this band does not run.
- The behaviour of these selectors on a device.

### The check to run

- `sh tests/backports/host/init-inherited/host.sh` on a macOS host: every line `SAME`, `failures=0`.
- `xmake lua tests/backports/host/init-inherited/check.lua <checkout>`, in every light guard: the eight rows are
  `implemented` in the registry, and the source carries the macro and no raising construction.
