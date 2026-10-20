# Matter

`Matter.framework` does not exist before iOS 16.4, so every release this package carries has no Matter
framework to shadow: a client that links one and asks a cluster a question reaches this port's class
instead. The clusters are therefore generated from the SDK's own headers rather than written by hand,
because a class has too many members for a hand transcription to be right and the header is the contract.

## The generated family against the real stack (v-matter9)

The real stack is revenant@matter's `libMatterBackports.dylib` (v1.6.1.0, armv7). Its Objective-C classes, read with
`modules/apple/objc.lua`'s `binary_inventory` (the reader `tools/matter-registry.lua` uses), are 1508. Of the 1208
classes the committed generated objects define, the real stack defines **1188** and **20** it does not.

- The generated side is the name of the `@implementation` of each of the 1208 committed `Matter/*.m` objects. The
  built `libMatterClusterBackports.dylib` of the same tree (the `matter` config's install) defines the same 1208 names,
  read with the same reader, so the object set and the binary agree.
- `class-overlap.tsv` (this directory) is the measurement, one row per generated class: `yes` when the real stack
  defines it, `no` when it does not. 1188 yes, 20 no. The 20 are listed in the table under "The 20 generated-only
  classes" below.
- The real stack's registry (`packages/m/matter/registry`) carries 854 of the 1188 class names as class rows. The
  other 334 are classes the real stack defines and its registry has no class row for: the registry is written from the
  SDK 26.2 surface corpus, and those 334 are not in that corpus (for example `MTRBaseClusterChime`,
  `MTRUnitTestingClusterGlobalEchoRequestParams`).

## What is carried

**1,208 objects, one class each, all emitted by `tools/matter-generate.py` from the SDK's own declarations.**
Two families, and both are read out of the headers rather than listed:

- **the 144 cluster objects** - 142 of the framework's 145 `MTRBaseCluster` classes from the declarations in
  `MTRBaseClusters.h`, plus the two classes they all sit on: `MTRGenericBaseCluster`, which SDK 16.4 does not
  declare, and `MTRCluster`, which it does. **Both bases are carried, not just the one the SDK lacks**: a
  declaration says a class exists at compile time, and the object is what makes it exist at runtime, and the
  release this family is carried into has no `Matter.framework` at all. Every one of the 142 cluster objects
  names `_OBJC_CLASS_$_MTRCluster` - measured over all 144 objects: of every symbol they leave open, those
  two (`MTRCluster`'s class and metaclass) are the only Matter ones - so without that object the library does
  not link: `Undefined symbols for architecture armv7`. 16.4's `MTRCluster.h` declares `-init` and `+new`
  `NS_UNAVAILABLE` and no member, so that is what its object carries: the class and nothing else. The other
  three are listed in `tests/backports/host/matter/excluded.txt` with a reason each. Every member a cluster
  declares - a read, a write, a subscribe, a command in every shape the header gives it, a cached read, the
  initialiser - has a body that answers without reaching a fabric: the value the caller set, or no value and
  the error the release documents for a cluster it cannot reach.

- **the 143 concrete `MTRCluster*` cluster objects, and the third class they sit on** - every `@interface`
  whose superclass is `MTRGenericCluster`, which is one line of the reader's own output
  (`@interface MTRClusterIdentify : MTRGenericCluster`, MTRClusters.h) and 143 classes: 139 declared in
  `MTRClusters.h` and 4 in `MTRBaseClusters.h`, the four already counted above. **139 new objects, plus
  `MTRGenericCluster`**, which 16.4 does not declare at all - `MTRCluster.h:62` gives it
  `MTR_AVAILABLE(ios(17.4))` - so without it every one of the 143 is `cannot find interface declaration for`
  and the library does not link. It carries the one property its own header declares at `MTRCluster.h:66`,
  `device`, and nothing else. **79 of the 143 are absent from 16.4** and get the port's own `@interface` in
  `RevenantMatterTypes.h`, superclass and every member; the other 64 are declared by it and add nothing there.
  Their list is written to `generic-clusters-emitted.txt` beside `clusters-emitted.txt` and CHECKED against
  the headers on every run, so a stale file is named rather than carried.

  These classes declare three shapes the base clusters do not, and each is the SDK's own answer to a
  different question:

  | shape | what it is | what the port answers |
  | --- | --- | --- |
  | `- (NSDictionary<NSString *, id> * _Nullable)readAttribute<Name>WithParams:(MTRReadParams * _Nullable)params` | a read on the caller's thread: it RETURNS the value where the asynchronous form hands it to a completion block, and has nowhere to report an error, so it needs none | the value the caller wrote into the class's own table, or nil when nothing was written - which is what the declaration's own `_Nullable` return says is a possible answer |
  | `- (void)writeAttribute<Name>WithValue:(NSDictionary *)dataValueDictionary expectedValueInterval:(NSNumber *)expectedValueIntervalMs`, with and without a trailing `params:` | a write that says when to consider it in effect, and takes no completion block at all | it stores what the caller wrote; there is nothing else to answer, because there is no block to answer through |
  | `- (void)<verb>WithExpectedValues:...expectedValueInterval:...completion:` | a COMMAND and not a write - it invokes the cluster rather than setting an attribute - which is why it sits beside the command patterns and not with the writes | the command's own answer: the error the release documents for a cluster it cannot reach |

  `NSDictionary<NSString *, id>` is the DATA VALUE type both of the first two carry, and the attribute's own
  type is stated nowhere in these 143 headers, so the emitted comment says the value is a dictionary rather
  than naming a type the header does not give. The synchronous read's single nullability annotation is on
  its RETURN type, which is why it takes one function of its own rather than sharing
  `strip_region_nullability()` with the commands: the region's nonnull and an explicit `_Nullable` on the
  same pointer is `nullability specifier '_Nullable' conflicts with existing specifier 'nonnull'`, measured
  on all 143 objects.

- **the 923 plain data classes** - every `@interface` in the SDK's Matter headers whose name carries
  `Params`, `Struct` or `Event`, holding 3,260 properties. They are the types the commands and the events name,
  and they were forward-declared and nothing more until now: a caller could not build one, which is what the
  `*Params` bullet under "What is owed" used to say. Nothing in this family reaches a fabric. A class holds
  what the caller put in it, hands back what it holds, and `-copyWithZone:` is written out over its own ivars
  so writing to the copy never reaches back into the original. 565 of the 923 carry `<NSCopying>` in their own
  protocol list and the rest inherit it from a superclass that does, so 863 of them get the copy; the 60 that
  do not are the event classes, and the host's own method list is what says so - `-copyWithZone:` is written
  for a class the MEASUREMENT gives one, which is `respondsToSelector:` read over the class's own methods and
  not the protocol list, because the protocol list is a declaration and this is a binary.

  **`-init` IS written, and it is not NSObject's.** Every class in this family except the ones whose header
  marks it `NS_UNAVAILABLE` gets an initialiser that stores what the host's initialiser stores: a NONNULL
  object member is the zero value of its own type and a nullable one is nil. Measured, by
  `tests/backports/host/matter/params-probe.m`:

      fresh  MTRGroupsClusterAddGroupParams  groupID               NSNumber(0)
      fresh  MTRGroupsClusterAddGroupParams  groupName             NSString()
      fresh  MTRGroupsClusterAddGroupParams  timedInvokeTimeoutMs  (nil)
      fresh  MTRTestClusterClusterSimpleStruct  d                  NSData(0)

  The three exceptions are the classes whose own header writes `- (instancetype)init NS_UNAVAILABLE`, and an
  `@implementation` that defines an unavailable method is the compiler's own error.

**Three declarations, because the SDK this library compiles against (16.4) does not have all of it.** Which
one applies is read, not chosen:

| the port writes | how many | why |
| --- | --- | --- |
| the whole `@interface`: superclass, protocols, every property | 538 | the library's SDK declares no class of that name, and an object that implements a class no `@interface` declares is `cannot find interface declaration for` |
| a class **extension** with only the properties a later SDK added | 72 | the library's SDK declares the class, so redeclaring it is `duplicate interface definition for class`; 26.2 adds properties to 313 of the classes it declares - `MTRReadParams` gains `minEventNumber` and `assumeUnknownAttributesReportable`, `MTRSubscribeParams` gains `minInterval` and `maxInterval` |
| a **category** with the properties the SDK declares in one | 17 | a category's property cannot be synthesized in the class's `@implementation`, and `MTRGroupsClusterAddGroupParams` carries the old `groupId` in a `(Deprecated)` category beside the `groupID` of its own `@interface` |

The 17 category properties are the SDK's own API - `MTRGroupsClusterAddGroupParams.groupId` is a corpus row at
16.1 - so they are carried, with their accessors written out by hand over storage in the port's own class
extension. Both alternatives are clang's own answer and both were measured: `@synthesize not allowed in a
category's implementation`, and `property declared in category 'Deprecated' cannot be implemented in class
implementation`. The accessors are written with the type the **library's** SDK declares, because Apple relaxed
a nullability between the two SDKs - `MTRDiagnosticLogsClusterRetrieveLogsResponseParams`' `content` and
`timeStamp` are `_Nonnull` in 16.4 and `_Nullable` in 26.2 - and the port does not redeclare the property, so
writing 26.2's spelling is `nullability specifier '_Nullable' conflicts with existing specifier '_Nonnull'`.

The class's own state is a table of each object's own, keyed by the attribute name, made on first use and read
and written under the object's lock: one object's written value is not another's, and two threads on one object
are not a race (`behaviour.sh`: the other instance reads nil, and eight threads of write-and-read under
ThreadSanitizer report nothing). It was one table for the whole class, mutated with no lock, until the
behaviour differential showed both. A release with no Matter hardware has no node to read from, so the class
methods the header declares answer as the framework does when it has nothing to read from: no value, and
`MTRErrorDomain` code `MTRErrorCodeInvalidState` ("Invalid object state."). Measured on the host by
`tests/backports/host/matterdifferential/behaviour.sh`: a cached read on a container with no cache attached and
a read, a write and a subscribe on a controller that has been shut down all answer exactly that, and an earlier
version of the port answered `NSCocoaErrorDomain` 4096, which no framework answer corresponds to.

## What is measured

tools/matter-generate.py            run exit 0; `clusters written: 281` (the 142 MTRBaseCluster* classes
                                        and 139 more of the 143 concrete MTRCluster* ones, the other four
                                        already in the first list); `every object compiles against the SDK
                                        the library builds with: 1208`; `every object names the class it
                                        implements: 1208 of 1208`; `plain data classes written: 924, 3263
                                        properties; 0 named but not declared in the SDK`; `the concrete
                                        MTRCluster* classes - every one the SDK declares whose superclass is
                                        MTRGenericCluster, and 143 of them, disjoint from the 142
                                        MTRBaseCluster* ones`; `generic-clusters-emitted.txt: 143 name(s)
                                        written, and they MATCH the committed list`;
                                        `RevenantMatterTypes.h: 2 shared class declaration(s), 158 cluster
                                        interface(s), 610 plain data declaration(s); 3 object(s) written`
    the generator's two invariants, both ways
                                        `invariant: every member the header declares is in the generated
                                        file, for every cluster` and `invariant: every command, cached read
                                        and initialiser an object defines is declared in the @interface the
                                        port writes for it, over every cluster the library's SDK does not
                                        declare`. The second is new and it is there because the first could
                                        not see a whole class of defect: the two artifacts come out of the
                                        same facts() but are read by two functions, so a shape one of them
                                        takes and the other does not is invisible to a check that looks at
                                        one of them alone. Measured, not argued - a version of the tool with
                                        the interface's reader put back to what it was reports
                                        `INVARIANT FAILED: 45 member(s) the object defines are not declared in
                                        the @interface the port writes for it, over 22 cluster(s)` and exits
                                        1, while the first invariant passes and all 27 objects of that run
                                        compile; see "The 45 declarations that were not there" below.
    tools/matter-registry.py            run on the 1,208 objects of this tree: `rows over the base ... 17494
                                        kept in its order, 4317 appended, 0 dropped`; `wrote ios16.json:
                                        21811 entries (1208 class, 14139 method, 6464 property) over 1208
                                        objects, every object one class`; `every class an emitted object
                                        defines has a row: 1208 of 1208`; 4873 rows take the 16.0 fallback the
                                        header states nowhere - 336 class, 2507 method, 2030 property - and all
                                        of them are listed in ios16.json.unannotated (10896 declarations);
                                        863 class rows take the class's OWN annotation and 345 are dated by a
                                        member because their own annotation names no release
    the ledger, coordination/corpus/ledger-2026-10-03/Matter.tsv
                                         2870 of the framework's 11675 `missing` rows are `implemented` by
                                         this family before this change, and 904 more name one of the 79
                                         concrete clusters 16.4 does not declare - 50 class, 854 method -
                                         which this change carries (see "The 904 rows" below)
    the 1208 objects, armv7-apple-ios6.0, the package's own flags
                                        0 lines matching ` error: ` over all 1208, xargs -P 2
    coordination/work-2026-10-03/tools/relcheck.lua, BP_LIBRARY=MatterClusterBackports
                                        `compiled 1208 objects of MatterClusterBackports` then
                                        `check_releases: every object of MatterClusterBackports holds API of
                                        one release` - measured from the held caches' EXPORT TRIE, not from
                                        API_AVAILABLE
    nm -gU over those 1208 objects      1208 distinct _OBJC_CLASS_$_ symbols, one per object, and every one
                                        is either Revenant-prefixed or a class the registry carries as
                                        `implemented`: 0 that are neither. The only other exported symbol is
                                        _OBJC_LABEL_PROTOCOL_$_NSCopying, from the NSCopying conformance the
                                        plain data classes carry, which internal_symbol() does not exempt -
                                        check_releases measured it as placed anyway
    coordination/build-gate.lua 6.1.3   exit 0; `build: 6.1.3 compiled 3890 of 1969 objects in 27.9s,
                                        measured their releases in 35.2s, linked 69 libraries in 4.9s,
                                        checked in 4.7s`, and no -Wincompatible-sysroot in the log
    coordination/build-gate.lua 4.3     exit 0; `build: 4.3 compiled 3890 of 1969 objects in 25.3s,
                                        measured their releases in 34.7s, linked 69 libraries in 3.9s,
                                        checked in 4.1s` - the same note as 6.1.3: the band links
                                        MatterClusterBackports without Matter, which the release has not
    RevenantMatterMTRGenericBaseCluster.m, armv7-apple-ios4.3
                                        fails: MTRDeviceControllerStartupParams.h:240 `property with 'retain
                                        (or strong)' attribute must be of object type`. The smallest of the
                                        144 objects, which imports Matter.h and declares nothing of its own,
                                        is enough to see it: the error is in a header all of them import
    the 144 objects, the package's own flags, before the plain data family
                                        armv7-apple-ios6.0, iPhoneOS16.4.sdk, -fobjc-arc -Os -Wall
                                        -Werror=objc-missing-property-synthesis, xargs -P 2, one log per
                                        object: 144 of 144 compiled, 0 errors, 0 warnings from the port's
                                        code. One flag pair is named rather than counted: the repository's
                                        own host compiles add -Wno-incompatible-sysroot
                                        (tests/macho_test.py and every gate call), and with it the 144 logs
                                        are empty. Without it the only diagnostic clang can add is its own
                                        `using sysroot for 'iOS 16.4' but targeting 'thumbv7-apple-ios6.1.3'
                                        [-Wincompatible-sysroot]`, which is the SDK against the deployment
                                        target and not a line of the port's - so it is named here instead
                                        of being rounded into "0 warnings"
    the same 144 objects for armv7-apple-ios4.3
                                        0 of 144 compile, and the same diagnostic is in all 144 logs
    tests/backports/host/matter/plants.sh
                                        plants run 4, failures 0: control 0, drop 1, rename 1, extra 1
    tests/backports/host/matterdifferential/run.sh
                                        DOES NOT BUILD on this host: 142 clusters not built, 0 checked

The invariant asks both ways and each direction has a control. Forward: every selector the header declares is
in the generated file - 1,162 members over 83 clusters when the invariant was first written. Reverse: every
selector the file defines is in the contract - it named 700 on `MTRBaseClusterTestCluster` alone, and an
invented instance method injected into one emitted object is caught and named, so the reverse direction is
not vacuous.

**The 45 declarations that were not there.** Both of those directions read the OBJECT. `RevenantMatterTypes.h`
is a second artifact, built from the same `facts()` but read by a different function, and a shape one of them
takes and the other does not is invisible to a check that looks at one of them. Reading the interface's
commands over the parameterised shapes alone dropped the `<verb>WithCompletion:` form of every verb that has
one: **45 declarations over 22 classes, all of them base clusters**, none of the 143 concrete ones - which is
why the run stayed green. All 1,208 objects compiled, because the library's SDK declares those selectors
itself, so the port's missing declaration was a duplicate of one the compiler could already see. It would
have stopped being one the moment the SDK stopped declaring it, and nothing in the run said so.

So the check is now asked of both artifacts: every command, cached read and initialiser an object defines is
declared in the `@interface` the port writes for it, over every cluster 16.4 does not declare. The reads,
writes and subscribes are deliberately outside it - each cluster object defines its own and nothing declares
them, which is legal and is what the tree has always done - and that exclusion is written down beside the
list it applies to rather than left to be rediscovered. **The control, measured:** the same 24 classes with
that one line put back to what it was reports

    INVARIANT FAILED: 45 member(s) the object defines are not declared in the @interface the port writes
      for it, over 22 cluster(s):
      MTRBaseClusterActivatedCarbonFilterMonitoring	resetConditionWithCompletion:
      MTRBaseClusterCameraAVSettingsUserLevelManagement	MPTZSetPositionWithCompletion:
      ...

and exits 1, while the pre-existing invariant on the same run prints its `invariant:` line and all 27 objects
compile. A check that cannot fail is worth nothing; that one could.

**An annotation macro is the header's, not the method's.** `signature()` took off `MTR_AVAILABLE(` and
nothing else, so a declaration SDK 16.4 spells with the OTHER name arrived with the macro still attached and
the emitted signature carried it: 1,723 lines of `MTR_DEPRECATED(...)` in
`RevenantMatterMTRBaseClusterTestCluster.m` and 22 lines of `API_AVAILABLE(...)` in
`RevenantMatterMTRBaseClusterColorControl.m`, both of which compiled and neither of which is the framework's
shape. The list is now every macro a declaration can END with - available, deprecated, unavailable, in both
spellings - and the paren-counting strip takes off whichever it finds first, so a nested one is still
consumed whole.

**The designated-initializer diagnostic cannot be satisfied, and the 60 objects that raise it silence it
where the repository silences it.** 60 of the 144 objects are the clusters SDK 16.4 declares AND marks
`-initWithDevice:endpointID:queue:` `NS_DESIGNATED_INITIALIZER` on: clang then asks the initializer to chain
to a designated initializer of the superclass, and the superclass `MTRCluster` declares
`-init NS_UNAVAILABLE` (MTRCluster.h:40 in 16.4, :42 in 26.2), so

    self = [super init];        error: 'init' is unavailable

is the measurement, not an assumption, and it is the same through a category or a class extension that
redeclares `-init` (both probed; the attribute stays). Four ways of writing the chain are measured in
`coordination/crutches.md`. What the 60 objects therefore carry is

    #pragma clang diagnostic ignored "-Wobjc-designated-initializers"

directly under the imports, with the reason in the comment above it, which is where this repository puts that
pragma - `MTLRasterizationRate13.m`, `GCMouseInput.m`, `CXCall10.m` and about twenty others. The predicate is
read from the SDK, not from a list: `chain_blocked()` is true where 16.4's own block carries the attribute on
the initializer, which is 60 of the 63 clusters 16.4 declares - `MTRBaseClusterBasic`,
`MTRBaseClusterBridgedDeviceBasic` and `MTRBaseClusterTestCluster` it declares without it, and those three
objects get no pragma. The 79 objects whose `@interface` the port writes carry none either.

The initializer itself does the work that matters: it writes the device, the endpoint and the queue it was
given into the three ivars its class declares, boxing the `uint16_t` that the header's deprecated
`initWithDevice:endpoint:queue:` hands it.

**The differential does not build here, and the reason is the port's own types header.** `RevenantMatterTypes.h`
declares every cluster class SDK 16.4 lacks, because the library compiles against 16.4 and an object that
implements a class no `@interface` declares is `cannot find interface declaration for`. This host's
Matter.framework declares 141 of the 142 emitted clusters, and 78 of the port's declarations carry a name
the host also declares, so every one of the 142 programs is `duplicate interface definition for class`. An
earlier version of this file reported `checked 139, differing 0` for this check; that does not reproduce on
this machine at this tree, and the difference is the host's framework, not the port. Running it needs a host
whose `Matter.framework` declares none of the 78, or the port's cluster declarations under a guard the
differential can turn off.

## What the host differential says about the PORT (2026-10-03, the coordinator's ruling)

`sh tests/backports/host/matter/params-diff.sh` runs the same probe on both sides - the host against
`/System/Library/Frameworks/Matter.framework`, the port against the generator's own objects regenerated for
this host with `--sdk16 <the host SDK>`, the same rule the shipped tree applies to 16.4. It compares what
each side answers for the same driver, and it runs a RED CONTROL: one value in one port object changed, and
the run must notice.

**THE PORT DOES NOT YET MATCH, and the numbers are the measurement.** Three runs, each with the red control:

    run                             ownDescription    description    fresh         alias
    first (port side generated with no --host-measurements)
                                   66 of 918          0 of 918      3141 of 3273  25 of 37
    second (--host-measurements, -description through the accessors)
                                   918 of 918         393 of 918    3141 of 3273  26 of 37
    third (--host-measurements, -description through the OWN STORAGE)
                                   918 of 918         393 of 918    3141 of 3273  26 of 37

66 on `ownDescription` was exactly the number of classes that do NOT override `-description`, which is what a
port that wrote none of them looks like. It is 918 of 918 now. The red control moved 923 readings each time,
so the comparison can fail and its verdict is a verdict.

**What is left, each with the measurement that explains it.**

**The ruling changed what these numbers mean.** The host's Matter.framework is built from a LATER SDK than
the one the port implements - it renames `thumbnailUrl` to `thumbnailURL` and reorders members - so a
difference in member SET, ORDER or NULLABILITY between the two is a difference between two RELEASES. The port
keeps 26.2's declaration, and `tests/backports/host/matter/predict.py` lays the port's own VALUES out in the
HOST SDK's declaration order and set, read from that SDK's headers with the generator's own reader. Three
families of reading:

    identical   the port's reading IS the host's
    predicted   a difference the two SDKs' DECLARATIONS account for, named one by one
    unexplained a difference no declaration difference accounts for. THIS IS WHAT MUST BE ZERO.

    run                                          description                      fresh                    alias
    first (no --host-measurements on the port side)
                                                  66 of 918 ownDescription, 0 of 918 description
    second (-description through the accessors)    918 / 393 / 0                   3141 / 0 / 132           25 of 37
    third (-description through the OWN STORAGE)   918 / 393 / 0                   3141 / 0 / 132           26 of 37
    fourth (an own member that shares an ivar is emitted like a category member)
                                                  918 / 3151 / 39 / 83            3151 / 39 / 83            37 of 37
    fifth (a nonnull member of another plain data class is [[X alloc] init]; the family closes over
           the classes its members name, which added MTRUnitTestingClusterNestedStructList)
                                                  918 of 919 / 3216 / 39 / 25     3216 / 39 / 25           37 of 37

`alias` is 37 of 37 and the fourth and fifth runs each carry the red control. What the 25 are, and it is
three things:

* **an own member that shared an ivar and was still `@synthesize`d** - which is now fixed. The synthesis
  gave `MTRApplicationBasicClusterApplicationStruct.catalogVendorId` a second ivar, so the member answered
  nil where its successor answered the shared value, with both SDKs declaring it `NSNumber * nonnull`.
* **a nonnull member whose type is another plain data class**: the host allocates one and the port held nil.
  It is `[[X alloc] init]`, the same construction the class's own `-init` does, and 83 readings were this
  one cause. Making it so added one class to the family - `MTRUnitTestingClusterNestedStructList`, which ends
  in none of the three suffixes and is named by
  `MTRTestClusterClusterTestNestedStructListArgumentRequestParams`'s `list` member. Without an object for it
  the library did not LINK: `Undefined symbols for architecture arm64:
  "_OBJC_CLASS_$_MTRUnitTestingClusterNestedStructList"`. The family now CLOSES over the classes its members
  name, so 924 classes and 1068 objects, and the oracle for 26.2's own defaults is the connectedhomeip tree
  already on this machine at `toolchain/.agent-work/upstreams/chip/src/darwin/Framework/CHIP/zap-generated/`,
  whose generated `MTRCommandPayloadsObjc.h` is the 26.2-era shape (`groupID` at `MTR_AVAILABLE(ios(16.4))`,
  the same as 26.2).

**`fabricID` and `ipk` are FIXED, and the rule came out of the framework's own source.** The port wrote an
`-init` for all 924 plain data classes. It should write one only where the framework's source does:

    toolchain/.agent-work/upstreams/chip/src/darwin/Framework/CHIP/MTRDeviceControllerStartupParams.h:30
        - (instancetype)init NS_UNAVAILABLE;
    toolchain/.agent-work/upstreams/chip/src/darwin/Framework/CHIP/zap-generated/MTRCommandPayloadsObjc.mm
        @implementation MTRGroupsClusterAddGroupParams
        - (instancetype)init
        {
            if (self = [super init]) {
                _groupID = @(0);
                _groupName = @"";
                _timedInvokeTimeoutMs = nil;
                _serverSideProcessingTimeout = nil;
            }
            return self;
        }

So the rule is not "a nonnull member gets a zero": it is **"the class has an `-init` of its own, and that
`-init` defaults every member"** - the generated sources write one line per member, `@(0)` for the nonnull
ones and `nil` for the nullable ones. A class the source declares no initialiser for inherits NSObject's,
which stores nothing, so every member of it is nil whatever its nullability says. The generator reads
`- (instancetype)init NS_UNAVAILABLE` out of the SDK's own headers and finds **2 of the 924**:
`MTRDeviceControllerFactoryParams` and `MTRDeviceControllerStartupParams`. Those two objects now have no
`-init`, and the run says so every time:

    2 of the 924 plain data classes whose own header marks -init NS_UNAVAILABLE, and so get no -init here:
    MTRDeviceControllerFactoryParams, MTRDeviceControllerStartupParams

**`ownDescription` is 919 of 919 and `alias` 37 of 37.** The measurement is re-taken with
`MTRUnitTestingClusterNestedStructList` in it - 919 classes present, 5 absent, 0 raised - and the port answers
both for every class the host has.

**23 readings are still UNEXPLAINED, and they are ONE cause.** `MTRJointFabricDatastoreClusterAddKeySetParams
.groupKeySet`, `MTRJointFabricDatastoreClusterUpdateKeySetParams.groupKeySet` and every member of the classes
that carry one: the port prints
`MTRJointFabricDatastoreClusterDatastoreGroupKeySetStruct: ...; epochStartTime2:(null); groupKeyMulticastPolicy:0; >`
and the host prints the same string ending at `epochStartTime2`, because
`MTRJointFabricDatastoreClusterDatastoreGroupKeySetStruct` has no `groupKeyMulticastPolicy` in the HOST's SDK.
It is the member-SET rule one level down, inside a nested value. `predict.py` compares the OUTER member's
declaration, which is the same in both SDKs, and so reports the whole string as unexplained. The fix is to
apply the member-set rule to a nested `-description` before falling through to a value comparison. **That is
in the tree now**, as one rule applied at EVERY level of a value and not as a case for one class:

  * a level where the member NAMES differ is a member-SET difference - the two SDKs declare different members
    - and predicts the difference at and below it, naming the members;
  * a level where the names agree is compared member by member, and each differing member's value goes
    through the same rule;
  * a difference is predicted only when EVERY differing branch ends in a member set. One value difference
    anywhere makes the whole reading UNEXPLAINED, because a member-set difference beside it must not excuse
    it. That clause is what the second red control tests.

It is what took the `groupKeyMulticastPolicy` family: **23 unexplained is 21.** And the run carries TWO red
controls - the first mutates a flat value, which has to become unexplained; the second plants a member INSIDE
a port struct (`plantedByTheRedControl` on `MTRUnitTestingClusterSimpleStruct`, a class BOTH SDKs declare, so
the planted member is not a version difference and cannot be excused as one) and requires it to be NAMED
somewhere in the prediction. A rule that walks into values and excuses everything it finds would swallow that
one silently, and the run exits 1 if it does.

**THE 21 THAT REMAIN, per reading, in three families.**

**THE "Foundation-runtime" FAMILY WAS A PORT DEFECT, and the ruling was right.** The zap-generated
`-description` prints every octet string through BASE64, not through `%@` of the `NSData`:

    toolchain/.agent-work/upstreams/chip/src/darwin/Framework/CHIP/zap-generated/MTRStructsObjc.mm:788
        [NSString stringWithFormat:@"<%@: data:%@; fabricIndex:%@; >", NSStringFromClass([self class]),
        [_data base64EncodedStringWithOptions:0], _fabricIndex]

and it does so in EVERY generated family, not only in structs - **334 members across
`MTRStructsObjc.mm`'s 33 descriptions and `MTRCommandPayloadsObjc.mm`'s 40, and every `NSData` member among
them is base64'd and nothing else is** (read out of both files, not assumed). An empty `NSData`
base64-encodes to the empty string, which is exactly the `d:;` and `hostname:;` the host prints where the port
printed `{length = 0, bytes = 0x}`. 108 of the 1068 objects now carry the call. A **nullable** one needs no
special case: `base64EncodedStringWithOptions:` on nil returns nil and `%@` prints a nil argument as
`(null)`, which is what the host prints for a nil member.

`-base64EncodedStringWithOptions:` is iOS 7 and this library is carried from 6.0, so the call is
FoundationBackports' and not a hand-rolled encoder: `packages/a/apple-backports/registry/Foundation/base.json`
carries `-[NSData base64EncodedStringWithOptions:]` as `introduced 7.0, status implemented`, and
`MatterClusterBackports` already lists `libraries = {"FoundationBackports"}`
(`modules/apple/backports.lua:119`), so the object links it the way every other object of the library does.
Nothing was added to the link line and no encoder was written.

**That took the unexplained readings from 21 to 7:**

    params-diff: description  3231 identical, 42 predicted by the SDK difference, 7 unexplained
    params-diff: fresh        3232 identical, 41 predicted by the SDK difference, 7 unexplained
    params-diff: ownDescription 919 of the hosts 919 readings the port answers identically
    params-diff: alias          37 of the hosts 37 readings the port answers identically
    params-diff: red control 11 readings move, so this comparison can fail

**THE 7 ARE CLOSED, and all 7 by the framework's own source rather than by a tolerance.**

**`-init` now stores what the framework's own `-init` stores, read out of that framework's code.**
`tools/matter-init-source.py` is a reader over `project-chip/connectedhomeip` at the tag this repository
pins (`v1.7-te2`, commit `99a81bd32986c5292b0b1c9245c8e247c2ad717d`, Apache-2.0, cloned under this
repository's `.agent-work/upstreams/chip`). It reads every `- (instancetype)init` in
`src/darwin/Framework/CHIP` and writes one line per store into `tools/matter-init-defaults.tsv` with the
source's own expression and the file and line it came from - **3,578 stores over 977 classes, of which 826
are classes SDK 26.2 declares**. `tools/matter-generate.py` reads that table and writes the store.

A header says nothing about an initial value, which is the whole reason the table exists:
`MTRReadParams.filterByFabric` is a plain `BOOL` in `MTRCluster.h` and its `-init` stores `YES`.

    where each plain data class's -init stores come from: 813 the framework's own source writes,
    57 inherit an ancestor's, 54 have none in that tree
      5 member(s) the framework's -init stores at something other than the member's type zero,
      and the port writes that:
        MTRReadParams.filterByFabric: MTRCluster.mm:120 (bool:1)
        MTRReadParams.assumeUnknownAttributesReportable: MTRCluster.mm:121 (bool:1)
        MTRSubscribeParams.replaceExistingSubscriptions: MTRCluster.mm:292 (bool:1)
        MTRSubscribeParams.resubscribeAutomatically: MTRCluster.mm:293 (bool:1)
        MTRSubscribeParams.minInterval: MTRCluster.mm:294 (number:1)

**`MTRSubscribeParams` WAS NOT A MYSTERY, and the measurement that settles it is in the table.**
`params-probe.m` now walks the class and every superclass with `class_copyMethodList` and records which of
them carries `-init` in its OWN method list - a category's method is merged into the class's list, so a
class whose `@implementation` declares none and whose `(Deprecated)` category does is measured here the same
as one that declares it:

    initOwner  MTRSubscribeParams  -  self,MTRReadParams
    initOwner  MTRReadParams       -  self

so `[[MTRSubscribeParams alloc] init]` runs MTRSubscribeParams' OWN `-init` and then, through `[super init]`,
`MTRReadParams`' - and the framework's source says which one that is:

    toolchain/.agent-work/upstreams/chip/src/darwin/Framework/CHIP/MTRCluster.mm:184
        @implementation MTRSubscribeParams            <- no -init here, only initWithMinInterval:maxInterval:
    toolchain/.agent-work/upstreams/chip/src/darwin/Framework/CHIP/MTRCluster.mm:287
        @implementation MTRSubscribeParams (Deprecated)
        - (instancetype)init
        {
            if (self = [super init]) {
                _replaceExistingSubscriptions = YES;
                _resubscribeAutomatically = YES;
                _minInterval = @(1);
                _maxInterval = @(0);
            }
            return self;
        }

`MTRCluster.h:234` marks that `-init` and `+new` `MTR_DEPRECATED("Please use initWithMinInterval")` and
says in prose what they do: *"initialize with minInterval set to 1 and maxInterval set to 0, which will not
work on its own"*. `reportEventsUrgently` is the member that tells the two initialisers apart, and the host
holds `0` in it after `[[X alloc] init]` while `initWithMinInterval:maxInterval:` stores `YES`
(`MTRCluster.mm:189`) - so the reading is the category's initialiser and not the other one. That is
`MTRSubscribeParams`' three readings, and `MTRReadParams`' two are `MTRCluster.mm:120-121`.

**The designated initialiser, measured on the host (tests/backports/host/matter/params-init.m).** SDK 26.2
declares `initWithMinInterval:maxInterval:` (`MTRCluster.h:213`, "there are no default values") and the port's
class did not have it. The host, asked with (1, 10): `minInterval` 1 and `maxInterval` 10 as given,
`reportEventsUrgently`, `replaceExistingSubscriptions` and `resubscribeAutomatically` YES; `keepPreviousSubscriptions`
0 and `autoResubscribe` 1 read through those. (10, 1) is stored as given, and (nil, nil) stores nil and raises
nothing. A copy is a different object, and its intervals are the same objects as the original's. A mutable string
passed as `minInterval` is stored as a COPY, not as the argument. The body the port emits is the framework's
(`MTRCluster.mm:184-194`): `[super init]`, the three flags YES, and `[minInterval copy]`, `[maxInterval copy]`.
`keepPreviousSubscriptions` is the NEGATION of `replaceExistingSubscriptions`, through its getter and its setter: with
replace YES it reads 0, and setting it YES makes replace NO (measured on the host, Round 6 probe; the fresh row of
tests/backports/host/matter/host-measurements.tsv says NSNumber(0)). `autoResubscribe` is a straight `boolValue` of
`resubscribeAutomatically`, the setter taking 7 as YES. The generator's NEGATED_ALIASES carries the negation.

**The readers a stub answered, measured on the host (tests/backports/host/matterdifferential/behaviour.m: the
`assert.unwritten reader, completionHandler: spelling` and `own.handler write then read` rows).** On a controller
that has been shut down, every request ends in the framework's own no-node answer, MTRErrorDomain/6 "Invalid object
state.", delivered on the queue given. That holds for an unwritten reader of Identify (IdentifyTime), OnOff (OnOff)
and LevelControl (OnLevel) in both spellings, for an unwritten TestCluster Boolean through both readers, and for a
write then a read of TestCluster Boolean through either writer and either reader: the framework's read after the
write answers the same error, so nothing the write did is visible on the framework's side. The port keeps the value
written in the object's table and answers it; with nothing written it answers the no-node error, and no reader answers
nothing. `readAttributeBooleanWithParams:completion:` is not declared for TestCluster Boolean, so the params reader has
no measurement for Boolean. The WithParams family is measured on TestCluster ListFabricScoped
(`assert.unwritten reader, WithParams: completionHandler: spelling`, behaviour.sh's fifth entry): the framework's
answer for an unwritten reader, with nil params, is the same no-node error. The port's deprecated spelling forwards to
the current `readAttributeListFabricScopedWithParams:completion:`, which MTRBaseClusterUnitTesting declares.
(The probe the Round 6 measurements came from is not committed; the rows above make the same calls.)

**A store does not decide the value where the two SDKs declare the member differently, and the 10 that do
not are named.** The framework's own rule is *a nonnull member gets the zero, a nullable one nil* - the
generated sources write one line per member, `@(0)` for the nonnull ones and `nil` for the nullable ones -
so a store only decides a value for a member THIS SDK declares nonnull. Apple relaxed the nullability on 9
members between the tag and SDK 26.2 and tightened it on 6, and those 15 are a difference between two
releases rather than a value:

    10 member(s) whose store does NOT decide the value, because the two SDKs declare the member
    differently and the port keeps this one's:
      MTRContentControlClusterAddBonusTimeParams.bonusTime: '@(0)' at MTRCommandPayloadsObjc.mm:37584, and this SDK declares it nullable
      MTRContentControlClusterUpdatePINParams.oldPIN: '@""' at MTRCommandPayloadsObjc.mm:37185, and this SDK declares it nullable
      MTRGroupcastClusterLeaveGroupResponseParams.endpoints: '[NSArray array]' at MTRCommandPayloadsObjc.mm:16324, and this SDK declares it nullable
      MTRGroupcastClusterMembershipStruct.endpoints: 'nil' at MTRStructsObjc.mm:4973, and this SDK declares it nonnull and the store holds no value
      MTRGroupcastClusterMembershipStruct.hasAuxiliaryACL: 'nil' at MTRStructsObjc.mm:4977, and this SDK declares it nonnull and the store holds no value
      MTRJointFabricAdministratorClusterICACCSRResponseParams.icaccsr: 'nil' at MTRCommandPayloadsObjc.mm:49388, and this SDK declares it nonnull and the store holds no value
      MTRJointFabricDatastoreClusterUpdateAdminParams.nodeID: '@(0)' at MTRCommandPayloadsObjc.mm:48095, and this SDK declares it nullable
      MTRJointFabricDatastoreClusterUpdateGroupParams.groupPermission: 'nil' at MTRCommandPayloadsObjc.mm:47795, and this SDK declares it nonnull and the store holds no value
      MTRPushAVStreamTransportClusterCMAFContainerOptionsStruct.sessionGroup: 'nil' at MTRStructsObjc.mm:12773, and this SDK declares it nonnull and the store holds no value
      MTRPushAVStreamTransportClusterCMAFContainerOptionsStruct.trackName: 'nil' at MTRStructsObjc.mm:12775, and this SDK declares it nonnull and the store holds no value

**The two class-name readings are the deprecated/current pair, and the pair is read out of the header.**
`MTRTestClusterClusterNestedStruct.c` and `MTRTestClusterClusterTestEventEvent.arg4` are declared with the
DEPRECATED type `MTRTestClusterClusterSimpleStruct *`, and the framework's own `-init` stores
`[MTRUnitTestingClusterSimpleStruct new]` into them (`MTRStructsObjc.mm:14623`, `:14788`) - the deprecated
class is a SUBCLASS of what the member holds, so the header's promise cannot be kept by anything that stores
what the framework stores, and a port that allocated what the header says printed
`<MTRTestClusterClusterSimpleStruct: ... >` where the host prints `<MTRUnitTestingClusterSimpleStruct: ... >`.
The port now stores the class it holds, and it declares the member with that class. **Which class is a
deprecated spelling of which is not a list: it is each class's OWN annotation**, which
`payload_classes()` reads off the line above the `@interface` -

    MTRStructsObjc.h:2828   MTR_DEPRECATED("Please use MTRUnitTestingClusterSimpleStruct", ios(16.1, 16.4), ...)
    MTRStructsObjc.h:2829   @interface MTRTestClusterClusterSimpleStruct : MTRUnitTestingClusterSimpleStruct

    120 of the 1330 classes the SDK declares carry their own MTR_DEPRECATED("Please use X") annotation,
    naming another CLASS: 62 of them are in the plain data family
    5 member(s) this SDK types with a DEPRECATED CLASS, declared with the class that one is a spelling of:
      MTRTestClusterClusterNestedStruct.c: MTRTestClusterClusterSimpleStruct -> MTRUnitTestingClusterSimpleStruct
      MTRTestClusterClusterNullablesAndOptionalsStruct.nullableStruct: -> MTRUnitTestingClusterSimpleStruct
      MTRTestClusterClusterNullablesAndOptionalsStruct.optionalStruct: -> MTRUnitTestingClusterSimpleStruct
      MTRTestClusterClusterNullablesAndOptionalsStruct.nullableOptionalStruct: -> MTRUnitTestingClusterSimpleStruct
      MTRTestClusterClusterTestEventEvent.arg4: MTRTestClusterClusterSimpleStruct -> MTRUnitTestingClusterSimpleStruct

**What the regeneration changed, measured by `diff -rq` over the 1,068 objects: 5 files.** Four objects and
one line of `RevenantMatterTypes.h` five times over - the 5 `-init` stores above and the 5 declared types.
Nothing else in the tree moved, which is the check that matters here: 3,267 members and the derived rule
they used to come from agree with the framework's own source everywhere else.

**`predict.py` classifies a differing CLASS NAME the same way it classifies a differing member set, and the
third red control holds that down.** A class name that differs is predicted exactly when one of the two is
the deprecated spelling of the other, read out of the same annotation; a name that is not in such a pair is
UNEXPLAINED. The port's own run has **no** class-name difference left to predict - the two readings are
identical now - so the clause is exercised by a plant: `MTRUnitTestingClusterNestedStruct`'s
`NSStringFromClass([self class])` is replaced by a class name no annotation pairs, and the run requires it to
come out UNEXPLAINED.

**The run, whole, and its exit status 0:**

    params-diff: description  3238 identical, 42 predicted by the SDK difference, 0 unexplained
    params-diff: fresh        3239 identical, 41 predicted by the SDK difference, 0 unexplained
    params-diff: classes the host has 919, absent 5, raised 0
    params-diff: ownDescription 919 of the hosts 919 readings the port answers identically
    params-diff: alias          37 of the hosts 37 readings the port answers identically
    params-diff: red control 13 readings move, so this comparison can fail
    params-diff: red control 2 readings become UNEXPLAINED, so the prediction looks at the port
    params-diff: nested red control 30 reading(s) name plantedByTheRedControl, so a planted nested
    params-diff: class-name red control 4 reading(s) name an unpaired class as UNEXPLAINED, and 4
    params-diff:   reading(s) name a PAIRED one as predicted, so the clause excuses the spelling and
    params-diff:   nothing else, and the reading of the unmutated port is 0 unexplained either way

**Three defects in the harness itself, found by running it, all three fixed at the cause.**

* `compile()` took its OBJECT directory and always read the sources from `$build/port`, so both planted
  binaries were built from the pristine tree and the controls measured nothing - and the run then printed
  the message that the control had failed, which is what a control that measured nothing looks like from the
  outside. The source directory is an argument now, and a plant is compared with the file it was made from
  before it is compiled.
* `predict.py` exits non-zero when a reading is unexplained, which is what a mutant is FOR, and under
  `set -e` that ended the script at its first red control. That is why the previous turn's log stops there
  and why this one was committed unrun.
* `split_members()` split a member body on every `"; "`, and a nested `-description` carries its own `"; "`
  separators: `c:<MTRUnitTestingClusterSimpleStruct: a:0; b:0; ... >` is ONE member and splitting it gave
  `['a:0', 'b:0', 'c:<MTRUnitTestingClusterSimpleStruct: a:0', 'b:0', ...]`, a list that compares EQUAL on
  both sides for any two values differing only in the class they name. Only a separator at bracket depth
  zero separates, and `level()` now keeps BOTH class names of a wrapped string - the one inside and the one
  around it - because a difference in either is a difference in the class the value has.

**132 of the 6,560 readings the probe took were cut short, and are not any more.** A TSV field cannot hold a
newline and an empty `NSArray`'s `-description` is one: a struct holding one printed its members up to `d:(`
and the rest of the line landed on the next, so `fresh`/`described` rows were compared over their first 180
characters and the file carried 277 lines that were the pieces of other lines. The same count on both sides,
so such a pair still compared equal - and nothing after the cut was examined. `params-probe.m` now flattens a
newline and a tab out of every value it prints, and the file has no continuation line left.

**A CLASS ROW IS DATED BY THE CLASS'S OWN ANNOTATION, and 2,923 rows move because of it.** The rule used
to read the block's FIRST annotated member, which is a different question: `MTRCluster.h:40` writes
`MTR_AVAILABLE(ios(16.1), macos(13.0), watchos(9.1), tvos(16.1))` on the line above
`@interface MTRCluster` at :41, and the first annotated member of that block is `endpointID` at 17.4, so the
class row said 17.4 - a class dated two releases after the class that exists. Every row the committed file
carried for `MTRCluster` is at 16.1, because the row was corrected by hand while the tool kept producing the
other value, which is the worst of the two: a regeneration disagreed with the file it was supposed to
reproduce. `releases_of()` now reads the annotation above the class's own `@interface` FIRST, through
`GENERATE.own_announcement()`, and a member's own annotation dates the class only where the class's own names
no release - `MTR_PROVISIONALLY_AVAILABLE`, which expands to an export or to `NS_UNAVAILABLE` and states no
iOS version at all, and is 316 of the 1,068 rows.

    rows over the base: 17606 kept in its order, 0 appended, 0 dropped
    2923 row(s) whose value changed, and every one of them the `introduced` field alone:
      185 class, 2210 method, 528 property
    every movement is DOWN, to an EARLIER release, and none of them reaches the 16.0 fallback:
      MTRCluster                                     17.4 -> 16.1   (MTRCluster.h:40)
      MTRBaseClusterBridgedDeviceBasicInformation    18.4 -> 16.4   (MTRBaseClusters.h:3414)
      MTRBaseClusterAccessControl                    18.4 -> 16.1   (MTRBackwardsCompatShims.h)
      MTRBaseClusterOnOff                            16.4 -> 16.1   (MTRBaseClusters.h:212)
      MTRTestClusterClusterSimpleStruct              16.0 -> 16.1   (its own MTR_DEPRECATED states ios(16.1))

The last one is why the reader takes a deprecation as well as an availability: a deprecated alias class is
annotated `MTR_DEPRECATED("Please use X", ios(16.1, 16.4), ...)`, which states a RANGE where an availability
states one release, so the reader takes the first number - the release the class is available from, which is
what a class row asks - and 69 class rows move off the 16.0 fallback onto the 16.1 their own annotation
states. The `.unannotated` sidecar loses those 443 declarations and adds none.

**`--base` makes the registry write ROWS, and that is the only way it may be written.** The tool writes its
entries in the order the objects' FILE NAMES sort in, which is not the committed file's order: the 144 cluster
rows are there first and the 924 plain data rows were appended under them, so writing the tool's own order
replaced all 17,606 rows and changed nothing but their order - the failure `toolchain/AGENTS.md` records for three
different families on 2026-09-30. With `--base` every row the file holds keeps its place, a row the run adds
is appended, a row the file holds that the run no longer produces is DROPPED and named, and every row that
keeps its place is compared value for value and its change printed by name. So the run's list of moved rows
IS the file's diff, which is checked here: **2,923 insertions and 2,923 deletions, one line per moved row, no
reformat**, and 443 deletions in the sidecar, none added. A second run over the file the first one wrote
changes nothing at all.

**THE ALIAS CLASSES HOLD NO STORAGE, and that is MEASURED now.** The framework declares a deprecated alias
class `@dynamic` and nothing else - `MTRStructsObjc.mm:14469

    @implementation MTRTestClusterClusterSimpleStruct : MTRUnitTestingClusterSimpleStruct
    @dynamic a;
    ...
    @dynamic h;
    @end

- no ivar, no accessor, no `-init`, no `-copyWithZone:`, no `-description`, all four inherited - so every
member lives in the superclass's ivars and ONE storage serves both names. **226 members over 60 classes** are
shaped so, measured over the 60 classes whose own `MTR_DEPRECATED("Please use X")` names their own superclass,
and the port emitted an ivar and an accessor per member for every one of them: two storages over one set of
members. The 60 objects now carry the framework's shape.

**`params-probe.m` asks, and the answer is on both sides.** A new question, one line per member, writes a value
of the member's own type through an ALIAS reference, reads it back through a CURRENT one, writes a second value
through the current reference and reads that back through the alias - and then reads the shape the runtime
reports, because **the value half cannot see two storages on its own** and saying otherwise would be a check
that never fails. Objective-C dispatch walks up from the RECEIVER's class and never from the static type of
the variable, so a write through one spelling and a read through the other reach the same accessor in both
shapes and answer the same value; what differs is WHICH accessor that is, and how many ivars the class has.
On this host, over all 230 member lines: `ownIvars=0` on every one, `sizeDelta=0` on every one, the
superclass present on every one, `ownAccessors=no` on 226 and `yes` on the 4 of `MTRControllerFactoryParams`,
and `currentRead` equal to the value written first with `aliasReadBack` equal to the value written second on
every one of the 230. **One storage, measured.**

**The run, whole, and its exit status 0.** heavy.sh's own record of it:

    2026-10-04T14:11:19 slow 1783s waited 1783s ran exit=0 sh tests/backports/host/matter/params-diff.sh

    predict.py: host SDK .../MacOSX.sdk declares 1484 Matter classes
    predict.py: port SDK .../iPhoneOS26.2.sdk declares 1330 Matter classes
    params-diff: description  3238 identical, 42 predicted by the SDK difference, 0 unexplained
    params-diff: fresh        3239 identical, 41 predicted by the SDK difference, 0 unexplained
    params-diff: classes the host has 919, absent 5, raised 0
    params-diff: ownDescription 919 of the hosts 919 readings the port answers identically
    params-diff: alias          37 of the hosts 37 readings the port answers identically
    params-diff: storage       230 of the hosts 230 readings the port answers identically
    params-diff: red control 13 readings move, so this comparison can fail
    params-diff: red control 2 readings become UNEXPLAINED, so the prediction looks at the port
    params-diff: nested red control 30 reading(s) name plantedByTheRedControl, so a planted nested
    params-diff:   member is reported and not excused
    params-diff: class-name red control 4 reading(s) name an unpaired class as UNEXPLAINED, and 4
    params-diff:   reading(s) name a PAIRED one as predicted, so the clause excuses the spelling and
    params-diff:   nothing else, and the reading of the unmutated port is 0 unexplained either way
    params-diff: alias-storage red control 8 reading(s) move and 8 of them name ownIvars=, so one
    params-diff:   storage for a deprecated alias class is something this comparison can see failing

**A RED CONTROL THAT COULD NOT FAIL, found by running the script and fixed at the cause.** `predict.py` read
the PORT's SDK from `ROOT/.agent-work/sdk262` - a path that is in no checkout on this machine, neither this
worktree nor the main one. `matter_headers()` returns `[]` for a directory that is not there,
`payload_classes([])` is `{}`, and from an empty port table **every member the port declares reads as "not in
the port's"**, which is the clause that excuses a value difference by a declaration difference. So the control
that mutates a port value and requires the prediction to call it UNEXPLAINED could not fail: this run's first
attempt printed `FAIL the red control - mutating a port value did not move the prediction`, and the mutation
HAD moved 13 readings - they were excused, by an empty table.

The path now comes from the environment as `MATTER_SDK_262`, the same variable `params-diff.sh` already finds
the SDK with, and `declarations()` **stops** when it cannot read the SDK it is named rather than returning an
empty class table. Both counts are printed above, because `0 unexplained` over an empty port table is not a
result. With the real SDK the unmutated numbers are unchanged - `3238 identical, 42 predicted, 0 unexplained` -
so nothing the empty table was excusing was load-bearing, and the mutant now comes out UNEXPLAINED for the
right reason:

    MTRGroupsClusterAddGroupParams.groupID: UNEXPLAINED, both SDKs declare NSNumber * nonnull, the host holds
    '0' and the port '7': a value difference, and no declaration difference accounts for it

That fix is `tests/backports/host/matter/predict.py` and the four `MATTER_SDK_262=` prefixes in
`params-diff.sh`. It is not part of this band's family and it was committed with it because the evidence for
item 1 comes out of that script and a script whose control cannot fail cannot hold anything down.

`sizeDelta` is `class_getInstanceSize(alias) - class_getInstanceSize(its runtime superclass)`, which is 0 for a
class that adds no ivar and 32 or 64 for one that adds a member or two - and it was 32 on all 60 objects
before this change. The superclass in that line is the RUNTIME's own answer rather than the name the driver
carries, because the host's framework is built from an SDK that spells 63 of these members' types the other
way round and a line printing the driver's name would be reporting two SDKs rather than two storages.

**THE 60TH CLASS IS THE ONE THAT IS NOT `@dynamic`, and its four members come out of the framework's source.**
`MTRControllerFactoryParams` declares four members its superclass does not, and writes the accessors by hand,
each forwarding to a differently named member of the superclass - `MTRDeviceControllerFactory.mm:1385`

    - (id<MTRPersistentStorageDelegate>)storageDelegate
    {
        return static_cast<id<MTRPersistentStorageDelegate>>(self.storage);
    }

The header's deprecation text names the member for three of the four (`Please use shouldStartServer`,
`Please use productAttestationAuthorityCertificates`, `Please use certificationDeclarationCertificates`) and
says **"Please use the storage property"** for `storageDelegate`, which is prose and names no member. So
`tools/matter-init-source.py` reads that table out of the same pinned tree as the `-init` defaults and writes
`tools/matter-alias-accessors.tsv`: 11 hand-written accessors over 3 classes, of which 8 are this one's. The
port writes the four accessors and gives the class no storage, so its `ownAccessors` reads `yes` on the host
and in the port - which is right, and is the framework's shape rather than a second difference.

**The registry rows for all 226 say what the object does, and 119 rows are gone.** `properties_of()` reads a
`@dynamic` line back as a property, so the 226 rows stay and their `effect` changes from "the property is a
readwrite ivar of the object's own" to what is now true: the member is answered by the class this one is a
spelling of, and a value written through this name is the value read through the other one. 119 METHOD rows
are dropped - `-init` on all 60 and `-copyWithZone:` on 59 - because the objects define no method at all any
more: both are inherited from the class each one is a spelling of, which is what `initOwner` measures on the
host (`initOwner MTRTestClusterClusterSimpleStruct - MTRUnitTestingClusterSimpleStruct`). 7 rows are added,
the three setters `MTRControllerFactoryParams` now writes by hand. No corpus row names `-init` or
`-copyWithZone:` on any of the 60 classes, and `check_registry` examines class, function and constant rows
only, so nothing the gate asks about is in the dropped set.

## The 904 ledger rows, and the 100 that are not closed

Re-running the ledger's own `status = missing` filter against this tree and asking which of those rows is
OWNED by one of the 79 concrete clusters 16.4 does not declare - the owner read out of `-[Class selector:]`
and `+[Class selector:]`, not out of a dotted api - gives **904 rows over 50 of the 79 classes: 50 class,
854 method.** Those 50 classes are the ones the corpus has a `missing` row for at all; the other 29 of the 79
carry no row, which is a fact about the corpus and not about this port.

**804 of the 904 are now carried by a registry row, verbatim, spelled the way the ledger spells them.** The
other 100 are 50 pairs of `-[Class init]` and `+[Class new]`, one pair per class, and they are not closed:
`contract_of()` drops both by rule, because the header marks them `NS_UNAVAILABLE` and they are NSObject's,
so the object's own method list cannot contain them. **This is not new and not specific to the concrete
family** - `-[MTRBaseClusterIdentify init]` and `+[MTRBaseClusterIdentify new]` are still `missing` in the
ledger with the reason "selector init is not", for a class this port has carried since the family began. The
port does not define either, and both are answered at run time by NSObject's own, which is inherited rather
than absent; whether a ledger row whose selector is inherited counts as `implemented` or wants `decide` is a
question about the ledger, not about this family, and it is left open here rather than answered by editing a
row.

## The 20 generated-only classes (proposal; no change to them)

The 20 classes this tree defines and the real stack does not (`class-overlap.tsv`, `no`). Row counts are the SDK 26.2
surface rows the registry in this package holds for each class (`registry/Matter/ios16.json`, owner read from the
class name of each row). The core column is the pinned connectedhomeip v1.6.1.0 source (commit 3bcdd56b, the
`matter` package's `v1.6.1.0` source tree): `ClusterId.h` of the cluster by its name under
`zzz_generated/app-common/clusters/`, and `zzz_generated/app-common/app-common/zap-generated/ids/Clusters.h`.

| class | class rows | property rows | method rows | pinned core cluster |
| --- | --- | --- | --- | --- |
| MTRBaseClusterAppleDeviceInformation | 1 | 7 | 22 | no cluster ID in the core |
| MTRBaseClusterAppleLockCluster | 1 | 6 | 21 | no cluster ID in the core |
| MTRBaseClusterTimer | 1 | 8 | 30 | no cluster ID in the core |
| MTRClusterAppleDeviceInformation | 1 | 7 | 8 | no cluster ID in the core |
| MTRClusterAppleLockCluster | 1 | 6 | 9 | no cluster ID in the core |
| MTRClusterTimer | 1 | 8 | 14 | no cluster ID in the core |
| MTRDoorLockClusterAppleAliroCredentialStruct | 1 | 3 | 3 | cluster 0x0101 present |
| MTRDoorLockClusterAppleAliroLockOperationErrorEvent | 1 | 6 | 3 | cluster 0x0101 present |
| MTRDoorLockClusterAppleAliroLockOperationEvent | 1 | 5 | 3 | cluster 0x0101 present |
| MTRDoorLockClusterAppleAliroLockUserChangeEvent | 1 | 8 | 3 | cluster 0x0101 present |
| MTRDoorLockClusterAppleClearAliroCredentialParams | 1 | 4 | 3 | cluster 0x0101 present |
| MTRDoorLockClusterAppleClearAliroReaderConfigParams | 1 | 3 | 3 | cluster 0x0101 present |
| MTRDoorLockClusterAppleGetAliroCredentialStatusParams | 1 | 4 | 3 | cluster 0x0101 present |
| MTRDoorLockClusterAppleSetAliroCredentialParams | 1 | 7 | 3 | cluster 0x0101 present |
| MTRDoorLockClusterAppleSetAliroReaderConfigParams | 1 | 7 | 3 | cluster 0x0101 present |
| MTRGroupcastClusterExpireGracePeriodParams | 1 | 3 | 2 | cluster 0x0065 present |
| MTRTimerClusterAddTimeParams | 1 | 3 | 2 | no cluster ID in the core |
| MTRTimerClusterReduceTimeParams | 1 | 3 | 2 | no cluster ID in the core |
| MTRTimerClusterResetTimerParams | 1 | 2 | 2 | no cluster ID in the core |
| MTRTimerClusterSetTimerParams | 1 | 3 | 2 | no cluster ID in the core |

- `Timer` (four `...Params` classes and the `Timer` cluster classes) and `AppleDeviceInformation` and `AppleLockCluster`:
  the core has no cluster directory and no ID for them in `Clusters.h`. Nothing in the pinned core can serve them over
  the real transport; they stay an honest generated answer, or are dropped in a later round by a decision of the owner.
- The nine `DoorLockClusterApple...` classes: the core's DoorLock cluster (0x0101) is present with its Aliro reader
  configuration (`SetAliroReaderConfig`, `ClearAliroReaderConfig`) and Aliro attributes, but no Aliro credential command
  (`SetAliroCredential`, `GetAliroCredentialStatus`, `ClearAliroCredential`) appears in `CommandIds.h`. The Apple
  spelling is Apple's own, so the core answers the cluster and not these names.
- `MTRGroupcastClusterExpireGracePeriodParams`: the core's Groupcast cluster (0x0065) is present, and the core has no
  `ExpireGracePeriod` command in its generated sources.

## What the real stack's registry lacks, measured (v-matter9)

The removal rule "the real stack carries it, so the generated object goes" needs the real stack's registry to hold the
rows the object carries, or the rows go with it. It does not, for most of the 1188:

| the 1188 generated classes' rows in this package's registry | rows | in `packages/m/matter/registry` by kind and name |
| --- | --- | --- |
| class rows of the 854 the real registry has a class row for | 854 | 854 |
| property rows of those 854 | 3927 | 2197 |
| method rows of those 854 | 11605 | 8419 |
| class rows of the 334 the real registry has no class row for | 334 | 0 |
| property and method rows of those 334 | 1872 and 2394 | 0 and 0 |

So 9516 rows (4916 of the 854's, and 4600 of the 334's) are held by no registry in the tree. Removing the 1188
objects outright would leave those rows with no object behind them, and the registry check holds a row no build
answers as red; deleting the rows would lose them. The registry is written by `tools/matter-registry.lua` from the
SDK 26.2 surface corpus, and no corpus file is on the machine this section was measured on, so these rows cannot be
written into `packages/m/matter/registry` here. The decision (extend the corpus, keep the objects for the rows the
real stack's registry does not carry, or accept the loss) belongs to the coordinator.

## The real stack's registry after the corpus rerun (v-matter10)

`tools/matter-registry.lua` was rerun on `libMatterBackports.dylib` (v1.6.1.0, armv7) with
`coordination/corpus/sdk-26.2-surface.tsv` (24647 Matter rows). The corpus is on the machine now, so the 334 classes
above are answered by the corpus, not by a gap. The rerun carries 17061 of the 24647 rows.

- Two families whose names differ only in case wrote one file on the case-insensitive file system: the SDK spells the
  OTA cluster both ways (`MTROTA...` from 16.4, `MTROta...` from 16.1 to 16.4), and the later family overwrote the
  earlier one's rows. The committed registry therefore held no `MTROta...` row. The tool now merges families by their
  lowercase name into one file (the spelling that sorts first); the file `OtaSoftwareUpdateProvider.json` is now
  `OTASoftwareUpdateProvider.json`.
- Against the committed registry, by kind and name: 66 rows added (11 class, 1 constant, 8 method, 46 property): the
  `MTROta...` rows, and `MTROtaSoftwareUpdateProvider...Params` and `ClusterWakeOnLAN` among the classes.
- 19 rows dropped: the Apple-spelled Aliro methods of `MTRBaseClusterDoorLock` and `MTRClusterDoorLock`
  (`appleClearAliroReaderConfigWith...`, `readAttributeAppleAliro...`, `readAttributeAppleNumberOfAliro...`). The corpus
  marks all 48 `Apple...Aliro` rows `unavailable` (yes). The dylib defines none of them (`strings` finds
  `clearAliroReaderConfig` and `AppleAliro` nowhere): the unprefixed Aliro selectors are the ones it carries. The
  `Revenant/MTRBaseClusterDoorLock.mm` and `Revenant/MTRClusterDoorLock.mm` forwards that were meant to add them are not in
  the matter package's build (`packages/m/matter/xmake.lua` names no `revenant` directory), so they are not compiled.
- The other 29 of the 48 were never in the committed registry and stay out (unavailable).

The 1188 generated classes' rows against the new real registry (by kind and name; the 20 are not in this set):

| the 1188 generated classes' rows, owned by the class | rows | by kind (class / method / property) | in the real registry |
| --- | --- | --- | --- |
| homed: the same kind and name is in the real registry | 11512 | 864 / 8408 / 2240 | yes |
| unavailable: not in the real registry; the corpus marks it unavailable | 48 | 0 / 48 / 0 | no |
| absent: not in the corpus | 9426 | 324 / 5543 / 3559 | no |
| in the corpus, available, not in the real registry | 0 | 0 / 0 / 0 | no |

Of the 9426 absent rows, 2386 methods and 1829 properties belong to the 324 absent classes, and 3157 methods and
1730 properties belong to 864 classes the corpus does carry (for example `MTRBaseClusterTestCluster`, 1354 rows, and
the `...Params` and `...Struct` classes' `init` and `copyWithZone:`). 185 of the 1188 classes have only homed and
unavailable rows; the other 1003 have absent rows. Whether each absent row is declared in the SDK headers with a
provisional or unavailable mark is not measured yet (the per-row proof is open): the removal waits for it.

## The absent rows, proved against the SDK 26.2 headers, and the removal (v-matter11)

`tools/matter-absent-proof.lua` (Lua, `xmake l`) classifies each row of the 1188 generated classes that the SDK 26.2
corpus does not carry at all: 9426 rows (324 class, 5543 method, 3559 property). Each row's owner is read from the
Matter headers as its own `@interface` block and its categories, the block only; a member that block does not declare is
looked for in the superclass chain, never in another block of the same name. The output is `absent-proof.tsv` next to
`class-overlap.tsv`: one row per absent row, with category, kind, api, owner, the header line of the declaration, and
the detail.

The categories:

- **a, unavailable.** The declaration, or the `@interface` that encloses it, carries `MTR_PROVISIONALLY_AVAILABLE`. That
  macro expands to `_MTR_UNAVAILABLE` (`NS_UNAVAILABLE`) unless `MTR_ENABLE_PROVISIONAL` is set; it is not set, and its
  default is 0 (`MTRDefines.h:36-37`), with the expansions at `MTRDefines.h:94-96`. `MTR_UNSTABLE_API` (`:99-102`) and
  the explicit `NS_UNAVAILABLE` and `API_UNAVAILABLE` also count; none of them is in the absent rows.
- **p, accessor.** A getter `-[Class name]`, a setter `-[Class setName:]`, or a custom getter (`getter=name` in the
  property) of a property the owner declares available. The corpus spells that surface as the property row `Class.name`,
  which is available, and the real registry carries it. The accessor row is not a surface of its own.
- **b, inherited and available.** Declared available by a superclass, and homed there in the real registry; the row is
  counted against the superclass. b-homeless would stop the removal.
- **c, declared nowhere.** No block of the owner, its categories, or its superclass chain declares the member in the
  Matter headers.
- **x, neither.** Declared available by the owner and absent from the corpus. It stops the removal.

| category | class | method | property | rows |
| --- | --- | --- | --- | --- |
| a (unavailable) | 324 | 1570 | 975 | 2869 |
| p (accessor of an available property) | 0 | 83 | 0 | 83 |
| c (declared nowhere) | 0 | 3890 | 2584 | 6474 |
| b, b-homeless, x | 0 | 0 | 0 | 0 |
| total | 324 | 5543 | 3559 | 9426 |

Every a row is `MTR_PROVISIONALLY_AVAILABLE`: 2869 of 2869, and no other mark. Three examples, from the header:

- class `MTRBaseClusterChime`: `MTRBaseClusters.h:15546`, the `@interface` line, with the mark on the line before it
  (`MTRBaseClusters.h:15545`).
- method `-[MTRBaseClusterChime playChimeSoundWithCompletion:]`: `MTRBaseClusters.h:15554`, the mark on the declaration.
- property `MTRCameraAVSettingsUserLevelManagementClusterDPTZRelativeMoveParams.deltaX`:
  `MTRCommandPayloadsObjc.h:12213`, the mark on the declaration.

The 83 p rows are accessors of properties that the corpus carries available, for example `MTRSubscribeParams`
`keepPreviousSubscriptions` (getter and setter), and `MTRSwitchClusterMultiPressCompleteEvent` `newPosition`, whose getter is
`getNewPosition` (`MTRStructsObjc.h:783`, a custom getter, `MTR_DEPRECATED` and available).

The 6474 c rows, in three groups, measured:

- **3380 NSObject-rooted.** 2536 methods (`init`, `new`, `copyWithZone:`, `description`) and 844 `.description`
  properties of struct, event and parameter classes. The walk reaches `NSObject`, and no Matter block declares these for
  the owner: they are the members the root (NSObject, and the NSCopying protocol) gives every object. The committed
  registry has 858 `init`, 855 `copyWithZone:` and 849 `description` rows, and none for a `MTRBaseCluster...` class. Their
  removal with the classes is a decision for the coordinator (see Open); the rule that a homeless available row stops the
  removal would stop it here, because NSObject is not a Matter registry row.
- **1354 MTRBaseClusterTestCluster methods, selectors the SDK never declares.** For example
  `writeAttributeIdentifyTimeWithValue:completionHandler:`: the SDK declares `writeAttributeIdentifyTimeWithValue:completion:`
  (`MTRBaseClusters.h:47`), and `subscribeAttributeIdentifyTimeWithMinInterval:maxInterval:params:...`, where the SDK has
  `subscribeAttributeIdentifyTimeWithParams:...`. `MTRBaseClusterTestCluster` is an empty deprecated `@interface`
  (`MTRBaseClusters.h:17913`) over `MTRBaseClusterUnitTesting`, which declares the SDK's spellings.
- **1740 properties of other classes, names no header declares.** For example `MTRClusterZoneManagement.ZonesValues`;
  `AbsMaxPowerValues`, `ExpressedStateValues`, `NightVisionValues` and `SupportedMapsValues` have no mention in the 62
  headers.

Of the 6474 c rows, 2201 are c rows whose exact member another class declares: the generator put it on the wrong owner.
The rest are declared nowhere in the headers.

**The 48 Aliro rows, and the DoorLock forwards.** The 48 generated rows that the real registry does not carry and the
corpus marks unavailable are all Aliro methods of `MTRBaseClusterDoorLock` (33) and `MTRClusterDoorLock` (15): 36 spelled
with `Apple` (for example `+[MTRBaseClusterDoorLock readAttributeAppleAliroBLEAdvertisingVersionWithClusterStateCache:endpoint:queue:completion:]`,
`16.1`, `unavailable` yes, `container`) and 12 unprefixed. The corpus carries all 36 Apple-spelled rows as unavailable
(`yes`). The dylib defines none of the Apple-spelled selectors. The `Revenant/MTRBaseClusterDoorLock.mm` and
`Revenant/MTRClusterDoorLock.mm` forwards that would have added them are not in `packages/m/matter/xmake.lua`, so nothing
compiled them; both are deleted (coordinator's decision 6), and the Aliro rows leave with the generated classes. No
app can call them: the SDK declares them unavailable.

**The removal.** The 1185 generated classes' object files are removed (1185 tracked files). The 20 generated-only classes and the three base classes they subclass stay (23 `RevenantMatter*.m`): MTRCluster, MTRGenericCluster and MTRGenericBaseCluster are the superclasses of the 20, and the release has no Matter framework, so the library is the only provider of them. The first removal dropped those three and the 6.1.3 gate failed to link the 20 (undefined `_OBJC_CLASS_$_MTRGenericBaseCluster` and `_OBJC_CLASS_$_MTRGenericCluster`).
`registry/Matter/ios16.json` goes from 21250 entries to 268 (the 20982 rows owned by
the 1185 are dropped; the 268 owned by the 23 stay, the same bytes in the same order). `registry/Matter/ios16.json.unannotated`
goes from 10334 lines to 264, by the same owner rule. The `matter` option's description no longer names 1208 objects.
Every row of the removed classes is either homed in `packages/m/matter/registry` (11512 rows, by kind and name: 864 classes,
8408 methods, 2240 properties), unavailable in the corpus (48), absent from the corpus and proved above (9426).

## Open

- Coordinator, decision: the 3380 NSObject-rooted rows (`init`, `new`, `copyWithZone:`, `description`) were removed with
  their classes as c rows. They are the root's members, not Matter's. Say if they must stay as a registry row of their
  own, or be homed on `NSObject`; the proof does not decide that.
- The guard `tests/addon/matter_objects_test.lua` (`failures`, pure Lua): fails when a committed `Matter/RevenantMatter*.m`
  implements a class of `class-overlap.tsv` `yes`, or a class the real registry carries (the three base classes exempt), and pins the count at 23. The
  coordinator adds its suite name `matter_objects_test` to `coordination/run_light_tests.lua`.
- `tools/matter-generate.py` still writes the 1185 classes. It is Python and was not run; a re-run would re-emit them, and
  the guard catches that.
- The emulator app `tests/backports/emulate/matter/app/main.m` names three removed classes: `MTRBaseClusterIdentify`,
  `MTRBaseClusterOnOff`, `MTRBaseClusterTestCluster`. They are SDK classes; the real stack provides them when the
  Matter framework is present.

## The emit rule and its closure (v-matter12)

`tools/matter-closure.lua` (Lua, `xmake l`) computes the rule the generator must follow. A generated class is emitted
only when both hold: (1) `class-overlap.tsv` says the real stack does not carry it, and (2) it is in the closure of the
app-usable SDK 26.2 Matter API. The closure starts from the 985 class rows of the SDK 26.2 corpus whose `@interface` the
shipped headers do not mark unavailable, and adds every Matter class an available member of a class in the closure names
(a parameter, return or property type, a collection element, through a typedef a member uses), and every superclass.
The output is `emit-closure.tsv`, one row per generator input class (1208), with the reason. The light guard is
`tests/addon/matter_closure_test.lua`.

Measured on the SDK 26.2 headers:

- The headers define 1330 classes. The 985 corpus rows are all unmarked, so all 985 are roots.
- The closure adds no class: no available member of a root names a class outside the roots (0 edges). The 345 defined
  classes outside the corpus are all marked `MTR_PROVISIONALLY_AVAILABLE` (344 are generator inputs, one is not), and no
  available member names one of them. No protocol body names any of the 344 generator-only classes.
- Of the 1208 generator inputs: the real stack carries 1188 and not 20. 864 are in the closure (all corpus classes, all
  carried by the real stack); 344 are not (324 carried by the real stack, 20 not).
- **Emitted under the rule: 0 classes.** The 20 generator-only classes (real stack `no`) are unavailable in SDK 26.2 and
  reached by nothing: not public API. The three base classes (`MTRCluster`, `MTRGenericCluster`, `MTRGenericBaseCluster`)
  are roots, so they are in the closure by (2), but the real stack carries them, so condition (1) says no.

The rule therefore retires the whole committed family. Six of the 20 are cluster classes that subclass the bases
(three from `MTRGenericBaseCluster`, three from `MTRGenericCluster`); the other 14 are NSObject-rooted structs, events and
params. Once the 20 go, no committed class subclasses the three bases. Keeping the three needs an exception to condition
(1), which v-matter11 made for the 6.1.3 link and which this rule does not allow. The coordinator rules (see the report). Until then
`tests/addon/matter_closure_test.lua` pins the 23 committed objects as pending; the list only shrinks.

`tools/matter-generate.py` is not ported in this band. Its acceptance, byte-for-byte on the emit-yes classes, is empty
under the rule as it stands, so a port needs the rule's decision first, and the port itself is about 4415 lines.

## The retirement (v-matter13)

**Ruling (coordinator, option a, the owner's rule as written).** The emit rule (v-matter12) emits none of the 1208
generator inputs, so nothing is generated for Matter. The 20 real-stack-`no` classes are unavailable in the SDK 26.2
headers (`MTR_PROVISIONALLY_AVAILABLE`) and reached by nothing an app can call. The three base classes (MTRCluster,
MTRGenericCluster, MTRGenericBaseCluster) are carried by the real stack, which is condition (1) of the rule, and with the 20
gone no generated class needs them. No exception to condition (1) is made.

**Measured counts, before the removal (the v-matter12 tip this series builds on).** 1208 generator inputs; 0 emitted (column 5 of
`emit-closure.tsv`); 23 committed `Matter/RevenantMatter*.m` objects (the three base classes and the 20); 268 registry rows in
`registry/Matter/ios16.json`, all owned by the 23 classes (every row's class name is one of them); 1 `.unannotated` sidecar.

**Removed.**
- The 23 objects, `Matter/RevenantMatterTypes.h` and `Matter/RevenantMatterQueueStorage.h` (the two headers only they included).
- `registry/Matter/ios16.json` and `registry/Matter/ios16.json.unannotated`. The folder is gone.
- The library `MatterClusterBackports`: its entry in `modules/apple/backports.lua`, the `matter` config and its library
  line in `packages/a/apple-backports/xmake.lua`. Nothing else in the tree named it (grep over the tree).
- `tests/backports/emulate/matter`, the emulator app that loaded that library by name. Its three classes
  (MTRBaseClusterIdentify, MTRBaseClusterOnOff, MTRBaseClusterTestCluster) had already gone in v-matter11.
- The generator and the tables only it read: `tools/matter-generate.py`, `tools/matter-init-defaults.tsv`,
  `tools/matter-alias-accessors.tsv`, and `tools/matter-registry.py`, which loaded the generator by path.
- The writer of those two tables, `tools/matter-init-source.py`, by the coordinator's ruling (no Python stays for a retired path).
- The host harnesses of the generated family, which called the generator or compared the port's generated classes with the
  host framework: `tests/backports/host/matter/` `contracts/`, `excluded.txt`, `host-measurements.tsv`, `params-diff.sh`,
  `params-init.m`, `params-init.sh`, `params-probe.m`, `plants.sh`, `predict.py`; and all of `tests/backports/host/matterdifferential/`
  (behaviour, cases, commands, not-built lists, params-fill, probe programs, run.sh, shutdown-controller).
- `tests/addon/matter_skip_test.lua`, whose subject (the differential's skip list) is gone, and the two cluster lists it read
  (`Matter/clusters-emitted.txt`, `Matter/generic-clusters-emitted.txt`), which had no other reader.
- `tools/matter-host-refusals.tsv`, read only by the generator and the removed differential.

**Kept, and why.** `tools/matter-closure.lua` and `facts/Matter/emit-closure.tsv` are the proof that nothing is generated.
The real stack's host-side harness stays: `tests/backports/host/matter/run.sh`, `members.m` (the host's own surface, read from a
live process) and `pure.m` (one program held against the host framework), with `tools/matter-host-diff.lua` and
`tools/matter-pure-diff.lua`, which compare them with the real stack's `libMatterBackports.dylib` (`packages/m/matter/facts/MatterFramework.md`).
Those files test only revenant@matter's surface and read nothing of the removed family.

**The matter option (ruling, coordinator).** Its removal is accepted. The real stack's route is revenant@matter: its
`libMatterBackports.dylib` is built and installed by `packages/m/matter`, which depends on apple-backports, so no
apple-backports option can deliver it.

**Guards.** `tests/addon/matter_closure_test.lua` has no pending list: it fails on any committed `Matter/RevenantMatter*.m`.
`tests/addon/matter_objects_test.lua` pins 0 and no longer excepts the base classes. Each fails on one added class object
(a mutant defining MTRBaseClusterOnOff: four failures, then removed; see the report).

**What an application gets for Matter now.**
- From apple-backports: nothing. No file in this package defines or installs a Matter cluster class.
- From revenant@matter: the real stack's `libMatterBackports.dylib` (v1.6.1.0, armv7), installed under
  `/usr/lib/revenant/org.revenant.apple-backports/libMatterBackports.dylib` (`packages/m/matter/xmake.lua:339`). That package
  depends on apple-backports (`packages/m/matter/xmake.lua:28`), so apple-backports cannot deliver it: the dependency would be
  a cycle. The owner's acceptance "the matter option still delivers the real stack's libMatterBackports" cannot hold from this
  package; the option is removed instead.
- The 1185 generated classes that are no longer built: each row is carried by the real stack's registry
  (`packages/m/matter/registry`), unavailable in the SDK 26.2 headers, or declared nowhere in them (`absent-proof.tsv`, v-matter11).
