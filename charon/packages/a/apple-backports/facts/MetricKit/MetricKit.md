# MetricKit, on a release that measures nothing

Every class of this framework is a value object the *system* fills in: it counts what the application
did, samples its memory footprint, reads its disk I/O and hands the result to a subscriber at the next
launch. iOS 6.1.3 has none of that - no MetricKit, nothing counts, nothing samples, no payload was
ever produced, and the release's armv7 6.1.3 cache carries no MetricKit surface at all (read with
`objc.binary_inventory`).

So the seam is the *collection*, and the port draws the line it drew for the rest of the week's
deliveries:

- **A member whose promise is "the value I was given" is implemented.** That is 206 of the 209 rows:
  the 36 value classes, their 142 properties, the dictionary and JSON representations, the archiver,
  the manager with a real subscriber list and a real payload store, and the two extended-launch
  measurements, which are real measurements of a real interval.
- **A member whose promise is "the system did something" needs the release's machinery.** Two of the
  209 needed nothing this release lacks, because the port already carried the machinery:
  `+[MXMetricManager makeLogHandleWithCategory:]` is `os_log_create` over the port's own log, which has
  been carried from 6.0 (`registry/Foundation/oslog.json`), and `_MXSignpostMetricsSnapshot()` is over
  the signpost family, which this delivery now carries over that same log
  (`facts/Foundation/OSLogSignpost.md`). Both were `absent` in a first pass on the grounds that
  os_log and os_signpost are later than this release - and that was wrong: `absent` is for hardware the
  device does not have, and neither of these is hardware.
- **The two `MXMetricManagerSubscriber` messages are the only rows of the 209 that are `absent`**, and
  for one reason: the port carries no class that conforms to that protocol. A subscriber is the
  application's own object and its own translation unit emits the protocol. The *messages* are real -
  the manager sends both to whatever object `-addSubscriber:` was given - and the entry says so; what
  is absent is the protocol, and the library must carry no `__OBJC_PROTOCOL_$_` for it, or the next
  check reads the two and finds them.

Nothing here answers a zero for a measurement it did not take. A property reads nil until something
puts a value in it, and a nil property is left out of the dictionary entirely rather than written as
null, so a reader can tell "not measured" from "measured and was nothing".

## The store, and why it is one dictionary

Apple's headers give these classes no initialiser, no setter and one representation method each, so
there is nowhere to put a value and nothing to read one from. The port gives each of the sixteen
NSObject roots one dictionary keyed by the property's own name, and each of the 142 properties is the
macro that reads or writes it (`CharonMetricValue.h`). That is what makes the properties a line each
rather than 284 hand-written accessors, and - the part that matters - it makes the dictionary, the
JSON and the archiver walk **one list per class**, the runtime's own property list, instead of a
hand-written list that could drift from the header. A property the header does not declare cannot be
read, and a property it does declare is always in the representation.

A property whose value is not an object is boxed into the store as an `NSNumber` and read back out of
one, which is what the property walk sees through KVC as well.

## The two representations

`-dictionaryRepresentation` is the object's own properties, each key the property's own name as the
SDK 26.2 header spells it. `-JSONRepresentation` is that dictionary serialised, so there is no second,
private shape to match: anything that can read the JSON can read the dictionary and find the same
content. Four conversions, and each is the only one that keeps the value true:

| a property's value | becomes | why |
| --- | --- | --- |
| a MetricKit value | its own dictionary | the JSON is a tree of the same shape the object graph is, and nothing is flattened into a string |
| an `NSMeasurement` | its `doubleValue` | the unit is named by the property's own declared type, which the header keeps, so a number need not repeat it |
| an `NSDate` | its interval since the reference date | exact and reversible, and a JSON number can carry it |
| an `NSURL` | its absolute string | that is what identifies it to anything that reads it |

`DictionaryRepresentation` is the deprecated `NS_REFINED_FOR_SWIFT` spelling of the same dictionary and
answers it.

## The archiver

`+supportsSecureCoding` is YES and the archiver walks the same property list, so a payload archived by
this port is read back into the properties it was written from. On the way in, the classes a value may
be are the classes **this library carries**, found through the runtime by the `MX` prefix, plus the
Foundation value types those hold. An archive naming a class outside that set decodes as nil rather
than as an instance of something the process does not have.

## The manager: a real store, a real subscriber list, one real measurement

- `+sharedManager` is one shared manager. `-addSubscriber:` and `-removeSubscriber:` are real, and the
  subscriber is held weakly - a manager outlives its subscribers, and holding one strongly would keep a
  view controller alive for as long as the process lives. **A subscriber is given what the store holds
  when it is added**, through both callbacks of the protocol, on the main queue. On this release the
  store is empty until an application writes into it, so what a subscriber receives today is an empty
  array - and it receives it because the manager really read the store, not a fabricated payload.
- `pastPayloads` and `pastDiagnosticPayloads` read a real directory under Application Support -
  `org.charon.apple-backports.MetricKit` - newest first by the time stamp the file name carries, and a
  file that does not decode as the class asked for is left where it is and skipped. That is the same
  convention `CoreSpotlightBackports` keeps its index in, and the store is writable: the payloads are
  `NSSecureCoding` and the port decodes them, so a payload the port never produced can still be a
  payload the manager hands over.
- `+extendLaunchMeasurementForTaskID:error:` and `+finishExtendedLaunchMeasurementForTaskID:error:` are
  the one real measurement in this delivery. The first remembers a monotonic reading under the task
  identifier; the second takes another and records the difference as a real `MXAppLaunchMetric` whose
  `histogrammedExtendedLaunch` holds it, in one bucket. An interval measured twice with a clock is
  exactly what a launch measurement is, and the clock is the release's own. A second call with no
  first call answers NO with `MXErrorDomain`.

## What the SDK the port builds against does not carry

The build compiles against the lowered **16.4** SDK, and MetricKit grew past it: three of the 26.2
classes (`MXSignpostRecord`, `MXDiskSpaceUsageMetric`, `MXCrashDiagnosticObjectiveCExceptionReason`) and
five of its properties (`MXMetaData.lowPowerModeEnabled`, `isTestFlightApp`, `pid`, `bundleIdentifier`,
`MXDiagnostic.signpostData`, `MXCrashDiagnostic.exceptionReason`, `MXMetricPayload.diskSpaceUsageMetrics`,
`MXAnimationMetric.hitchTimeRatio`) are not in those headers at all. They are declared in
`CharonMetricKit.h`, spelled as `SFCertificatePresentation.h` spells itself in `CharonSecurityUI.h`:
the same superclass, the same selectors, the same property types, no ivars, and no availability
annotations. The five gap properties are implemented in categories, because a property a category
declares is implemented in a category.

`CharonMetricKit.h` redeclares those three classes **for the lowered SDK this package builds against
and nothing else**: compiled against the real 26.2 headers it collides with them, exactly as
`CharonSecurityUI.h` collides with `SecurityUI`'s own `SFCertificatePresentation`. The package only ever
compiles against the lowered SDK, so nothing in a build sees it; a header a future SDK change would
break is the price of carrying a class whose header the build's SDK has not got, and it is the price
`CharonSecurityUI.h`, `CharonAVAudioBuffer.h` and `CharonCallKit.h` already pay.

## Not measured, and the four warnings

**Two of the registry's own first answers were wrong.** The second is
`MXMetricManagerSubscriber`'s two messages, which the first pass wrote as `implemented` because the
manager really does send them - and `check_registry` read the build and said
`listed as implemented, but nothing of that name is built`, which is the registry and the tree
disagreeing, which is the check's whole purpose. The entry describes what this library carries, and it
carries no such class and no such protocol.

**The first is that one row and is corrected here.** A first pass of the
header walk missed `MXMetricPayload.diskSpaceUsageMetrics` - its declaration wraps across a line, and the
walk stopped at the first newline - and wrote that row as `absent` with the reason "no property of that
name is declared on the class the SDK 26.2 headers give it". The header does declare it, the port
carries it, and the entry is now `implemented`; the error is worth recording because a registry entry and
the tree have to agree, and the gate is what says when they do not.

## The two rows that were absent and are not

`+[MXMetricManager makeLogHandleWithCategory:]` returns an `os_log_t`, and this package has carried
`os_log_create`, `_os_log_internal` and `os_log_type_enabled` from 6.0 - so the handle is
`os_log_create("com.apple.metrickit.log", category)`, over the port's own log, named with the subsystem
Apple uses for this framework's own log. Its own `-description` names the subsystem and the category it
was made with, which is what the host differential would print.

`_MXSignpostMetricsSnapshot()` is declared in the SDK after all, in `MXSignpost_Private.h` - the header
whose own comment says "implementation details that are not meant for clients to call directly. The
header must be public to allow clients to compile properly" - and its type is `void* _Nonnull`. So R4
does not apply: a name an SDK header declares, in a private header, is not a name no header declares.
The macros beside the declaration also say exactly what the pointer is for: every signpost MetricKit
emits gets a public `signpost:metrics` field and this pointer as its one argument, and the port's emit
path records that pointer on the interval it takes. The port's own os_signpost family
(`facts/Foundation/OSLogSignpost.md`) is what records it, and the port's signpost metrics are read out
of the same store.

## The value differential, and the one check that needed the round trip

`tests/backports/host/metricvalue` builds the port's own sources for a host and asks two questions.
The first is what the system's MetricKit writes for a value nothing measured, and the port must answer
it the same way. The second is the KVC walk: the eight properties the port declares and the 16.4 SDK it
builds against does not, plus one ordinary property, each set through the port's own
`-charon_setValue:forKey:` and read back through the accessor, with the class named by its **symbol** so
that the port's class is the one under test and a class it does not carry is a build error.

That round trip is the check the `hitchTimeRatio` mutation needed, and the reason is worth writing
down. The port half compiles with `-DCHARON_HOST_DIFFERENTIAL=1`, because the host's MetricKit is
*newer* than the SDK the port ships against and the rename header rewrites the class name inside Apple's
own headers: Apple's `@interface MXSignpostRecord` becomes `@interface CharonMXSignpostRecord`, the same
class the port declares. Building without the flag was measured and does not build —
`duplicate interface definition for class 'CharonMXSignpostRecord'`, then six `property has a previous
declaration` — so it is not a configuration that can be asked for. With the flag, the port's `@dynamic`
is compiled out, the property is declared by Apple's header, and the **compiler synthesises** a getter
when the port's is missing. A synthesised getter still answers the selector, which is why
`instancesRespondToSelector:` cannot see the mutation, and `nm` cannot either: the synthesised IMP is
in the binary and the ivar is present in both variants. What a synthesised getter cannot do is return a
value nobody wrote, so the round trip is what separates it from the port's accessor. No symbol table
and no `nm` is involved.

## Not measured against a host (measured: the directory has
128 frameworks and MetricKit is not among them), and a differential would have no system implementation
to compare against - the values here are the system's *output*, which is precisely what this release
does not produce. What could be measured by hand - the property lists, the hierarchy, the SDK gap - is
measured and written above.

**Four warnings in `CharonMetricValue.m`** (`-Wincomplete-implementation` for the coding pair on two
roots, and `-Wobjc-property-implementation` for `+supportsSecureCoding` on one class) are open. The
implementation is there and the file links; what is missing is that the category declarations and the
implementations of the two roots' archiving trio live in different categories, which the compiler wants
merged. They are not `-Werror` in this package, so nothing is silenced; the next pass on this framework
should merge them.

**The device call test has not been run.** It would be the one thing that could catch a mistake in the
property walk, and it is listed in the delivery as not run.
