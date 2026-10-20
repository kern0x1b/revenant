# Intents on a release with no assistant daemon

What `libIntentsBackports.dylib` is, and what each part of it answers on a device whose iOS
carries no `Intents.framework` and no assistant daemon. Every registry entry of this framework
points here.

## What this release has, and what it does not

The device is an iPhone 4S or an iPad 2 on iOS 6.1.3 (and the same builds are gated at 4.3).
There is no `Intents.framework` at all: the framework arrived with iOS 8, and the armv7 caches
this port is built against end at iOS 10.3.4, so the last release that ever had `Intents` is
beyond the newest release any armv7 device can run. There is no `SiriKit`, no assistant
daemon, no intent handler extension host, and no Spotlight index that reads an interaction.

So none of what `Intents` is *for* — the system reading a donation, launching an extension to
handle an intent, asking a user to disambiguate a value, speaking a vocabulary — can happen
here. That is the wall. Everything that does not go through it is implemented, and the seams
say what they are instead of answering as though the system were there.

## The two stores an application really keeps

The brief for this framework is that an application can donate, store and query interactions
and resolve and handle in process. Both stores are real files under **this application's own**
`Application Support/Revenant/Intents`, written with
`NSPropertyListSerialization` and read back through the same path
(`RevenantIntentsStore.m`), every write and every read on one serial queue, and every failure the
error the file system or the serialisation reported.

* `INInteraction donateInteractionWithCompletion:` stamps the interaction's date interval with
  the moment of the donation, archives it into the store and calls the handler with `nil` — or
  with the error the write failed with. The two `revenant_interactions` accessors on
  `INInteraction` read the store back, newest last, and the deletion methods remove by
  identifier, by group identifier and all of them.
* `INVocabulary` writes the phrases an application offers, by type and in order, and
  `revenant_vocabularyStringsOfType:` reads a type back.

On a release that does carry `Intents.framework` the release's own framework is linked instead
(`modules/apple/backports.lua`'s band drops this library's objects and re-exports the
framework's symbols), so none of this store is in a process that has the real thing.

## Where a value is read instead of by the system

`INIntentResolutionResult` has no public accessors in the SDK, and none of its subclasses have
any: on a release with Siri the system is the reader, so the result's value is a value the
system reads and an application never sees. Here the application that resolves a parameter is
the reader, so `RevenantIntentsResolution.h` declares four accessors on the class — the resolved
value, the values to disambiguate, the value to confirm, and which of the six answers this is —
plus the one method every answer is built with. They are named as Revenant's own, collide with
nothing Apple has, and are absent on a release that carries the framework itself.

A resolution result whose value is a value type rather than an object —
`INBooleanResolutionResult`, `INIntegerResolutionResult`, `INDoubleResolutionResult` and the
result classes typed with an enumeration — carries it as an `NSNumber` of the same value: the
base has nowhere to hold a value of the subclass's own type, and the value is what the
parameter was given.

## The classes whose behaviour is more than storage

Ten classes are hand written in `RevenantIntents100.m` (the iOS 10.0.1 group) and one in
`RevenantIntents110.m` (the 11.0 group); the other 104 of the 10.0.1 group, the 22 of the 10.3
group and the 56 generated classes of the 11.0 group are generated into `IN10_0.m`, `IN10_3.m`
and `IN11_0.m` by `tools/intents/gen-intents.lua` from the SDK's own declarations. The generated
objects are built at build time into `.gen/Intents/` by `tools/intents/objects.lua` (from
`REVENANT_GEN_SDK`, the iPhoneOS 26.2 SDK) and are not committed; `IN17_0.m` and the hand-written
files stay in the folder. What is hand written and why:

* **`INIntent`** makes a UUID string `identifier` where the intent is made. The system assigns
  that identifier when the interaction carrying the intent is donated; there is no system, and
  the store above is keyed by it, so it is made here instead — the same kind of value, at the
  moment the object exists. `intentDescription` is the class's own words with the framework's
  `IN` prefix and `Intent` suffix off (`INSendMessageIntent` reads "Send message"): the SDK does
  not document how the framework derives it and this release has no framework to ask, and nil
  would be the only other answer. `setImage:forParameterNamed:` and `imageForParameterNamed:`
  keep a real map of images by parameter name; `keyImage` returns the first parameter that has
  one, in parameter name order so that it is the same on every call.
* **`INImage`** is an opaque token in the SDK: it has no property and no reader at all. The
  three ways of being made are therefore all there is to implement, and each one really
  obtains what it says. `imageNamed:` resolves the name in the app's own asset catalogue
  through UIKit, which is where the catalogue lives on every release this port covers.
  `systemImageNamed:` answers the names UIKit draws. It calls `+[UIImage systemImageNamed:]`, the one symbol
  table of the UIKit band (`UIKit/UIImage+Symbols.m`), and carries the PNG the way `imageNamed:` does, so
  nothing here keeps a second list. See "+[INImage systemImageNamed:]" below for what the host answers. `imageWithURL:` reads the URL and answers no image for a URL it cannot read, which is the
  header's own `nullable` on that method.
* **`INIntentSetImageKeyPath`** and **`_INIntentSetImageKeyPath`** have **no row**. No Objective-C
  header declares either: the iPhoneOS 16.5 and macOS 27 SDKs on this machine have no hit in the
  Intents framework's headers (16.4 and 26.2 are not installed here). The Objective-C runtime loads
  neither: `NSProtocolFromString` answers NO for both on Catalyst and macOS (`tests/backports/host/intents-remaining`,
  golden lines `protocol INIntentSetImageKeyPath NO`). The SDK's Swift overlay declares both as Swift-only
  protocols, `public protocol INIntentSetImageKeyPath : Intents._INIntentSetImageKeyPath` and
  `public protocol _INIntentSetImageKeyPath`, each `@available(iOS 10.0, macOS 11.0, ...)`, in
  `usr/lib/swift/Intents.swiftmodule/*.swiftinterface` and `usr/lib/swift/libswiftIntents.tbd`. The two
  methods they serve, `-[INIntent setImage:forParameterNamed:]` and `-[INIntent imageForParameterNamed:]`,
  are marked `NS_REFINED_FOR_SWIFT` in `INIntent.h`, which is why a search of the headers finds the methods
  and not the protocols. A Swift-only protocol has no Objective-C protocol object to carry, so
  `tools/intents/gen-registry.py` skips the two names (`SWIFT_ONLY_PROTOCOLS`) and writes no row for them.
  The earlier `absent` rows, with a reason that named no header, were not an answer and are removed.
* **`INPreferences`** answers `INSiriAuthorizationStatusRestricted` for
  `siriAuthorizationStatus`, which is the header's own wording for a system where Siri
  services are restricted and the user cannot change the answer, and it hands the same status
  to `requestSiriAuthorization:`'s handler rather than waiting for a prompt this release cannot
  show. `siriLanguageCode` answers the language the release itself is set to: the SDK defines it
  as the code Siri is configured with, there is no Siri setting to read, and the device's own
  language is the one a voice would use. **This is a divergence and it is deliberate**: a
  release that has Siri answers Siri's setting, not the device's.
* **`INExtension`**'s own surface is empty; the one requirement it inherits from
  `INIntentHandlerProviding` is `handlerForIntent:`, which answers the instance of the loaded
  class that conforms to the intent's own handling protocol (`INRequestRideIntent` is handled by
  something conforming to `INRequestRideIntentHandling`) and responds to `-handleIntent:`, and
  nil where there is none. There is no extension host here to instantiate anything, so the
  lookup is the whole of what it can do.
* **`INPaymentMethod`**, **`INRideCompletionStatus`**, **`INSpeakableString`** and
  **`INIntentResolutionResult`** are described in their registry entries; each of them either
  carries a derived answer (`INRideCompletionStatus`'s six flags and amounts, computed from the
  outcome its factory methods name) or a value Apple's own class keeps in a way this port names.
* **`INParameter`** (iOS 11.0, `RevenantIntents110.m`) is a class and a key path, which is all the
  header's own two properties say, so that is what it keeps. `isEqualToParameter:` compares those
  two, and `setIndex:forSubKeyPath:` / `indexForSubKeyPath:` keep a real index per sub key path,
  answering `NSNotFound` for one that was never given an index — an `NSUInteger` return has no
  other way of saying there is none. `-[INInteraction parameterValueForParameter:]` reads the
  intent's value by that key path, **one component at a time and each asked for by name first**,
  because a key-value lookup of a path the object has no accessor for raises: a path the intent
  does not have answers nil.

Two shapes of resolution result the iOS 11.0 group adds:

* **A result that wraps another result.** Five classes take a resolution result in their
  designated initialiser and expose no value of their own —
  `INSendPaymentPayeeResolutionResult` takes an `INPersonResolutionResult`, and the four others
  of that shape. The wrapper answers **what the result it was given answers**, status included,
  so its whole state is taken rather than re-derived: a caller that resolves a payee must get the
  answer the person result gave. That is one method on the base,
  `-revenant_adoptResolutionOf:`, and the generator emits the call when a parameter's type is a
  resolution result.
* **`+unsupportedForReason:`** (also iOS 11.0, on those five and on every later group's
  equivalent). The reason is an enumeration and the classes expose **no reader for it in their own
  headers** — on the releases that added the method, the system is the only one who reads it, and
  this release has none. A result that swallowed the reason would answer "unsupported" with no way
  to say why, which is a different answer from the one the method's name promises, so the reason
  is kept and read back through `-revenant_unsupportedReason` beside the four other accessors.

### One bare `-init` that the header declares *available*, and the loop that never visited it

`INListCarsIntent`'s own entry in `INListCarsIntent.h:17` is

    - (instancetype)init NS_DESIGNATED_INITIALIZER;

Available, and the class's only initialiser: it is an `INIntent` with no property of its own, so
the whole of it is the superclass's `-init`. `INIntent` declares none of its own, so that is
`NSObject`'s, and nothing in the chain marks one unavailable - the selector can be spelled, so the
body is `return [super init];` and no IMP is reached through.

Its row said `absent` with the reason *"the header marks the initialiser unavailable, so a port
cannot call it"*, which is false of this header. The cause is a gap in the generator, not a
judgement: the loop that writes an initialiser body visits only selectors spelled `initWith…:`,
so a bare `-init` reached the file only through the separate block that exists for the classes
whose header marks one unavailable, and this class is not one of those. Its body is written by
hand in `EXTRA_METHODS` for that reason, and the registry row's `source` says so rather than
carrying the sentence about the 110 `-init` rows a header really does mark.

What the release was asked, and how:

    sh tools/intents/probe-host-absent.sh packages/a/apple-backports/registry/Intents/ios16.json

    ios16.json  -[INListCarsIntent init]  found=yes answers=yes declared-by=INListCarsIntent init=object
    # absent rows: 1, control rows: 464 implemented rows of the same files
    # rows=465 parsed=465 unparsed=0 found=465 answered=214 inherited-from-NSObject=25

`declared-by=INListCarsIntent` is the column that separates this row from the 110: there, the
selector is declared by `NSObject` and the port has to forward through an IMP because the header
forbids naming it; here the class declares it itself and the header permits the name. `init=object`
is `[[INListCarsIntent alloc] init]` on the host's own class, through the IMP, since a compile-time
call to a member the port's SDK marks unavailable does not build. All 465 names were found in the
same process, so the row's `yes` is the release's and not the reader's.

## What is generated, and what that means for a reader

`IN10_0.m` and `IN10_3.m` are generated, and the generator refuses to emit a body it cannot
justify: an initialiser parameter that names no property of the class or of a superclass and has
no line in `PARAMETER_PROPERTIES` stops the run rather than being dropped, and a member whose
type is a class of a later group is left `@dynamic` and takes an entry of its own that says so.
The registry is written from the generator's report of what it emitted, read back out of the
emitted text, so an entry cannot claim a member the library does not carry
(`tools/intents/gen-registry.py`).

Four places where the SDK's own names differ and the generator is told where a value goes,
each read off the header of iPhoneOS 16.4:

* `INBillPayee`'s and `INPaymentAccount`'s initialisers take `number:` and the class exposes it
  as `accountNumber` — the class's one `NSString` property.
* `INPriceRange`: the header's own comment on `minimumPrice` is "the lowest of the two prices
  used to construct this range", so `initWithRangeBetweenPrice:andPrice:` feeds the first price
  to the minimum and the second to the maximum, and `initWithPrice:` gives both ends the one
  price.
* `INPerson`'s `contactSuggestion` is declared `getter=isContactSuggestion`, so the initialiser
  that spells its parameter `isContactSuggestion:` is matched through the getter's own name.
The copy in the revenant-coding package reads the property an ivar belongs to through the `V_` field
of its own attributes — the way the runtime pairs them, so a property whose ivar is not spelled
after it is still found — and then reads the ownership out of the **field list** that follows the
type field, one character at a time, skipping the `G…`/`S…`/`V…` payloads. A property is copied
exactly when `C` is among those flags, and `&` (retain), `W` (weak) and their absence (assign) mean
it is not. Measured with the port's own compiler for `armv7-apple-ios6.1.3`:

| header | attributes | copied |
|---|---|---|
| `strong`, `retain` | `T@"X",&,N,V_p` | no — the ownership is `&` |
| `copy` | `T@"X",C,N,V_p` | yes |
| `assign` | `T@"X",N,V_p` | no |
| `weak` | `T@"X",W,N,V_p` | no |
| `readonly, strong` | `T@"X",R,&,N,V_p` | no — `R` is *readonly* |
| `getter=isFoo` | `T@"X",&,N,GisFoo,V_p` | no — `G` starts a payload |

Searching the string instead would read the `C` of **`INCar`**, the `S` of `NSString` and the `R`
of a readonly, which is how three `strong` properties of the 10.0.1 group were being copied.

### A success that says nothing is a notRequired

The host's own framework logs, for a success whose value is the "nothing to say" case of its
enumeration, `Success resolution with INCarSignalOptionsUnknown will be reformed to notRequired.`
(observed on the host's own Intents, 2026-09-27, and for nine enumerations: `INCarSignalOptions`,
`INTaskStatus`, `INRadioType`, `INRelativeReference`, `INRelativeSetting`, `INTaskPriority`,
`INVisualCodeType`, `INWorkoutGoalUnitType`, `INWorkoutLocationType`). A success that says nothing
is a success with nothing to say, which is what `notRequired` means, so the generated
`+successWithResolved…:` of a result of one of those enumerations builds a **notRequired** for its
zero case and a success for any other. The list is `NEUTRAL_ENUMERATIONS` in the generator, and it
is the host's own list of what it reform, not a guess about which enums have a zero case.

* A subclass initialiser that keeps a value its superclass declares **read-only**
  (`INRestaurantGuest`'s `nameComponents`, which is `INPerson`'s) calls the superclass's own
  designated initialiser, with the value it has and `nil` or `0` for the arguments the header
  marks `nullable`. For the six nullable arguments that is the only value a subclass initialiser
  can have, and the result holds nil for them.
* **The one exception is measured, not assumed.** `INPerson`'s designated initialiser takes
  `personHandle` *nonnull* (`INPerson.h:27`, inside `NS_ASSUME_NONNULL_BEGIN`, and the only
  parameter of the five that is not marked `nullable`), and nothing in the SDK's own headers says
  where a subclass would get one. The generator therefore **refuses to chain** and those four
  initialisers — `INRestaurantGuest`'s and its three siblings' — are left unimplemented, with
  their own registry entries saying so. It does not claim Apple's class does the same, and it
  does not pass nil to a parameter the SDK forbids: a call the header rules out is not a way to
  make an initialiser fit.
* The same refusal covers a class whose superclass declares a value read-only and offers **no
  designated initialiser at all** to put it in (`INBoatReservation`'s `itemReference`, which is
  `INReservation`'s): there is no chain to make, and a body would have to store the value in this
  class's own copy of a property it does not own.

### The groups above iOS 10.3 and what places them

The `armv7` ladder this package is gated against ends at iOS 10.3.4 — the newest release any
`armv7` device can run — so for the 11.0 group and everything above it **no held release cache
exports a single one of these symbols**. There is no measurement to be had, and the object file
of a group is placed by the header's own availability annotation, which is the one source
`modules/apple/backports.lua`'s `releases_in()` falls back to. The band machine handles that
correctly: a point at 11.0 or later matches no `armv7` release in the firmware catalogue, so no
band is cut for it and the API is carried by the last band that exists (iOS 10.3.4), which is the
newest release an `armv7` device runs and does need it. `release-split` confirms the split is
clean, one release per object file, on the ladder it has.

On **arm64** the same groups are reachable, and the `arm64` band plan *would* name caches to
fetch for the points between them. That is not measured here: this package is gated for `armv7`,
and the caches an `arm64` band would need are not held. It is the first thing to settle before
those groups can be called done for `arm64`.

The header and the release caches disagree more than once, and the caches decide the object file
every time:

* `INPaymentStatusResolutionResult` — the header says iOS 10.0, the armv7 caches of 10.0.1 do not
  export it, and it appears in 10.3. The header's own annotation stays in its registry entry,
  because that is what an application compiling against the SDK is told.
* `INCallRecordTypeResolutionResult` — the header says 11.0 and the 10.0.1 cache has it, so it
  rides in `IN10_0_1.m` with the 10.0.1 group and not in `IN11_0.m`.
* `INCallRecordResolutionResult` — the header says 16.2 and the 16.0 cache has it.

A member whose type the SDK's headers only `@class` forward declare was held back until EventKit was linked:
`INDateComponentsRange`'s `initWithEKRecurrenceRule:` takes **EventKit's** class. It is implemented now, as
described in the EventKit section below. The property of the same name, whose type *is* carried, was always
implemented.

### The six members iOS 17.0 added to INMessage

`INMessage` is a class of the 10.0.1 group, so `IN10_0_1.m` defines it. The six members iOS
17.0 added to it were sitting `absent` with the reason "the SDK's own headers do not declare this
member, so there is nothing to answer" - a claim about the SDK **of 16.4**, which this package
compiles against, and not about any release. All six are declared by the header of iPhoneOS 26.2,
each `API_AVAILABLE(ios(17.0), watchos(10.0))`:

```
$ grep -n "attachmentFiles\|linkMetadata\|numberOfAttachments" \
    ~/.xmake/packages/i/iphoneos-sdk/26.2/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk/System/Library/Frameworks/Intents.framework/Headers/INMessage.h
72:                   attachmentFiles:(nullable NSArray<INFile *> *)attachmentFiles API_AVAILABLE(ios(17.0), watchos(10.0)) API_UNAVAILABLE(macos);
126:                      linkMetadata:(nullable INMessageLinkMetadata *)linkMetadata API_AVAILABLE(ios(17.0), watchos(10.0)) API_UNAVAILABLE(macos);
137:               numberOfAttachments:(nullable NSNumber *)numberOfAttachments API_AVAILABLE(ios(17.0), watchos(10.0)) API_UNAVAILABLE(macos);
198:@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY)  NSArray<INFile *> *attachmentFiles API_AVAILABLE(ios(17.0), watchos(10.0)) API_UNAVAILABLE(macosx);
200:@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) NSNumber *numberOfAttachments API_AVAILABLE(ios(17.0), watchos(10.0)) API_UNAVAILABLE(macosx);
204:@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) INMessageLinkMetadata *linkMetadata API_AVAILABLE(ios(17.0), watchos(10.0)) API_UNAVAILABLE(macosx);
```

and the registry's own source says the same, `coordination/corpus/sdk-26.2-surface.tsv`, one row
per name at 17.0. So the reason was false about the release and true about the port, and the six
are now written by hand in `Intents/IN17_0.m`.

The cause is one word in `tools/intents/generate.sh`: the 10.0.1 and 10.3 groups run with
`newer: no`, so `gen-intents.py` reads only the port's own SDK for their classes, and a member
only iPhoneOS 26.2 declares is invisible to them. The 12.0, 16.0 and 18.0 groups already run with
`newer: yes`. Flipping it for the 10.0.1 group would generate these six where they belong - in
`IN10_0_1.m`, beside the class, in the file's own `@implementation`, with the ivars the revenant-coding
walker reads - but it rewrites `registry/Intents/ios10.json` and `IN10_0_1.m` whole, and both belong
to other slices of the same file. Until it is flipped the six are answered by the category, and
`coordination/crutches.md` carries the entry.

**What a release this port deploys on carries.** Neither band end carries the class at all, and
the run carries its own control - the 10.0.1 rung is in it and does carry `INMessage`, so a zero on
6.1.3 and 4.3 is the release's and not the reader's:

```
$ REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua INMessage 6.1.3 4.3 10.0.1
# (cache paths below abbreviated to ~; the tool prints them absolute)
6.1.3     ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming INMessage 0
         classes 11378, of which INMessage* 0
         protocols 1171, of which INMessage* 0
4.3       ~/.revenant/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming INMessage 0
         classes 7187, of which INMessage* 0
         protocols 564, of which INMessage* 0
10.0.1    ~/.revenant/dyld/10.0.1/dyld_shared_cache_armv7s
         images 1082, of which naming INMessage 0
         classes 39319, of which INMessage* 3 (INMessage INMessageAttributeOptionsResolutionResult INMessageAttributeResolutionResult)
         protocols 6111, of which INMessage* 1 (INMessageExport)
control: 4 name(s) beginning INMessage found in this run, so a zero on another rung is the release's and not the reader's
```

**Which held release first carries each name.** `tools/cache-index/first-rung.lua`, over the whole
ladder, with a nonsense name in the same run as the negative control. Read it as PRESENCE and
nothing else: `numberOfAttachments` reads 3.0 and `linkMetadata` reads 10.0.1, and neither is
`INMessage`'s - they are other classes' selectors of the same name, which is the same trap
`fileSystemRepresentation` sets, and it is why a selector's rung is never evidence about its owner.

```
$ printf '%s\n' 'initWithIdentifier:conversationIdentifier:content:dateSent:sender:recipients:groupName:messageType:serviceName:attachmentFiles:' \
    'initWithIdentifier:conversationIdentifier:content:dateSent:sender:recipients:groupName:serviceName:linkMetadata:' \
    'initWithIdentifier:conversationIdentifier:content:dateSent:sender:recipients:groupName:serviceName:messageType:numberOfAttachments:' \
    attachmentFiles numberOfAttachments linkMetadata revenantNoSuchSelector17Control \
  | xmake l tools/cache-index/first-rung.lua
initWithIdentifier:conversationIdentifier:content:dateSent:sender:recipients:groupName:messageType:serviceName:attachmentFiles:	18.0
initWithIdentifier:conversationIdentifier:content:dateSent:sender:recipients:groupName:serviceName:linkMetadata:	18.0
initWithIdentifier:conversationIdentifier:content:dateSent:sender:recipients:groupName:serviceName:messageType:numberOfAttachments:	18.0
attachmentFiles	18.0
numberOfAttachments	3.0
linkMetadata	10.0.1
revenantNoSuchSelector17Control	NONE
```

The armv7 ladder ends at 10.3.4 and the three initialisers and `attachmentFiles` first appear at
18.0, so no release this package is gated against has any of the six, and none could: they are
newer than every release an armv7 device runs. That is why the six are not answered by anything a
release has, and it is not a reason to leave them out - `INFile` (13.0) and `INMessageLinkMetadata`
(17.0) are both carried by this package, so the three values are objects the port already has and
what a caller gets back is the copy of what it passed.

**Where the three values are kept, and the three of the class's own methods this file answers.**
A class extension may declare ivars in a translation unit that does not hold the `@implementation` -
clang accepts it and the file compiles - and it does not link:

```
$ xcrun clang -fobjc-arc -framework Foundation -o t a.m b.m main.m
Undefined symbols for architecture arm64:
  "_OBJC_IVAR_$_Foo._lateIvar", referenced from:
      -[Foo(Late) lateIvar] in b.o
```

So the three live in an associated object each, and `-copyWithZone:`, `-encodeWithCoder:` and
`-initWithCoder:` - the class's own three, which walk its ivar list through the one helper in
`packages/r/revenant-coding` - are answered in `IN17_0.m` beside them, under the keys that helper
itself uses (`INMessage.attachmentFiles` and so on, which are the keys the class of iOS 17.0
occupies for the same three). Without that a copy and an archive of an `INMessage` would carry
ten of its thirteen values and drop exactly the three of 17.0. Those three methods are not API of
this release: the SDK's header declares none of them (the class takes them from `NSObject`'s
protocols), no registry row names any of them, and so nothing this file carries is placed by them.

## The four, and what is not carried

Four classes of this delivery are not implemented whole, and each says so in its own entry
rather than answering with a class that looks filled and is not: `INDateComponentsRange`'s
`recurrenceRule` (an `INRecurrenceRule`, which arrived with iOS 11), `INPaymentAccount`'s
`balance` and `secondaryBalance` (an `INBalanceAmount`, iOS 11), `INMessage`'s
`audioMessageFile` (an `INFile`, iOS 13) and `INIntent`'s `donationMetadata` (an
`INIntentDonationMetadata`, iOS 15). Each of those members is `@dynamic` — the header's
availability mark stays on it, so a port cannot call it, and `respondsToSelector:` answers no
instead of a process dying on an unrecognised selector. An initialiser that takes one of those
values is left unimplemented for the same reason and says so in its own entry.

## All 309 classes, and the nine declarations the port's SDK does not have

Every one of the SDK 26.2 surface's 309 Intents classes is carried: the measurement places them
at 10.0.1 (116), 10.3 (22), 11.0 (55), 12.0 (17), 16.0 (95) and 18.0 (4), one object file per
group, and `registry/Intents/` has a file for each.

Seven of those classes and the four declarations they are typed by are **newer than the SDK the
port compiles against**: the toolchain's `revenant@iphoneos-sdk` is iPhoneOS 16.4, and
`INMessageLinkMetadata` (iOS 17), `INUnsendMessagesIntent`/`INUnsendMessagesIntentResponse` and
`INEditMessageIntent`/`INEditMessageIntentResponse` (iOS 17), `INMessageReaction` and `INSticker`
(iOS 18) appear first in the SDK of 17.0 and 18.0. Their contracts are read from the headers of
**iPhoneOS 26.2** (the SDK that `tools/intents/generate.sh` asks for as `SDK_262`, which the coordinator
keeps unpacked and a worktree sweep will delete) and the
declaration the implementation compiles against is `RevenantIntents262.h` — the seven classes, the
two enumerations two of them are typed by, and the two response codes the two responses are typed
by. That is what a backport writes for API its SDK does not have, and the same generator builds
their bodies from the same declarations it builds every other class's from.

**Thirteen, not eleven:** the header declares seven classes, **four** enumerations and **two**
protocols, and the two protocols (`INUnsendMessagesIntentHandling`,
`INEditMessageIntentHandling`) were left out of the earlier count of what this file carries.

The generator takes a second AST for exactly this: `--dump-newer` is read for a class the port's
SDK does not declare at all, and **only** for those — a class both SDKs declare is taken from the
port's own, because that is the declaration the implementation compiles against and the newer one
names members (`INRelevantShortcut`, `INVoiceShortcut`) the port's headers do not.

### One class of the 16.0 group is an object file of its own

`INPaymentMethodResolutionResult` is in `INPaymentMethodResolutionResult10.3.m`, not in
`IN16_0.m`, and the reason is measured. The **armv7s cache of iOS 10.3.4 already exports it**,
while the caches of the 16.0 group's own release do not have the 94 classes it would have shared
an object with (`tools/intents/measure-group.lua`, which walks the release below the group's own
and names the classes it exports: 1 of 95, this one). One object that defines both is what
`modules/apple/backports.lua`'s `band()` refuses — "an object carries API that arrived in one
release, so split it" — and it refused it in the **armv7 band at 10.3.4** while the 6.1.3 gate,
which links the deployment band alone, did not. A one-class object is consistent in every band:
the release that has it re-exports the object, and every release that does not keeps it.

**The lesson, for every framework in this push:** the gate is a deployment-band check and the
package build is the per-band one. `xmake emulate install` stages every band and is what finds
this; `build-gate.lua` alone would not.

`INObjectCollection -initWithItems:` is the one member of the 16.0 group whose body is a
derivation rather than a store, and it is hand written in the generator with the header's own
words: `allItems` is the items, `sections` is them under one untitled section, and collation is
not indexed, because the items arrive in the order they were given.

The 16.0 and 18.0 groups are also the ones that are only reachable on **arm64**: no armv7 device
runs past 10.3.4, so for the armv7 band they are carried by the last band and cost nothing, and
for arm64 they need the band caches the arm64 plan names. Neither is measured here.

IntentsUI (58 rows, 43 of them entries, 15 absent with a reason each) is a library of its own,
`libIntentsUIBackports.dylib` over UIKit, and is in `facts/IntentsUI/IntentsUI.md`. AppIntents
(2323 rows) is a `swift-runtime` deliverable and is not here.

## INMessage of iOS 18: four rows that are `implemented`, and the measurement that moved them

Four rows of `registry/Intents/ios10.json` and one object, `Intents/RevenantIntents180.m`:

| row | kind | what answers it |
| --- | --- | --- |
| `-[INMessage initWithIdentifier:conversationIdentifier:content:dateSent:sender:recipients:groupName:serviceName:messageType:referencedMessage:reaction:]` | method | the category's initialiser, chaining to the class's own designated initialiser of 16.4 |
| `-[INMessage initWithIdentifier:conversationIdentifier:content:dateSent:sender:recipients:groupName:serviceName:messageType:referencedMessage:sticker:reaction:]` | method | the category's initialiser, same chain |
| `INMessage.sticker` | property | `-sticker` / `-setSticker:` in the same file |
| `INMessage.reaction` | property | `-reaction` / `-setReaction:` in the same file |

**What they were.** All four carried `absent` with the reason *"the SDK's own headers do not declare
this member, so there is nothing to answer"*, which is the one of the tree's absent reasons that
cites a declaration and names no measurement. It was also the wrong claim to make: it is a claim
about **the port's own SDK**, and `absent` is a claim about **a release**. Two of these names are
in the arm64e cache of iOS 18.0, so a release does answer them.

**The measurement.** `tools/release-split.lua` names it in its blind-spot note, for exactly this
case - a member that no exported symbol answers, which is every method of a category, because
`nm -gU` on such a file returns nothing:

    strings -a ~/.revenant/dyld/18.0/* > strings-18.0.txt      # 22522030 lines, 552128265 bytes
    strings -a ~/.revenant/dyld/6.1.3/* > strings-6.1.3.txt    #  4134954 lines,  73318374 bytes
    grep -x -c -F -e "$SELECTOR" strings-18.0.txt strings-6.1.3.txt

Both rungs in one run, a nonsense selector as the negative control, and the class's own selectors
of earlier releases as the positive controls:

    18.0  2  6.1.3  0  initWithIdentifier:...groupName:serviceName:messageType:referencedMessage:sticker:reaction:
    18.0  2  6.1.3  0  initWithIdentifier:...groupName:serviceName:messageType:referencedMessage:reaction:
    18.0  9  6.1.3  0  setSticker:
    18.0 57  6.1.3  0  sticker
    18.0  3  6.1.3  0  setReaction:
    18.0 28  6.1.3  0  reaction
    18.0  4  6.1.3  0  initWithIdentifier:...groupName:messageType:serviceName:                 <- control
    18.0  3  6.1.3  0  initWithIdentifier:...groupName:messageType:serviceName:attachmentFiles:   <- control
    18.0  0  6.1.3  0  revenantNoSuchSelector18Probe:                                                <- control

The selectors are the whole lines of the strings pass, which is why the `strings` pass exists at
all: a selector sits inside a binary blob in `__objc_methname`, and a raw `grep -x` over the cache
matches nothing and reports CONTROL FAILED. That is what the first run of this measurement did, and
it is why the controls are in it. The two positive controls were misspelled the first time too -
the 18.0 cache spells that class's initialiser `...groupName:messageType:serviceName:`, not the
order the 26.2 header writes for its own - and a misspelt control is indistinguishable from a
blind reader, so it has to be read and not assumed.

`6.1.3` answers 0 for all of them, including the positive controls, because it carries no Intents
at all: Intents arrived with iOS 10.0. That zero is the band end and not evidence against the
name, which is why the `18.0` rung above is the one that decides.

**The other half: the port's own SDK really does lack all four.** `grep -n 'sticker\|reaction\|referencedMessage\|DESIGNATED' INMessage.h`
over each of the three iPhoneOS 16.4 SDKs on this machine answers three lines - the
`NS_DESIGNATED_INITIALIZER` of 11.0, of 13.2 and of 16.0 - and no property at all. So the
generator, which reads that SDK's AST, had nothing to emit, and the four rows came out of it as
`not_declared`. The contract is therefore read from **iPhoneOS 26.2's own `INMessage.h`** - lines
139 to 178 for the two initialisers, 206 to 210 for the two properties, word for word - and
`RevenantIntents262.h` is where the port writes what its SDK does not have. Both types are already
carried: `INSticker` and `INMessageReaction` are two of the four classes of the 18.0 group and
`IN18_0.m` defines both.

**Where the bodies are, and the one place this shape differs from the tree's.** A member does not
have to arrive in its own object's release: `IN10_0_1.m` already carries `INMessage.serviceName`
(13.2), `INMessage.groupName` (11.0) and `INMessage.audioMessageFile` (16.0), and
`INIntent.donationMetadata` (15.0) was put beside its class in `RevenantIntents100.m`. **By that
shape these four belong in `IN10_0_1.m`,** with an ivar and a synthesised accessor each, and
`revenant_intents_copy`'s own ivar walk would then carry them with no further work.

They are not there, and the reason is coordination and not architecture: this slice holds **one**
object, the one for 18.0, and `IN10_0_1.m` is the 10.0 group's generated object, which another
slice's rows also land in - putting these four there means changing `gen-intents.py` to emit
members of a class the port SDK does not declare, and rewriting a generated file in flight. So
`RevenantIntents180.m` is a category on `INMessage` instead, the arrangement
`Photos/PHPickerConfiguration15.m` already uses for `PHPickerConfiguration`'s own iOS 15
properties. **What that costs, exactly:** the two values are held beside the object rather than in
it, because a category cannot add an ivar to a class another object implements, and three of the
class's own selectors have to be carried as well (below). Folding these four into `IN10_0_1.m`
later is a clean move that removes all three, and nothing in this file depends on them staying.

**The copy and the archive are the part that needs saying.** `INMessage` declares `NSCopying` and
`NSSecureCoding`, and the class's own `-copyWithZone:` / `-encodeWithCoder:` / `-initWithCoder:`
walk the ivar list, which cannot see what a category holds beside the object. Left alone they
would carry the whole message except these values: a silent wrong answer rather than a crash.
The category therefore carries those three selectors, each calling the package's own helper from
`RevenantCoding.h` (`revenant_intents_copy`, `revenant_intents_encode`, `revenant_intents_decode`,
`revenant_intents_super_init`) and adding this file's three values, so none of them repeats the ivar
walk and the copy stays true as the class grows. Clang's note that a category implements a method
its primary class also implements is that arrangement and is silenced for the reason
`PHPickerConfiguration15.m` gives. The archive keys are `RevenantCoding.h`'s own spelling (the class
that owns the value, then the value's own name), and none of the three collides with an ivar key:
`INMessage`'s ivars are `audioMessageFile`, `content`, `conversationIdentifier`, `dateSent`,
`groupName`, `identifier`, `messageType`, `recipients`, `sender` and `serviceName`.

**Both initialisers chain to `IN10_0_1.m`'s 13.2 one**, not to the 16.4 designated initialiser:
the 18.0 pair has no `audioMessageFile` parameter to hand it - the 26.2 header marks that property
deprecated and unavailable on ios - so there is nothing to pass, and nothing of the class's own
state is left unset.

**`referencedMessage:` is kept and not readable.** It is a parameter and not a property - the 26.2
header declares no accessor for it - so nothing on this port reads it back, and this file adds no
accessor, because an accessor the SDK does not declare is not a backport. The value the caller
handed is kept rather than dropped, so the object is whole.

**What is not verified here.** The four selectors answer on the host's own Intents and are in the
18.0 cache, and `RevenantIntents180.m` compiles clean for `armv7-apple-ios6.0`, `arm64-apple-ios12.0`
and `arm64e-apple-ios12.0` against the port's SDK. It has **not** been run: `INMessage` is a port
class that needs the whole `libIntentsBackports` linked, and this framework is device-unverified as
a whole (see above), so these four are device-unverified with it.

## Where the tables and the walker come from, and that nothing came from liblouis

**The braille tables are written from the standard, not copied from an implementation.**
liblouis is the implementation everyone uses and it is **LGPL**: read it, do not copy it, and
**this package never had a copy of it** — there is no liblouis in the tree, in the store or in
anything this work read. What is in `RevenantBraille.m` is written out here:

* the twenty-six letter cells, as the dot numbers the grade-1 alphabet gives each letter, and
  every cell the **Unicode braille pattern** those dots are (`U+2800 +` the dot bitmask, dot 1 the
  lowest bit), which is the published block's own definition;
* the capital sign as **dot 6** (`U+2820`), the number sign as **dots 3, 4, 5 and 6** (`U+283C`),
  the grade-1 indicator as **dots 5 and 6** (`U+2830`), and the digits `1-9` as `a-i` with `0` as
  `j`;
* the punctuation cells the standard covers with one cell, and the two places two characters share
  a cell, which the table says rather than the code inventing a second one;
* the run rules: one sign for a capital on its own, **twice** before a run of consecutive capitals,
  the number sign once for a run of digits, and the grade-1 indicator before a letter `a-j` that
  follows a digit.

The **coding walker** is this package's own: it walks a class's ivar list through the Objective-C
runtime, from the object's class up to `NSObject`, and encodes a value type by its bytes and an
object by its value. The one part that follows something outside is the **ownership read**, and
that is the runtime's own documented attribute format: a property's `property_getAttributes` string
ends in its backing ivar (`T@"NSString",C,N,V_name`), and the ownership is a flag in the field list
after the type field. The field-list walk and the table of what each declaration compiles to are in
this file, and the negative control for it is `tests/backports/callgen/ownership-test.lua`.

## What is not measured here

This framework's behaviour was written against the header of iPhoneOS 16.4 and measured against
macOS, where `Intents` exists as a framework, for the values the data classes carry and the
names they derive. It has **not** been run on the device or in the emulator: the
`donateInteractionWithCompletion:` path, the two stores, the resolution results and
`INPreferences`' three answers all need a run on the port itself before this file can say they
work rather than that they are the behaviour the header describes. Until that run, every entry
of this framework is **device-unverified**.

## The 110 `-[X init]`, what the header says and what the port answers

110 rows, one bare `-init` per class, and the reason they are `implemented` is not the header: the
header **denies** the method on every one of them, and a row that cited it would be citing the wrong
authority. These are the classes whose own SDK marks

    - (instancetype)init NS_UNAVAILABLE;

which is a compile-time marker. It says a caller must not *name* the selector. It does not say the
system has no answer, and the system has one — which is the thing that had to be measured before the
rows could move, and it is in the `source` of every one of them.

**What the host was measured to answer.** Not by hand any more. `tests/backports/host/intents/init-rows.m`
is the per-class harness, and `init-classes.txt` beside it is the class list it reads, so a row that
is added or moved is measured by the next run and not by an edit to a program. Through the IMP and
not by a call — a compile-time call is unavailable and cannot be, which is the same constraint the
emitted body is built around:

    $ sh tests/backports/host/intents/run-rows.sh
    $ build/init-rows tests/backports/host/intents/init-classes.txt

    control: INRevenantNoSuchClassForThisHarness reads absent, as it must
    control: NSObject, whose -init the SDK does not mark unavailable, has IMP non-NULL and answers
             an object through it
    control: INAirline declares 3 of its own, 3 of the 7 class_copyPropertyList answers
    ... 21 classes ...
    init-rows: 21 answer -init with an object, 0 do not

    class_getMethodImplementation(Cls, @selector(init))  non-NULL   on all twenty-one
    [[Cls alloc] init] through that IMP                    an object, no exception, on all twenty-one
    respondsToSelector:init                                 1           on all twenty-one
    every property the class's own header declares         nil, or the zero case of its enumeration

The twenty-one are the classes of `init-classes.txt`: `INAddMediaIntentResponse`, `INAirline`,
`INAirport`, `INAirportGate`, `INDeleteTasksIntentResponse`, `INFlight`,
`INGetReservationDetailsIntentResponse`, `INMediaDestination`, `INMediaSearch`, `INMediaUserContext`,
`INRentalCar`, `INReservation`, `INReservationAction`, `INSearchForMediaIntentResponse`, `INSeat`,
`INSnoozeTasksIntentResponse`, `INStartCallIntentResponse`, `INTicketedEvent`, `INTrainTrip`,
`INUpdateMediaAffinityIntentResponse`, `INUserContext`.

**Two corrections this harness found in the text it replaces, both of them real.**

- *"every declared property present and nil" was false of NSObject's own six.* `hash`, `superclass`,
  `description`, `debugDescription`, `class` and `zone` are declared on every class and can never be
  nil, and `class_copyPropertyList` answers them along with the class's own — seven entries for
  `INAirline`, of which three are its declaration. A check that had asked for nil of them would have
  failed on classes that answer perfectly, which is what the first run of the harness did: twenty of
  twenty-one FAIL. The walk now stops at NSObject, which is the only honest reading of "declared".
- *an enumeration property never reads nil.* `INMediaDestination`'s `mediaDestinationType` reads
  `NSNumber 0`, not nil, because that is what zeroed integer storage holds — and the framework says
  itself that this is the same thing: `NEUTRAL_ENUMERATIONS` in `gen-intents.py` is the host's own
  list of the enumerations whose zero case "will be reformed to notRequired", a success with nothing
  to say. Eleven of the twenty-one have such a property — `code` on the eight response classes,
  `mediaDestinationType`, `mediaType`, `sortOrder`, `reference`, `subscriptionStatus`,
  `reservationStatus`, `type`, `category`, `confirmationReason` — and every one of them reads the
  zero case. The rows quote that, not a nil that never happens.

What the harness does **not** settle, and what is owed: it compares the port's `-init` with the
system's through `tests/backports/host/prefix_selectors.py`, the tool `mpsmatrix/run.sh` uses to
rename the port's classes so its implementations are reached under names of their own. That rename
list is generated from the port's own object symbols, and the port's Intents sources additionally
need `RevenantIntents262.h` renamed with them, because that header re-declares the classes the port's
own SDK lacks and the host's has, and without the rename the host build fails with *duplicate
interface definition*. Until that run exists, what is proven for the port's own side is the compile,
the presence of each `-init` per `nm`, and the registry's own text.

**What the port now answers.** The same, by construction: the class defines `-init` even though the
header marks it unavailable — which compiles, because defining an unavailable method is allowed — and
forwards to the superclass's own `-init` through `class_getMethodImplementation(parent, selector)`,
never by name. The generator's rule is in `tools/intents/gen-intents.py`, in `own_init_blocked_here`:
`own_init_unavailable` walks the whole chain, which is the right question for an initialiser *with*
arguments, because such an initialiser stores them here and then has to reach a superclass `-init`; a
bare `-init` stores nothing, so the question is narrower — the selector it forwards to is the nearest
implementation in the chain, and only the one it would actually reach matters.

**Why `absent` was wrong and `implemented` is right.** Before this, all 110 were `absent` with the
reason *"the header marks the class's -init unavailable, so a port cannot call it"*. That reason was
true of a compile-time call and false of the class: leaving the method undefined sends a caller that
asks for it to a NULL IMP, which is worse than answering with an object whose properties are nil. The
marker forbids *naming* the selector at compile time, and that is the only thing it forbids.

## The five owed `-init` rows of the 10.0 group: inherited, and measured

Five rows were `owed`, each with the reason *"build -[X init]"* and the effect *"respondsToSelector:
answers NO"*: `-[INInteraction init]`, `-[INIntentResolutionResult init]`, `-[INPaymentMethod init]`,
`-[INRideCompletionStatus init]` and `-[INSpeakableString init]`. The effect was wrong. None of the five
classes defines `-init` in `Intents/RevenantIntents100.m`, and each inherits NSObject's, so
`respondsToSelector:init` is YES: the probe asks `instancesRespondToSelector:init` of each class, and on both sides it answers YES.

Whether an inherited `-init` is the right answer is the host's to say. The SDK header marks
`- (instancetype)init NS_UNAVAILABLE` on all five, the same marker as the 110 rows above, so a port
cannot name the selector and must not need to. `tests/backports/host/intents-init-owed/run.sh` measures
both sides from one probe source, `owed.m`:

    sh tests/backports/host/intents-init-owed/run.sh

The host build links the system's Intents for Catalyst, the target the port is built for. The port build
compiles `RevenantIntents100.m` with `RevenantCoding.m` and `RevenantIntentsStore.m`, under renamed class
symbols, as tests/backports/host/inimage-bridge does. The probe is built without ARC, so it owns what it
allocates. Both outputs are diffed. The plant is a port whose `INSpeakableString` answers nil for `-init`,
and its diff must be non-empty. Measured, the same on both sides, for all five:

    INInteraction             inherit NSObject object nonnil=- nonzero=- responds=YES
    INIntentResolutionResult  inherit NSObject object nonnil=- nonzero=- responds=YES
    INPaymentMethod           inherit NSObject object nonnil=- nonzero=- responds=YES
    INRideCompletionStatus    inherit NSObject object nonnil=- nonzero=- responds=YES
    INSpeakableString         inherit NSObject object nonnil=- nonzero=- responds=YES

So each class's `-init` IMP is NSObject's, `[[Cls alloc] init]` through that IMP answers an object with no
exception, no object-typed property of that fresh object reads non-nil, and no scalar property reads
non-zero. A struct-typed property is not read; none of the five has one (`unread 0`).

The two controls, read on the host only, show the reader finds both kinds: `INPaymentAmount` inherits
`-init` the same way, and `INListCarsIntent` declares its own. So a zero for the five is not a blind
reader's zero.

**Counts that differ, and do not decide the row.** The host's SDK declares more properties on these classes
than the port's release does: `INInteraction` has 11 object properties on the host and 5 on the port,
`INIntentResolutionResult` 5 and 0, `INPaymentMethod` 4 and 3, `INRideCompletionStatus` 3 and 3,
`INSpeakableString` 5 and 0. The diff does not compare these counts, because a release's list length is
not an answer to `-init`. It does compare every non-nil and every non-zero property either side reads, so
a property the host answers non-nil that the port lacks is a difference, and it is a property row's
business, which that row says.

**What was not measured.** The values of properties after a set, and any subclass of these five, which the
registry does not carry. The native macOS run in `tests/backports/host/intents-init` reads the same five
classes through its own golden file, which the 117-line population now includes: 117 golden lines, 0 differ,
and its plant fails. Its python guard counts 117 implemented rows, 117 listed classes and 117 golden lines,
and it was not run here, because python is not run in this band.

## INRideDriver's deprecated initialisers, and what the runtime carries beside the headers

The SDK headers no longer declare `-initWithHandle:displayName:image:rating:phoneNumber:` or
`-initWithHandle:nameComponents:image:rating:phoneNumber:` on `INRideDriver`: the 16.4 and 26.2 headers name
only `initWithPhoneNumber:`. The runtime still carries both, on Catalyst and on macOS, so the release carries
them and a header is not the answer. Their host answers are the golden file of
`tests/backports/host/intents-ride-driver/expected.txt`, measured by its `probe.m` on the Catalyst host:

* the handle is kept as the value of an `INPersonHandle` of type `0` (Unknown), with a nil label, and the
  person handle is made even when the handle is nil, so its value is then nil;
* a nil `displayName` is the handle, and a nil handle with a nil `displayName` is `""`; a `displayName` that
  is given is kept verbatim, `""` included;
* with components, `displayName` is the given name and the family name, each only when it is not nil and not
  empty, joined by one space with the given name first. The middle name, prefix, suffix and nickname are not
  used. Components that make no name (`nil`, or only a nickname or suffix) give the handle, and no handle gives
  `""`. A part that is only spaces is text and is kept, so `" "` stays `" "`;
* the components are kept as given, and `rating` and `phoneNumber` are kept verbatim, nil included.

Not measured: the order of the name in another locale (the machine is `en_US`, and the formatter's order is
read here as given-first), and a non-nil image.

The port's half is built the same way. `RevenantIntents262.h` declares nothing under `REVENANT_HOST_BUILD`, the
convention the host harnesses define, so `Intents/IN10_0_1.m` compiles against the Catalyst headers, and
`tests/backports/host/intents-ride-driver/run.sh` links the port's objects under renamed `RevenantHost` classes and
diffs their answers against the host's. The two initialisers are implemented in `IN10_0_1.m` and their rows are
`implemented`. The plant (a port that answers `""` for a nil `displayName`) differs from the host, so the diff can fail.

**What else the runtime carries, and what the headers say of it.** `tests/backports/host/intents-remaining`
asks the runtime by name, so a member a header omits is still asked for. Its golden is `expected.txt`, and
the macOS and Catalyst runtimes agree on every line:

* `+[INIntentResolutionResult unsupportedWithReason:]` and
  `+[INIntentResolutionResult confirmationRequiredWithItemToConfirm:forReason:]` answer YES on both. Neither is
  declared by the 16.4 or 26.2 headers; the macOS SDK declares both in `INIntentResolutionResult+Custom.h` from iOS
  13.0. Their behaviour is measured and built: see "The resolution results the two factories make" below.
* **`+[INImage systemImageNamed:]`** answers the names `+[UIImage systemImageNamed:]` answers, and nil for the
  rest. The answer is UIKit's: the port calls `+[UIImage systemImageNamed:]`, which draws a template image for the
  549 names of the UIKit band's one table (the 251 the corpus names and 298 common ones,
  `UIKit/UIImage+Symbols.m`, `facts/UIKit/UIImageSymbols.md`) and answers nil for every other name. The INImage
  carries the drawn image as PNG, as `imageNamed:` does, with its name and size.
  The host differs, and the difference is kept as measured: the system's own `+[INImage systemImageNamed:]`
  answers an image for **any** non-empty name, including names no symbol has (`revenant.no-such-symbol` and
  `zz.not.a.symbol` were both answered on Catalyst, while UIImage answered nil). The port does not answer those,
  because a nil for them is the answer the UIKit table gives, and the ruling was one table for both classes.
  `tests/backports/host/intents-symbol` compares the port's INImage with the host's UIImage name by name, over 551
  names (the 549 and two it does not draw), and prints the count of names UIImage does not draw that the host's
  INImage answers. A planted port that answers nil for every name differs.
* `-[INDateComponentsRange initWithEKRecurrenceRule:]` and `-[INDateComponentsRange EKRecurrenceRule]` answer
  YES on both. They take and give an EventKit `EKRecurrenceRule`; their answers are in the EventKit section below.
* `INIntentSetImageKeyPath` and `_INIntentSetImageKeyPath` answer NO on both: no protocol of either name is
  loaded. They have no row; see the bullet above for the Swift-only declaration.

## EventKit's recurrence rule: the host's answers, and the port that matches them

`-[INDateComponentsRange initWithEKRecurrenceRule:]` and `-[INDateComponentsRange EKRecurrenceRule]` are declared
from iOS 11.0 in `INDateComponentsRange.h`, which forward declares `EKRecurrenceRule`. The port links EventKit into
`IntentsBackports` (`modules/apple/backports.lua`), and implements the two as a category of the class in
`Intents/RevenantIntents100.m`. The host's answers are measured by `tests/backports/host/intents-ek`: a golden of 241
lines (`expected.txt`), which macOS and Catalyst both give, and which the port matches line for line on Catalyst. The
host is the oracle, by ruling: where it raises, the port raises; where it loses a field, the port loses it too.

The measured rules:

* **The init keeps an `INRecurrenceRule`**, with `frequency`, `interval` and `weeklyRecurrenceDays`, and no
  recurrence end. The frequency is mapped: EventKit daily, weekly, monthly and yearly become the Intents daily (3),
  weekly (4), monthly (5) and yearly (6). The interval is kept. `weeklyRecurrenceDays` is 0 for every rule given.
* **The start is the first day only**, for any frequency, when the rule names days: `startDateComponents` gets that
  day's weekday, and its week number as `weekdayOrdinal` (0 for none, `-1` for last, `2` for the second). The other
  days are dropped. A rule that names no day has a nil start.
* **The end is dropped**: `endDateComponents` is nil, and the getter's `recurrenceEnd` is nil for every rule.
* **A nil rule** gives a daily range of interval 0, with no start.
* **The getter** answers nil for a range with no rule, and for a minute or hourly rule (EventKit names neither). For
  the others it builds a rule of the same frequency and interval with one day, the start's weekday and week number.
  A range with no weekday asks EventKit for day 0, and EventKit refuses it with `NSInvalidArgumentException`, "Invalid
  day number". The host raises the same, and the port raises it through EventKit itself. So every daily, monthly and
  yearly range raises, a weekly range with no days raises, and a nil rule raises.
* **The getter never answers the object it was given** (NO in every case): it answers a new rule.
* A range made by its plain `init` answers nil.

Measured cases, one line each in the golden: daily every two, daily five times, weekly with no days, weekly on Monday,
on Friday, on Monday and Friday (five times), in the order Friday then Monday (Friday kept), with a week number of 2
(kept), with a week number of -1 (kept), weekly with no days and five times (raises), monthly and yearly (raise), daily
and monthly with a Monday (Monday kept), the Intents rules made by the initialiser with a start weekday (daily,
weekly interval 2, monthly), minute and hourly (nil), and the nil rule (raises). The range's own fields are measured
the same way, so the golden also holds the frequencies, intervals, and which date components are set.

## The resolution results the two factories make, and the readers the host's result answers

`+[INIntentResolutionResult unsupportedWithReason:]` and `+[INIntentResolutionResult confirmationRequiredWithItemToConfirm:forReason:]`
are declared from iOS 13.0 in the macOS SDK's `INIntentResolutionResult+Custom.h`. The port implements both in
`Intents/RevenantIntents100.m`, through the one builder every resolution result uses. The host's answers are measured by
`tests/backports/host/intents-resolution-reason`: a golden of 72 lines (`expected.txt`), which macOS and Catalyst both
give, and which the port matches line for line on Catalyst. A planted port whose `+unsupportedWithReason:` drops the
reason is red.

The host's result class answers, by name, five readers that no header declares: `resolutionResultCode`,
`itemToConfirm`, `unsupportedReason`, `confirmationReason` and `disambiguationItems`. The port answers the same five. The codes the host gives are: success 0, unsupported 1, disambiguation 2, confirmation required
3, needs value 4, not required 5. Measured:

* **`+unsupportedWithReason:N`** (N = 0, 1, 2) answers code 1 and `unsupportedReason` N, and nothing else.
* **`+confirmationRequiredWithItemToConfirm:X forReason:N`** answers code 3, `itemToConfirm` X and `confirmationReason`
  N. With nil and 0 it answers code 3 with nothing else.
* **`+needsValue`, `+notRequired`, `+unsupported`** answer codes 4, 5 and 1, with every other reader zero or nil.
* **`+[INIntegerResolutionResult successWithResolvedValue:7]`** answers code 0. **`+confirmationRequiredWithValueToConfirm:3`**
  answers code 3 and `itemToConfirm` 3, the value given.
* **`+[INSpeakableStringResolutionResult disambiguationWithStringsToDisambiguate:]`**: two strings give code 2 and
  `disambiguationItems` the two; one string gives code 3, `itemToConfirm` that string, and `disambiguationItems` nil.
  The host turns a one-item disambiguation into a confirmation of that item, and the port's reader does the same.

**A bug the measurement found, fixed in the same commit.** `+revenant_adopted:`, which every generated resolution factory
builds through, passed the class object as the receiver of the superclass's `-init`. The helper answers its receiver, so
the result's ivars were written into the class object itself, and `+[INIntentResolutionResult needsValue]` crashed
(`objc_release` on a bad address). The receiver is now an instance, `[self alloc]`. The probe covers `+needsValue`,
`+notRequired`, `+unsupported` and the subclass factories above, and after the fix each answers as the host does. The
rows for those factories were marked `implemented` before this, and they did not run on the host until this measurement.

**A gap, not fixed here.** The host answers nil for `+[INSpeakableStringResolutionResult disambiguationWithStringsToDisambiguate:@[]]`.
The port's generated factory (`Intents/IN10_0_1.m`, a row already `implemented`) answers an object with code 2 and no items.
The probe leaves the empty array out, so the golden does not claim it. Closing it means changing the generated factory,
which is not this commit's file.

## The three `+[X new]` of the 12.0 group, the same marker one call up

`INShortcut`, `INVoiceShortcut` and `INVoiceShortcutCenter` each mark **both** initialisers
unavailable, so the same argument that moved the 110 `-init` rows moves these three `+new` rows, and
they were `absent` for the same wrong reason before. What was measured, and how:

    sh tools/intents/probe-host-absent.sh packages/a/apple-backports/registry/Intents/ios12.json

    ios12.json  +[INShortcut new]            found=yes answers=yes declared-by=NSObject
    ios12.json  +[INVoiceShortcut new]       found=yes answers=yes declared-by=NSObject
    ios12.json  +[INVoiceShortcutCenter new] found=yes answers=yes declared-by=NSObject
    # absent rows: 3, control rows: 97 implemented rows of the same files
    # rows=100 parsed=100 unparsed=0 found=100 answered=55 inherited-from-NSObject=9

`answers=yes` is the release's own answer and `declared-by=NSObject` is whose body it is: the
metaclass chain declares `new` at `NSObject` and nowhere else. The 97 control rows of the same file
were probed in the same process and 100 of 100 names were found, so a zero elsewhere would have been
the release's and not this reader's.

That `answers=yes` and a returned object are two claims, so the second was measured separately, by a
probe that asks the selector's declaring class and then calls it. It is not in the tree and this is
its whole output (arm64-apple-macos14.0 against `/System/Library/Frameworks/Intents.framework`):

    INShortcut             declares=NSObject  returns=object  respondsToSelector:new=1
    INVoiceShortcut        declares=NSObject  returns=object  respondsToSelector:new=1
    INVoiceShortcutCenter  declares=NSObject  returns=object  respondsToSelector:new=1
    INObject               declares=NSObject  returns=object  respondsToSelector:new=1   <- control

So the port answers each `+new` with NSObject's own `+new`, reached through its IMP for the same
reason the `-init` above is: the header forbids naming the selector. `INObject` is in that table as
the control, and it is the one class of the four whose header marks nothing.

That table says `returns=object` and not WHICH object, so the twelve members of this group that
`EXTRA_METHODS` writes by hand - three `+new`, three singleton accessors, three void setters and
three handler members - were asked again, member by member, and this is the whole output of that
run. `sh tests/backports/host/intents/run-rows.sh`, host `macOS 27.0 build 26A428, arm64`, one
process per section:

    intents12 classes INShortcut=1 INVoiceShortcut=1 INVoiceShortcutCenter=1 INRelevantShortcutStore=1 INUpcomingMediaManager=1 INObject=1 INRevenantNoSuchClassForThisHarness=0
    intents12 +[INRevenantNoSuchClassForThisHarness sharedCenter]          ABSENT class=INRevenantNoSuchClassForThisHarness
    intents12 +[NSObject new]                                            IMP non-NULL returned NSObject
    intents12 +[INShortcut new]                                          IMP non-NULL returned INShortcut
    intents12 +[INVoiceShortcut new]                                     IMP non-NULL returned INVoiceShortcut
    intents12 +[INVoiceShortcutCenter new]                               IMP non-NULL returned INVoiceShortcutCenter
    intents12 +[INRelevantShortcutStore defaultStore]                    IMP non-NULL returned INRelevantShortcutStore identical=1
    intents12 +[INUpcomingMediaManager sharedManager]                    IMP non-NULL returned INUpcomingMediaManager identical=1
    intents12 +[INVoiceShortcutCenter sharedCenter]                      IMP non-NULL returned INVoiceShortcutCenter identical=1
    intents12 -[INVoiceShortcutCenter setShortcutSuggestions:]           receiver=INVoiceShortcutCenter IMP non-NULL returned void
    intents12 -[INUpcomingMediaManager setSuggestedMediaIntents:]        receiver=INUpcomingMediaManager IMP non-NULL returned void
    intents12 -[INUpcomingMediaManager setPredictionMode:forType:]       receiver=INUpcomingMediaManager IMP non-NULL returned void mode=0 type=0
    intents12 -[INRelevantShortcutStore setRelevantShortcuts:completionHandler:] on the singleton handler before-return=0 within-5s=1 on-main-thread=0 no-run-loop=1 error=nil
    intents12 -[INRelevantShortcutStore setRelevantShortcuts:completionHandler:] on a fresh instance handler before-return=0 within-5s=0 on-main-thread=-1 no-run-loop=0 
    intents12 -[INVoiceShortcutCenter getAllVoiceShortcutsWithCompletion:] on the singleton handler before-return=0 within-5s=1 on-main-thread=0 no-run-loop=1 count=0 array-nil=0 error=nil
    intents12 -[INVoiceShortcutCenter getAllVoiceShortcutsWithCompletion:] on a fresh instance handler before-return=0 within-5s=1 on-main-thread=0 no-run-loop=1 count=0 array-nil=0 error=nil
    intents12 -[INVoiceShortcutCenter getVoiceShortcutWithIdentifier:completion:] on the singleton handler before-return=0 within-5s=1 on-main-thread=0 no-run-loop=1 shortcut=nil error=nil
    intents12 -[INVoiceShortcutCenter getVoiceShortcutWithIdentifier:completion:] on a fresh instance handler before-return=0 within-5s=1 on-main-thread=0 no-run-loop=1 shortcut=nil error=nil
    intents12 port INRelevantShortcutStore -setRelevantShortcuts:completionHandler: dispatches its handler
    intents12 port INVoiceShortcutCenter -getAllVoiceShortcutsWithCompletion: dispatches its handler
    intents12 port INVoiceShortcutCenter -getVoiceShortcutWithIdentifier:completion: dispatches its handler
    port bodies: 3 of 3 dispatch, 0 failed

Four things it settles, and one it changes:

- **The three `+new` return an instance of their own class**, not of `NSObject` — which is what the
  table above left as `returns=object`. The emitted body reaches `NSObject`'s `+new` and that is
  correct, because `+new` is where the class's own `-init` is entered from.
- **The three singleton accessors are singletons on the system's own framework too**: two calls in
  one process return the same object (`identical=1`), so `dispatch_once` is not this port's
  invention but the shape the release itself has. That was previously read off the header's
  `@note` alone.
- **The three handler members' VALUES are the port's own, measured on the host**: an empty array
  that is not nil with a nil error, a nil shortcut with a nil error, and a nil error for a
  relevant-shortcut set the singleton took.
- **Their TIMING was not, and now is.** Every one of them is `before-return=0` **and**
  `on-main-thread=0` **and** `no-run-loop=1`: the framework calls the handler after the method
  returns, on a thread that is not the caller's, and it fires with no run loop turning anywhere in
  the process — so it is not the main queue and needs no run loop of the caller's. The port now
  answers the same way, from `dispatch_async` on the default global queue, and each of the three
  bodies says so and gives the measurement. **Which queue the framework uses is not measurable from
  outside it and no claim is made that it is this one**; what is claimed, and measured, is that the
  port's is likewise not the caller's thread and likewise needs no run loop. The harness now
  **fails** on `before-return=1`, so a synchronous answer cannot come back unnoticed, and its own
  negative control for that check is the `sync-plant` section, which calls a handler inline through
  the same path and must exit non-zero.
- **One host behaviour still has no port counterpart**: `-setRelevantShortcuts:completionHandler:` on
  a receiver that is **not** the singleton never calls its handler at all inside the window
  (`within-5s=0`, and `on-main-thread=-1` because it never ran). That is recorded and not imitated,
  because a handler that never runs is a hang and the port answers every receiver.

**What this is about the host, and what it is about the port.** The rows above are measurements of
the system's own framework, taken by a host binary. The port's bodies are armv7 and do not run on
this host, and they cannot be linked beside the framework either — that is measured, and the earlier
version of this page had it wrong:

> "Comparing the two needs `tests/backports/host/prefix_selectors.py`, which renames the port's
> classes so its implementations are reached under names of their own"

`prefix_selectors.py` renames **selectors** and not class names (its own comment: "gives one to the
selectors the port's Revenant categories carry"; `IN12_0.m` carries none, so for this file it renames
nothing at all — measured, 0 occurrences of the prefix in its output). The class renaming is `-D`,
and a `-D` moves the SDK's own declaration of a class along with the port's, because it applies to
every occurrence in the translation unit. So the host build of `IN12_0.m` answers

    RevenantIntents262.h:39: error: duplicate interface definition for class
        'RevenantHostINMessageLinkMetadata'
    MacOSX.sdk/…/Intents.framework/Headers/INMessageLinkMetadata.h:14:12: note: previous definition is here

— the port's own header renamed onto the SDK's own header, which is the same name twice. Every one
of this group's five classes is declared by the macOS SDK, so there is no name here a `-D` can move
without moving the SDK's with it. **Nothing in the tree renames a port class without the SDK's**, so
the port's runtime behaviour for this group cannot be measured beside the framework's, and that is
owed and stays owed.

What *is* checked on the port's side is the one thing that can be, and it is checked in the same
run: `run-rows.sh` reads the three generated bodies out of `IN12_0.m` and fails unless each hands
its handler to a `dispatch_async` with no call before it. The expectation comes from the measurement
above and not from the body; the mechanism reads the port's own generated source, so this is a check
of the port's *shape*, not a measurement of its behaviour, and it is labelled that way in the script.
It was mutated both ways to confirm it is live: a body with its dispatch removed, and a body that
keeps its dispatch but also calls the handler inline first — one FAIL and one exit non-zero each.

Two limits, both measured rather than assumed:

- **One process per receiver, and that is not tidiness.** A version that asked both receivers of one
  member in a single process printed `before-return=1` for
  `-getAllVoiceShortcutsWithCompletion:` on a fresh instance in one run and `before-return=0` in
  the next: the first call's work was still in flight when the second was made. The receiver is an
  argument to `intents12-rows.m` for that reason, and three runs per cell agree.
- **Nothing here runs the port's objects.** The port's classes and the framework's share a name, so
  a lookup in one process returns the framework's object. This measures what the system's own
  Intents does with these twelve, which is the oracle the rows are checked against; the port's own
  side still needs `tests/backports/host/prefix_selectors.py`, named as owed above.

## What the host was measured to answer, on all 110 of them

The twenty-one above were measured by `tests/backports/host/intents/init-rows.m`, which prints its
table and compares it against nothing: the other ninety were "the same rule applied to the same
header, which is a claim and not a measurement", and the `source` of their 73 registry rows said so
in as many words — that the per-class harness "is OWED, and is not in the tree". That claim was
false of the tree and is now discharged: `sh tests/backports/host/intents-init/run.sh` passes with
112 golden lines and 0 differing, and the plant is red.

`tests/backports/host/intents-init/` is the harness that measures all of them, and it is built to be
checked rather than read. Three runs, each worthless if the one before it did not pass:

    $ sh tests/backports/host/intents-init/run.sh
    host   macOS 27.0 build 26A428, arm64
    guard  112 implemented -init rows in registry/Intents, 112 in init-classes.inc, 112 in expected.txt

    provenance: the control, and what a zero looks like when it is real
    control, 4 classes a blind reader would miss or invent:
      NSObject / NSString / INCar / INListCarsIntent          found

    the forwarding trampoline, and three selectors beside it:
      +[INSendMessageAttachment noSuchSelector:]             _objc_msgForward    libobjcMsgSend.dylib
      +[INSendMessageAttachment attachmentWithAudioMessageFile:]
                                        +[INSendMessageAttachment attachmentWithAudioMessageFile:]
                                        Intents
      -[INCar setMaximumPower:forChargingConnectorType:]     -[INCar setMaximumPower:...]  Intents
      -[INListCarsIntent init]                               -[INListCarsIntent init]      Intents
    provenance: ->  PASS every control found, so an absent class is the host's own
    intents-init: 112 golden lines, 0 differ -> PASS
    # intents-init: 112 classes, 109 answered, 0 absent, 0 no IMP, 1 raised, 2 nil;
    #                -init own 64, inherited 48; 332 property reads, 5 classes with a non-nil property
    # intents-init: PLANT=one-wrong on INMediaSearch
    intents-init: PLANT=one-wrong forced one line to disagree
    intents-init: 112 golden lines, 1 differ -> FAIL
    intents-init: the plant is red, as it must be
    intents-init: ->  PASS on macOS 27.0 arm64

The reader is `class_getInstanceMethod(Cls, @selector(init))` and then `[[Cls alloc] init]` through
that IMP, for the same reason the emitted body is: the header forbids naming the selector at compile
time, so a call could not be the measurement. `provenance.m` runs first and fails if NSObject,
NSString, INCar or INListCarsIntent is not found, and prints the forwarding trampoline beside three
real IMPs — INCar is in that list because its header says `API_UNAVAILABLE(macos, tvos)` and a
reader that trusted the macro would have skipped it. `PLANT=one-wrong` is the negative control: the
same binary with one line forced to disagree, which must go red, and the script stops if it does not.

`expected.txt` is the golden file, one line per class: name, `own` or `inherit`, what the call
answered, the property reads and how many of those read non-nil, and which. **A row's `source`
quotes its own class's line**, so the claim is checkable at the row rather than asserted for a
population — `-[INObjectCollection init]`'s carries
`INObjectCollection\tinheritobject\t3\t1\tallItems` and `-[INPerson init]`'s carries
`INPerson\tinheritobject\t8\t1\tdisplayName`.

What that population is, and it is not what the twenty-one showed:

- **`-init` is declared by the class for 64 of the 112, and inherited from NSObject for 48.** The 64
  are the rows whose `implemented` status rests on a body that is *not* the answer the host gives,
  because the port's generated body always forwards to the superclass's IMP. That difference was
  invisible in the header and invisible in the registry, and it is the reason a row now names its own
  golden line instead of a shape.
- **109 classes answer an object, 2 answer nil, 1 raises.** `INRelevanceProvider` **raises**, with the
  framework's own reason — *"INRelevanceProvider cannot be initialized directly with -init, initialize
  a subclass instead"* — which is `NS_UNAVAILABLE` in the header and a refusal in the body, in the
  same breath. The port answers with an object instead; that is the row's `effect` and a deliberate
  difference. `INCancelRideIntentResponse` and `INSendRideFeedbackIntentResponse` answer **nil**, with
  the system's own *"Unable to initialize '<name>'. Please make sure that your intent definition file
  is valid."* Both are intent *responses* whose class the framework wants an `.intent` definition for.
- **Five classes answer an object with a property that is not nil**, against a row that says every
  property is nil: `INListRideOptionsIntentResponse.rideOptions`, `INObjectCollection.allItems`,
  `INPerson.displayName`, `INSearchForMessagesIntentResponse.messages`,
  `INSendMessageIntentResponse.sentMessages`. Each is the one property its class computes rather than
  stores; `INPerson.displayName` and `INSearchForMessagesIntentResponse.messages` come from a
  superclass that keeps state the header declares read-only, and the other three are derived. Five of
  the 110 synthesize no property at all and are measured on the IMP and the call alone:
  `INIntentDonationMetadata`, `INRelevanceProvider`, `INRelevantShortcutStore`, `INUserContext` and
  `INVoiceShortcutCenter`.
- **332 property reads over 107 classes**, which is the harness's own count of what it read off a
  fresh object, and it fails if it and the `@synthesize` lines in the port's own objects disagree — so
  a row added to the registry cannot pass unmeasured. A row added to neither is invisible.

`init-classes.inc` is every `implemented` `-[<class> init]` row the registry carries, with the
properties the port's own objects synthesize for each, and `tools/intents/gen-init-classes.lua` writes
it — the tool its own header named and the tree did not have. The run prints **three** counts before
it compares anything, and the third is the one that matters:

    guard  111 implemented -init rows in registry/Intents, 111 in init-classes.inc, 111 in expected.txt

The first is the registry's own count and the other two are the harness's, and comparing those two
with each other only shows that two files written from the same place agree. `INListCarsIntent` is
what that hid: its body moved into the generator's `EXTRA_METHODS`, its row was added, and neither
file was regenerated, so **110 of the 111 rows were being measured** and the guard was 110 against
110. It is the eleventh class now, with an empty property set and a golden line of
`INListCarsIntent	ownobject	0	0` — the class declares its own `-init`, as
`INListCarsIntent.h:17`'s `NS_DESIGNATED_INITIALIZER` says it does.

`INGetRideStatusIntent` was the twelfth, and it is a false row rather than a missing measurement:
its `-init` row read `absent` with the reason *"the header marks the initialiser unavailable, so a
port cannot call it"*, and `INGetRideStatusIntent.h:17` reads
`- (instancetype)init NS_DESIGNATED_INITIALIZER;` — declared, not marked. The generator has no case
for a class whose own header declares a bare `-init`, so the member fell through to the group's
reason and the reason was false. The body is now in the generator's `EXTRA_METHODS` beside
`INListCarsIntent`'s, which is the same body for the same reason: the class declares no property, its
superclass `INIntent` declares no `-init` of its own, and the chain ends at `NSObject`'s, which
nothing marks unavailable, so `[super init]` is the whole of it and the selector can be spelled here.
Measured on the host through this same harness: `INGetRideStatusIntent	ownobject	0	0`.

**The class of that defect is still open, and it is one row wide today.** It was found by reading
every `absent` bare-`-init` row in the five registry files against the SDK header of the class it
names: six rows, one false. A general rule in `gen-intents.py` — a class whose OWN header declares
`-init` and does not mark it unavailable gets a body — would make the false reason unreachable
rather than absent, and would make both `EXTRA_METHODS` entries unnecessary. It is not landed here
because changing what the generator emits means re-running `tools/intents/generate.sh`, which
rewrites all six registry files and every `IN*.m`: the one operation the tree's trap forbids doing
by hand, and one that wants the full gate beside it. That is a change of the generator's shape,
not of a row, and it is written down here so it is not rediscovered as a new bug.

The one thing the twenty-one measured that this one does not is the **zero case of an enumeration
property**: `INMediaDestination`'s `mediaDestinationType` reads `NSNumber 0` rather than nil, and the
eleven such properties read their enumeration's zero case. The golden file records how many reads
were non-nil and which, not what an enumeration read, so the 21 rows of `registry/Intents/ios16.json`
that quote the zero case keep citing `init-rows.m` for it. Two harnesses, one fact each — that is the
debt, and it is written down here rather than settled by deleting whichever row is inconvenient.

## The six hand-written bodies of this framework, and the census behind them

Six rows of `registry/Intents/ios16.json` are `implemented` with a body written by hand in
`tools/intents/gen-intents.py`'s `EXTRA_METHODS` rather than derived from the header: the two
`INMediaDestination` factories, the two `INFile` factories,
`+[INAddTasksTargetTaskListResolutionResult confirmationRequiredWithTaskListToConfirm:forReason:]`
and `-[INUserContext becomeCurrent]`. A body written by hand is a decision, so each of their rows
says where the decision came from instead of naming only the header — and what it names is the same
two things for all six.

**Neither band end carries any Intents class at all**, which is why the port has to supply these
classes itself and why a caller that reaches one of these methods gets the class and not a release's
own answer:

    $ REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua IN 6.1.3 4.3 11.0 12.0

    6.1.3   images 524,  classes 11378,  classes IN* 0,  protocols IN* 0
    4.3     images 354,  classes 7187,   classes IN* 0,  protocols IN* 0
    11.0    images 1258, classes 52768,  classes IN* 239, protocols IN* 171
    12.0    images 1368, classes 63192,  classes IN* 411, protocols IN* 218
    control: 1039 name(s) beginning IN found in this run, so a zero on another rung is the
              release's and not the reader's

The framework arrived with iOS 10 and the `armv7` ladder ends at 10.3.4, so no release this package
is gated for has ever carried it. On a release that does carry it the band's own objects are dropped
and the framework's class answers, which is what the rows' `effect` says.

**And the host answers all six anyway**, which is the measurement each row's `source` quotes. All
four classes are `API_UNAVAILABLE(macos)` in the SDK, so
`tests/backports/host/intents/factory-rows.m` reaches every method by selector through
`objc_msgSend` and reads every value through KVC, and `tests/backports/host/intents/run-rows.sh` runs
it with its controls. Two findings from that harness are worth keeping, because both are ways of
measuring nothing:

- a program that read the four classes with `NSClassFromString` **without linking
  `-framework Intents`** answers `ABSENT` for all four, and is wrong about every one;
- a program that called them through a raw cast of `class_getMethodImplementation` to a C function pointer dies with
  `EXC_ARM_DA_ALIGN` at the entry point — the crash report's symbol is
  `_OBJC_$_CLASS_METHODS_INFile(Readable|INEnumerable|INJSONSerialization)`, so this host's Intents
  compiles its Objective-C entry points as SVE and pointer-authenticated thunks that a C function
  pointer reaches on the wrong convention.

| row | what the host answers |
|---|---|
| `+[INMediaDestination libraryDestination]` | `mediaDestinationType` 1, `playlistName` nil, a second call `isEqual` the first |
| `+[INMediaDestination playlistDestinationWithName:]` | `mediaDestinationType` 2 and the name given; nil for a nil name, which is the header's own nullable |
| `+[INFile fileWithData:filename:typeIdentifier:]` | the bytes given, `filename` and `typeIdentifier` as given, `fileURL` nil, `removedOnCompletion` false, a nil `filename` stays nil, and `data` hands back a copy and not the same `NSData` |
| `+[INFile fileWithFileURL:filename:typeIdentifier:]` | `fileURL` the URL given, `filename` the URL's last path component when the name is nil, `typeIdentifier` as given, and `data` the file's own bytes: `/etc/hosts` came back as its 213 bytes and a path that does not exist as 0 |
| `+[INAddTasksTargetTaskListResolutionResult confirmationRequiredWithTaskListToConfirm:forReason:]` | what the superclass's one-argument factory answers — `resolutionResultCode = NeedsConfirmation`, the task list as the item to confirm, nothing else — and the reason in no property either class declares, `unsupportedReason` staying 0 |
| `-[INUserContext becomeCurrent]` | returns with no exception; the class declares **no** property and no `-init` of its own, and its seven own methods are `initWithCoder:`, `.cxx_destruct`, `becomeCurrent`, `encodeWithCoder:`, `_init`, `_becomeCurrentNoHelper` and `_setStore:` — it hands the context to a store, and the store is the assistant's user-context store |

The last one gets a body that does nothing observable, and that is the decision rather than a gap:
the class declares no reader, so a body that remembered the object would answer that the context is
current and nothing the SDK declares could ever see that it is. `INImage`'s `+systemImageNamed:` does not
answer that way: it answers the names UIKit draws (see "+[INImage systemImageNamed:]" above).

## What is NOT proven here, and is owed

- **The ninety are measured now; the twenty-one's enumeration zero case is measured twice.** 74 rows'
  `source` names `intents-init` and quotes their own golden line. The 21 rows of `ios16.json` that
  quote `init-rows.m` for the zero case of an enumeration property keep citing it, because
  `intents-init`'s golden line records how many property reads were non-nil and which, and not what
  an enumeration read — see the section above for why that is left as it is. The 16 rows of
  `ios11.json` cite the same older harness and are set out in `Init11.md`.
- **`run.sh --write` used to drop two lines of the golden file's own header.** It cut the comment at
  the host line, so the two comment lines a reader had put below that line were removed by a write
  and the file and its writer could not both be right. Measured on 2026-10-03: a `--write` on an
  unchanged host rewrote all 110 data lines identically and removed those two. The writer now
  carries the header above the host line verbatim, writes the host line and the prose below it
  itself, and a second `--write` is a no-op — checked by running it twice and diffing.
- **The port's own `-init` has not been run against the system's.** The harness above reads the
  system's class; the port's side is proven by the compile, the presence of each `-init` per `nm`,
  and the registry's own text. **Comparing the two is owed and is not blocked on anything but a
  rename that does not exist yet.** An earlier version of this bullet said it "needs
  `tests/backports/host/prefix_selectors.py`, which renames the port's classes"; it does not — it
  renames selectors, and the class renaming is `-D`, which moves the SDK's own declaration of a class
  along with the port's. `RevenantIntents262.h` re-declares the classes the port's own SDK lacks and
  the host's has, so a `-D` renames the port's copy and the SDK's copy onto one name and the build
  answers *duplicate interface definition* — measured, with the exact text, in the 12.0 section
  above. Every class of this framework is declared by the macOS SDK, so what the comparison needs is
  a **source-level** rename of the port's own class names that leaves the SDK's alone. Teaching
  `prefix_selectors.py` that is owed; nothing else is. Until then the port's behaviour is compared
  by shape only, and `run-rows.sh` says which kind of check each of its steps is.
- **Nothing here runs on a device or under `xmake emulate`.** Every answer above is the macOS host's
  own Intents, and the port's objects are armv7 iOS 6.1.3. That the `-init` survives into a linked
  6.1.3 binary is the link step's job.
- **`gates: coordinator`.** Not run by the author.

## A subclass that keeps its superclass's read-only value in its own ivar

The seventeen `intents-1a` rows — eight reservation classes' `-initWithItemReference:…` in both
spellings, `INRestaurantGuest`'s `-initWithNameComponents:…` and `INRideDriver`'s two — and the
reason they were `absent` at all: `INReservation` and `INPerson` declare their values read-only and
offer no designated initialiser, so there was nowhere to put them. The class now keeps a copy in its
own ivar and answers the getter itself. **The objects are armv7 iOS 6.1.3 and nothing in that slice
runs them**, so what is proven is the compile, the presence of the seventeen per `nm`, and the
registry's own text; the runtime behaviour — the getter's answer, a superclass-typed pointer, an
`NSSecureCoding` round trip — is owed to `intents-1c` and its renamed host harness. What is owed and
what is proven are set out in full in `facts/Intents/InheritedReadonly.md`.
