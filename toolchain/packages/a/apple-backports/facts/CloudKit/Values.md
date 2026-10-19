

### The rest of the sync engine surface

`CKSyncEngine17.m` over the same header. The engine, its configuration, the twelve events, the three
pending changes, the batch, the two classes of what the service refused and the two of what it
reports gone. **The whole header is 32 classes and 78 properties, and none of them is an R4 case** —
they are all in the 26.2 surface the corpus measures.

- **The engine's four requests are the operations this package already carries** — a fetch of the
  database is `CKFetchDatabaseChangesOperation`, a fetch of a zone is
  `CKFetchRecordZoneChangesOperation`, a send is `CKModifyRecordsOperation` — so what the engine adds
  is the state and the order, not a request of its own.
- **Both of the engine's initialisers refuse on the host, and it is a trap rather than an exception.**
  `+[CKSyncEngine new]` and `-[CKSyncEngine init]` on the host raise
  `Fatal error: Use of unimplemented initializer 'init()' for class 'CloudKit.__CKSyncEngine'`, because
  the class behind the public one is private and its `-init` is not implemented. A trap takes the
  process down. This port's engine is an `NSObject` that does not trap - it builds, with no state - so
  the refusal a caller meets is the one this package's own header makes: both spellings are
  `NS_UNAVAILABLE` in `RevenantCKSyncEngine26.h`, as they are in Apple's own header, and the engine is
  built through `-initWithConfiguration:`. The measured difference, and what a caller sees only if it
  sends the selector dynamically, is in *The operation initializers* below.
- **A refusal from the service is handed over with the thing it was about.** A failed record save
  carries the record, a failed zone save the zone, and the failed deletes are dictionaries keyed by
  what was refused. A caller has to decide what to do about a record it did not save, and it cannot
  find that record again by itself.
- **A fetched deletion carries what an identifier does not.** A record deletion carries the record
  type as well as the identifier, and a zone deletion carries which of the three reasons it gives —
  deleted, purged, or the user reset their encrypted data. Those are different problems for a caller
  and the port does not fold them together.
- **A batch asks the delegate's provider for a record through the port's own selector**
  (`-revenant_recordForRecordID:`), because the 26.2 headers type the provider as `id` and declare no
  selector for it. A record the delegate has not read is not sent: a port that sent a record it had
  invented would be overwriting one it never saw.

## The record value half, and the one place it does not match the host

`CKRecordZoneID`, `CKRecordID`, `CKServerChangeToken`, `CKReference`, `CKAsset`, `CKRecordZone` and
`CKRecord` are in `CloudKit/CKRecords8.m`, with the parent and share of iOS 10.0 in
`CloudKit/CKRecords10.m` and the two record decoders in `CloudKit/RevenantCKRecords.m`. They were
missing from the tree while the registry carried all seven as `implemented` - 82 rows, 75 classes - and
the release-split refused before the link ever ran, so nothing had found it.

Every refusal, default and equality is the host's own, read out of the running iOS CloudKit by
`tests/backports/host/cloudkit/records-cases.h` and held to the same questions by
`tests/backports/host/cloudkit/records-port.m`; `compare.py` reads the two records and names every
difference. 137 answers, 136 of them identical.

**The one difference, and why it is not matched.** The host's `CKRecordZoneID` is *interned*: a zone ID
decoded out of an archive is the same object as the one encoded, and `compare.py` records `identical`
where this port records `equal`. The two zone IDs are equal by value here and are not the same object.
Matching it means a process-wide table of every zone ID ever made, held for the life of the process,
and the host's retention rules for that table are not something this port can measure. A port that
interns would hold every zone name a caller ever built; one that does not holds only what the caller
still references. The values agree, which is what the equality contract is, and the identity is left
to the caller.

Two more answers are compared by shape rather than by value, and neither is a difference: a record
given no name of its own is given a UUID on both sides, and an archive's byte length is not compared
because a port ships its own archive keys - what is compared is the round trip, which decodes to an
equal object for all five classes that are archived.

The measurements that are easy to get wrong, all from the host:

    +[CKRecordID new]                 NSInvalidArgumentException: You must call -[CKRecordID initWithRecordName:] or -[CKRecordID initWithRecordName:zoneID:]
    -[CKRecordID initWithRecordName:nil]  CKException: recordName can not be nil
    +[CKServerChangeToken new]         CKException: You can't call init on CKServerChangeToken
    -[CKAsset initWithFileURL:nil]     NSInvalidArgumentException: Null fileURL
    -[CKAsset copy]                    NSInvalidArgumentException: -[CKAsset copyWithZone:]: unrecognized selector
    a parent in another zone           NSInternalInconsistencyException: Parent record must be in the same zone as the current record
    set a field key of ""              NSInvalidArgumentException: recordKey can not be empty

    the field key grammar, over all 95 printable ASCII characters:
      accepted as the whole key  ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz        (53)
      accepted after the first  $0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz (64)

    CKRecord and CKRecordZone do not override isEqual: - two records of one type are different, a
    copy is a different object carrying the same fields, and +[CKRecordZone defaultRecordZone] is one
    shared object. CKRecordID, CKRecordZoneID and CKReference compare by value.

## The two names the sweep lists, and where they came from

`CKFetchWebAuthTokenOperation` and `CKShareRequestAccessOperation` were on the sweep's list of 72
CloudKit API names main lacked, and they are the two the bundle this series was rebuilt from had no
commit for. **Both are carried now**, one file of its own each, because the band machinery puts an
object in the band of the release its API arrived in: `CKOperations92.m` for the one that arrived in
9.2, `CKOperations26.m` for the one that arrived in 26.

What that earlier page said about them was right about the bundle and wrong about the headers, and the
second half is what made them look impossible:

    $ for n in CKFetchWebAuthTokenOperation CKShareRequestAccessOperation; do
        git log --format=%H --all -- packages/a/apple-backports/CloudKit | while read s; do
          git grep -l "@implementation $n" $s -- packages/a/apple-backports/CloudKit && break; done
      done
      no @implementation in any reachable commit   (both names)

    $ ls "$(cat /tmp/land/sdkpath)"/System/Library/Frameworks/CloudKit.framework/Headers/CKFetchWebAuthTokenOperation.h
    ...iPhoneOS16.4.sdk/.../CloudKit.framework/Headers/CKFetchWebAuthTokenOperation.h
    $ ls "$(cat /tmp/land/sdkpath)"/System/Library/Frameworks/CloudKit.framework/Headers/CKShareRequestAccessOperation.h
    No such file or directory

`CKFetchWebAuthTokenOperation` is declared by the headers this package builds against, 9.2 with three
members, so nothing about it had to be transcribed. `CKShareRequestAccessOperation` is not in the 16.4
headers and is transcribed from the 26.2 ones into `RevenantCKIOS26.h` - the same shape as
`RevenantCKSyncEngine26.h`, which is how the other half of the 26 surface is declared - and implemented
in `CKOperations26.m` beside it with an explicit `@synthesize` for each of its three properties.

**What each one asks the service for.** The web auth token operation is the one request in this package
whose answer is not of the port's own making: it is `users/login` with the API token the caller was
handed, the path a client uses rather than signing a token of its own, and a token it was not given is
`CKErrorNotAuthenticated` with no request made - there is no account behind the answer, because there
was no token to exchange. `CKShareRequestAccessOperation` is the other half of accepting a share:
`shares/requestAccess` with the URLs of the shares to ask about, answered per URL, an item the service
refused arriving as that item's own error and the operation's own as `CKErrorPartialFailure` under
`CKPartialErrorsByItemIDKey`. Both are the service's own interface, as `facts/CloudKit/WebServices.md`
sets out; neither is reachable from this device, which has no iCloud account, so neither has been run
against the service and neither claims an answer it was given.

The two siblings of the 26 sharing surface that are still not carried - `CKShareAccessRequester`,
`CKShareBlockedIdentity`, and the members of `CKShare` that say a share may ask at all - are named at
the bottom of `RevenantCKIOS26.h`. They are values the service fills in, and the `CKShare` members cannot
be answered without `CKShare` itself.

## The five names the two halves of the pile defined without a row

`CKFetchDatabaseChangesOperation`, `CKFetchRecordZoneChangesOptions` and `CKFetchRecordZoneChangesOperation`
are defined in `CloudKit/CKOperations1210.m`, `CKFetchRecordZoneChangesConfiguration` in
`CloudKit/CKOperations12.m`, and `CKSyncEnginePendingZoneDelete` in `CloudKit/CKSyncEngine17.m`. Every one
of them had **no row at all**: the two halves of the pile each carried the definitions, and neither carried
the registry entry that says so. An `implemented` row without code is what the gate refuses; a definition
without a row is the same defect seen from the other side, and the gate's own rule names it - "built, but no
entry in `registry/`". Each of the five now has a row whose `source` is the file that defines it.

Two things were wrong with the check that should have caught this, and both are fixed here rather than
worked around:

- The registry mirror (a check since removed) printed its two numbers and **returned nothing**, so it exited 0
  whatever it had found. A check that cannot fail is not evidence: the five names above were reported as
  "both directions 0" on the strength of a mirror that could not have said otherwise. It now exits
  non-zero on either direction.
- The duplicate `(RevenantCKBuilding)` categories in `CloudKit/RevenantCKSubscription.h` were the same fact in
  the source: two categories of one name on one class, where the runtime keeps one and the other's members
  are never registered. `CKUserIdentity` was declared twice - the four properties in one, `-revenant_identity`
  in the other - and `CKShareParticipant` twice, the two properties in one and `-initWithType:` in the
  other. Each pair is one category now, carrying every member it had between them. The pile's own final
  commit carries the same duplication, so this is not a replay artefact.

## A row is keyed by (kind, api), not by the name

Both reports keyed a row on its bare name, so `+[CKRecordID new]` and `CKRecordID` were one key. A
member row then answered the class row's question: delete the class row and leave the member row
`implemented`, and every direction in both scripts read 0 and exited 0. Measured on this tree before
the fix:

    class row CKRecordID deleted, +[CKRecordID new] left implemented
      the registry mirror (deleted)   exit 0   (every direction 0)
      the checklist (deleted)         exit 0   (every direction 0)

Both are keyed by `(kind, api)` now, and a fourth direction reads a member row against its class: a
member cannot exist without its class, so `+[CKRecordID new]` reading `implemented` beside a class row
that is `absent`, or with no class row at all, says the class is here and not here in the same breath. A
`constant` row is a global symbol and stands on its own - the twenty-five constants in this registry
(`CKErrorDomain`, `CKRecordTypeShare` and the rest) are not members of anything, and asking them for a
class row would be the same mistake pointed the other way. After the fix, the same two plants:

    class row deleted          mirror exit 1   checklist exit 1
    class row marked absent    mirror exit 1   checklist exit 1

The checklist counts a sweep name as carried only through a class row of its own, which is why it now
also reads `a definition here with no row: ['CKRecordID']` where it read nothing at all: the member row
had been standing in for the class row that was not there.

## Corrections to the record

**`eed61c206`'s statement that the light guard "reports 4 failures, all in `registry_test` on
FileProvider entries … which the same guard reports on `main` without any of this work" is withdrawn.**
It is an artefact of how the guard was invoked, not a property of the tree.

`coordination/run_light_tests.lua` takes the checkout it is to read as an argument, and
`review-mechanical.sh` passes its own fresh worktree:

    lg=$(xmake l "$HOME/Git/projects/ios/coordination/run_light_tests.lua" "$wt" 2>&1 | ...)

Run without that argument, from the repository root, the guard resolves a different set of registry
files and reports four `registry_test` complaints that have nothing to do with CloudKit -
`pathRelativeToDocumentStorage`, `identifier` and `displayName` "a property not spelled
`-[Class selector:]`", and `NSFileProviderDomain` "named by both FileProvider/ios11.json and
FileProvider/ios11.json" (the two files are `ios110.json` and `ios160.json` in the tree the guard
reads when it is given a checkout). Both measurements are real; only the second one is the guard the
gate runs:

    xmake l coordination/run_light_tests.lua <checkout>     10 suites OK, 0 FAIL, exit 0
    xmake l coordination/run_light_tests.lua                 4 failures,           exit 1

Measured on `main` at `a66cdcde5` with the checkout argument, which is what the reviewer ran: **10/10,
0 FAIL**. The four FileProvider failures were reproduced on `main` and on this branch alike, which is
what made them look pre-existing rather than like an invocation artefact - they were pre-existing *for
that invocation*, and that invocation is not the gate's.

The claim as written in `eed61c206` is withdrawn rather than amended: the commit stays, and this
section is the correction. Its other measurements are unaffected - the checklist, the mirror, the
`registry_test` exit and the eleven CloudKit compiles were each run directly against the checkout and
are not touched by this.

## One object carries one release, and one minimum

The band machinery puts an object in the band of the release its API arrived in, so an object whose
symbols first appear in two releases belongs to no band at all. The gate refuses it as "an object
carries API that arrived in one release, so split it", and `tools/release-split.lua` measures the same
thing out of the compiled symbols. Measured on the objects of this tree before the split:

    CKOperations10.o  MIXED-RELEASES  10.0.1,8.3
    CKValues10.o      MIXED-RELEASES  10.0.1,8.0,8.3

`CKAcceptSharesOperation` is 8.3 and the four discover and fetch-share operations are 10.0.1, so the
first is `CKOperations83.m` now. `CKShareParticipant` is 8.0 and joins `CKValues8.m`, the first
release's own value file, and `CKUserIdentity` is 8.3 and is `CKValues83.m`. After the split:

    xmake l tools/release-split.lua <objects> <out> <iPhoneOS16.4.sdk>
    release-split: clean, every object file's symbols first-appear in one release (28 files, 185 symbols, 50 releases checked)

The releases are read from the held dyld caches, so 10.0.1 is the first rung that **exports** the
discover and fetch-share symbols and the arrival is bounded from above by it, the way release-split's
own note says for the rungs the ladder skips. The rows said 10.0 where the measurement says 10.0.1,
and the three moved classes said 10.0 where the measurement says 8.3 and 8.0; all thirteen now carry
the release they were measured at, because a row that names another release than the object is the
same defect the split fixes.

The second half of the gate's finding is the registry's `minimum`, which is the release an **object**
is carried from: the minimum of the entries its API answers to, and an object whose entries name
different minimums is refused, "the earliest would carry API below its minimum, the latest would drop
API the registry carries earlier". `CKSyncEngine17.o` had three rows at 6.0 and eighteen naming none,
which is two answers. Every one of the object's thirty rows now names 6.0, the value the three already
gave, and never above 10: armv7's last deployment is 10, and a minimum above it would take the object
out of every band that can link it. A minimum at or below the deployment bounds nothing, which is why
6.0 is the answer that both satisfies the rule and keeps the object in every band.

### introduced is Apple's surface, placement is measured

A row's `introduced` is a transcription of what Apple's own header says a client can expect the API
from, and `check_registry`'s `carried(entry, deployment)` reads it. Where an object goes is measured:
the held dyld caches and the SDK header, and nothing in the placement path reads the row. The two are
different facts and putting one in the other's field is wrong in both directions, so the measured
releases live here and not in the registry.

Read per class out of the 26.2 headers - the annotation that governs each `@interface`, which for the
two discover operations is an `API_DEPRECATED` whose first `ios` is the arrival and whose second is the
deprecation - all thirteen read **`ios(10.0)`**:

    CKAcceptSharesOperation              API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))
    CKDiscoverUserIdentitiesOperation    API_DEPRECATED(..., ios(10.0, 17.0), ...)
    CKDiscoverAllUserIdentitiesOperation API_DEPRECATED(..., ios(10.0, 17.0), ...) + API_UNAVAILABLE(tvos)
    CKFetchShareMetadataOperation        API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))
    CKFetchShareParticipantsOperation    API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))
    CKQuerySubscription                  API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(6.0))
    CKRecordZoneSubscription             API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(6.0))
    CKDatabaseSubscription               API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(6.0))
    CKDatabaseNotification               API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))
    CKUserIdentityLookupInfo             API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))
    CKUserIdentity                       API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))
    CKShareParticipant                   API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))
    CKShareMetadata                      API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))

Apple's annotation and the measurement disagree for three of them, and both readings are kept:

| class | Apple says | first held rung exporting it | placement |
| --- | --- | --- | --- |
| `CKAcceptSharesOperation` | ios(10.0) | 8.3 | `CKOperations83.m` |
| `CKUserIdentity` | ios(10.0) | 8.3 | `CKValues83.m` |
| `CKShareParticipant` | ios(10.0) | 8.0 | `CKValues8.m` |

A rung is the first release the **cache** exports the symbol from, so it bounds the arrival from above
and is not a claim about when Apple shipped the class; `release-split`'s own note reads a skipped rung
the same way. The split follows the measurement, because an object is placed by the symbols it
carries, and the row records the surface, because a client asks the row. The ten classes the gate
grouped as 10.0.1 are `ios(10.0)` by Apple's annotation and 10.0.1 by the ladder, which is the same
bound one rung tighter.

### One object, one minimum, and why the check groups by the file and not by `source`

The gate's 4.3 rule is that an object is carried from one release on, and its minimum is read from the
entries the symbols it carries answer to, so within one object those entries all name the same minimum
or none of them names one. Two CloudKit objects broke it, and a check I wrote to find them first read
them clean, twice, for one reason:

| class | defined in | its row's `source` said | minimum |
| --- | --- | --- | --- |
| `CKSyncEngine` | `CKSyncEngine.m` | `CKSyncEngine.m` | none |
| `CKSyncEngineConfiguration` | `CKSyncEngine.m` | `CKSyncEngine17.m` | 6.0 |
| `CKSyncEngineStateSerialization` | `CKSyncEngineState17.m` | `CKSyncEngineState17.m` | none |
| the six scopes, options and contexts, `CKSyncEngineState` | `CKSyncEngineState17.m` | `CKSyncEngine17.m` | 6.0 |

**Eight rows named a file that does not define them.** The event group in `CKSyncEngineState17.m` was
filed under `CKSyncEngine17.m`, and `CKSyncEngineConfiguration` was filed under `CKSyncEngine17.m`
while `CKSyncEngine.m` defines it. So grouping by the row's `source` put `CKSyncEngine.m` down as one
object with one row, `CKSyncEngineState17.m` down as an object with no rows at all, and read clean -
and the earlier minimums fix landed on the rows filed under `CKSyncEngine17.m`, which happened to
include the seven that really belong to `CKSyncEngineState17.m`, so the numbers came out right while
the field underneath them was wrong. `source` is a transcription; placement is what the file that
defines the class says. All eight now name the file that defines them, and every row of all three
objects carries 6.0.

`tests/addon/registry_test.lua` now carries the rule itself (`one_minimum_per_object`), grouped by the
file that defines a class, with a class two files implement asked of both objects. The rule was
already tested above it, on synthetic objects; what it could not do was run over the repository's own,
which is where a registry that disagrees with itself is found. Run before this fix it reported six
objects, the two here and four that are not ours.

## The operation initializers, measured on the host

`CKOperations8.m` and the four files above it. The base class refuses to be instantiated, and it
refuses in words and with an exception class that are the host's own; every concrete subclass answers.
Both halves were measured against the host's CloudKit with `objc_msgSend`, because `-init` and `+new`
are the two spellings a caller gets wrong and the header's own marking is not what is being asked:

    $ ./ckinit CKOperation new
    CKOperation[+ new]          -> raises NSInternalInconsistencyException: You must use a concrete subclass of CKOperation
    $ ./ckinit CKOperation init
    CKOperation[- init]         -> raises NSInternalInconsistencyException: You must use a concrete subclass of CKOperation
    $ ./ckinit CKDatabaseOperation new
    CKDatabaseOperation[+ new]  -> CKDatabaseOperation
    $ ./ckinit CKModifyRecordsOperation init
    CKModifyRecordsOperation[- init] -> CKModifyRecordsOperation

**Sixteen is the number of concrete subclasses this port carries, and all sixteen answer for both
spellings** - `CKDatabaseOperation`, the eight of `CKOperations8.m`, `CKAcceptSharesOperation` of
8.3, `CKFetchDatabaseChangesOperation` and `CKFetchRecordZoneChangesOperation` of 12.10, and the four
of `CKOperations10.m`. That is why a modify built with `-init` is a modify with nothing in it and
its `-main` declines to send it: the header marks each of those `-init` as the **designated**
initializer, which is a statement that this is the way to make one, and the framework agrees.

**The refusal is about the receiver, and that is what the host's own words say.** *"You must use a
concrete subclass of CKOperation"* is a statement about which class was instantiated, not about which
initializer was reached - a `CKModifyRecordsOperation` **is** a concrete subclass, and measured on the
host it answers. So `-[CKOperation init]` does both halves in one method: for the abstract base itself it
raises with the host's exception and words, and for anything below it it is the ordinary designated
initializer, `NSOperation`'s own `-init` followed by `-revenant_setUp` (the four members every operation
needs). Every subclass therefore writes the `[super init]` the header tells it to write, and there is no
seam to go around. The question "which class is this really" is asked with `object_getClass`, not
`[self class]`, because `-class` is a method a subclass may answer with something else.

The first version of this had it the other way round: the base refused unconditionally and every
subclass built through a `-revenant_init` seam instead of `[super init]`. It compiled, it was green, and it
was wrong twice over - it would have raised on every operation anybody built, and it cost 35
`-Wobjc-designated-initializers` warnings over these files, because a category cannot carry
`objc_designated_initializer` and marking the seam designated in a class extension instead makes clang
demand an override per subclass (both measured). The warning count over the 28 sources main already had
is back at main's own **336**, and the 24 `-Wobjc-designated-initializers` lines left in the family are
the ones `CKQuery8.m`, `CKValues10.m` and `CKValues11.m` already had.

**`+new` is NSObject's here, and that is the host's shape too.** The 26.2 header marks `-init` as the
designated initializer of `CKOperation` and says nothing about `+new`, so `+[CKOperation new]` reaches
this `-init` and refuses with the same words. A `+new` of this class's own would be *inherited by*
`CKDatabaseOperation` - which is concrete on the host - and would refuse a class the host builds.

**Two more refusals were measured in the same probe, and only one of them is this port's to make.**
`+[CKShare new]` and `-[CKShare init]` raise `CKException` with *"You must call -[CKShare
initWithRootRecord:shareID:]"*; this port carries no `CKShare` at all, so there is nothing here that
answers either spelling. `+[CKSyncEngine new]` and `-[CKSyncEngine init]` **trap** -
`Fatal error: Use of unimplemented initializer 'init()' for class 'CloudKit.__CKSyncEngine'`, because
the class behind the public one is private and its `-init` is not implemented - and this port's
`CKSyncEngine` is an `NSObject` that does not trap: it builds, with no state. The difference is only
visible to a caller that sends the selector dynamically; a caller compiling against
`RevenantCKSyncEngine26.h` cannot write `[CKSyncEngine new]` at all, because that header marks both
spellings `NS_UNAVAILABLE` as Apple's own does.

**What is measured here and what is not.** The 36 cases above are the host's own answers, and they are
the oracle for the words and for which classes refuse. The port's own answer is not run here: linking
this family's objects for the host needs `uECC.c` from micro-ecc, and the shared store keeps that
package's headers and its per-digest archives built for armv7, not the C it was fetched as. What is
checked on this side is the compile - 30 sources for `armv7-apple-ios6.0` against iPhoneOS16.4, no
error line - and the gate's own reading of the objects.

## What CloudKit is still owed, by class

Measured over `coordination/corpus/ledger/CloudKit.tsv` (1198 rows) against the 118 rows of
`registry/CloudKit/values.json` in this tree: **1072 ledger rows are not in the registry**, and they are
mostly members rather than classes - 491 properties, 347 methods, 135 constants, 33 enums, 28 structs,
27 typealiases, 7 classes, 4 protocols. The registry's 118 rows are the classes this series carries and
what they answer; the ledger is the whole surface.

**The counting rule, in one line, so the table beside it can be recomputed: the count for a class is
the number of distinct `api` spellings the ledger attributes to it, where a class is attributed its own
rows, a member (`-[CKRecordID recordID]`) and a dotted name (`CKRecord.recordID`,
`CKContainer.Application.PermissionBlock`) are attributed to the class that heads the spelling, and a
bare `CKErrorDomain`-style constant is attributed to itself, because the ledger spells it bare and
attributing it to a class would need a name-prefix guess.** The table is the owed count of the ledger under this rule (the check that printed it is removed). Its output for one class was:

    CKSyncEngine                      169 owed of 169 distinct

| class | owed distinct apis | what it is |
| --- | --- | --- |
| `CKContainer` | 52 | the container's accounts, status and configuration surface |
| `CKShare` | 35 | the share object of iOS 10 and its metadata, acceptance and participants |
| `CKDatabase` | 73 | the database's notifications, subscriptions, zones and change tokens |
| `CKRecord` | 49 | the record's fields, change tracking and the key-value setting protocol |
| `CKSyncEngine` | 169 | the engine's delegate, events, scopes and contexts |
| `CKUserIdentityLookupInfo` | 11 | the lookup info's own members |
| `CKRecordKeyValueSetting` | 8 | the protocol the record's fields answer to |
| `CKSyncEngineState` | 10 | the state object's own members and its serialization |
| `CKRecordZone` | 12 | the zone object's own members |
| `CKSyncEngineDelegate` | 7 | the delegate the engine calls back into |

The nine rows above are the owed distinct spellings each class heads. A reviewer's independent count of
the same ledger put several of these lower (`CKContainer` 46, `CKShare` 80, `CKSyncEngine` 249,
`CKRecordZone` 28) and three of them above what this rule prints; the difference is the owner rule, not
the ledger - a bare constant is counted against itself here and a nested name against its head, and a
rule that attributes a bare `CKErrorDomain` to `CKError` would move every cell by a different amount
again. The rule above is the one the deleted script applied, and any cell of the table is its count of owed distinct
spellings under that rule.

`CKDatabase` is the next family by that rule, and the count is a count of distinct owed spellings, not a
judgement about what it is worth: a member is owed when no row and no definition exist for it here, and
a member whose behaviour is already answered by a class this series carries is not owed work, it is a row
to be written. The table was measured when the two owed *classes* were still owed; both are carried now
- `CKFetchWebAuthTokenOperation` in `CKOperations92.m` and `CKShareRequestAccessOperation` in
`CKOperations26.m` - and *The two names the sweep lists, and where they came from* above has them.

What this table is not: a plan, and not a claim that any of it can be carried. Each family needs its own
host differential before a row may say `implemented`, and where the host cannot be asked the row says so
with the reason. The two operations above are the exception in the other direction: their host
differential is the initializer probe, because what a CloudKit operation answers without an iCloud
account is its refusal to be built wrongly - and neither has been run against the service, which this
device has no account for.

### CKDatabase, and what the host does not answer

The next family is `CKDatabase`, 73 distinct owed spellings under the rule above. Its differential is `tests/backports/host/cloudkit/database-cases.h`
with `database-host.m` and `database-cases.m`: one cases file, two builds, the arrangement the record
half already uses - the cases header declares the surface and no CloudKit header is imported, so the
host build links the framework and takes the classes from the runtime while the port build links
nothing and takes them from this package. The cases ask, for the no-account case, the three things a
caller switches on - whether the completion block ran, the error's domain by name and by value, and
the code - for five operations, plus the scope and identity a database reports in memory before it is
asked to do anything.

**The conditions the run must hold under, and what this machine can prove.** Two, and the answers go
into the output beside the cases so a reader can see which they hold under:

1. **THE PROCESS HAS NO NETWORK.** The runner proves it rather than trusting a flag: it opens one TCP
   connection to 1.1.1.1:443 and records what came back, and **refuses the run outright if the
   connection succeeds**. That refusal is the red control and it works:

       $ /tmp/database-host                                  # network available
       refused: "a TCP connection to 1.1.1.1:443 SUCCEEDED, so this run is not network-denied and a
                 case could have reached Apple's servers"      exit 1, cases: null

2. **THE ACCOUNT STATE, RECORDED NOT INTERPRETED.** `+[CKContainer accountStatusWithCompletionHandler:]`
   is declared by the iOS SDK and is not on this host, so the question is asked the way Foundation
   answers it: `-[NSFileManager ubiquityIdentityToken]`, which is nil with no iCloud account and answers
   locally with no network. **On the machine that took these numbers the token is NOT nil** - it is a
   20-byte token - so an iCloud account is signed in here and every measurement taken on this machine
   holds under *"an account is signed in AND the process has no network"*, not under "no account". A
   no-account measurement is a different claim and this machine cannot make it.

**The blocker, measured, and why the host side is not exported.** The denial cannot be applied to this
host's iOS CloudKit: a plain macOS binary runs fine under the profile, and the Catalyst binary is killed
by it.

    $ sandbox-exec -p '(version 1)(allow default)(deny network*)' /tmp/plain
    ran                                                                exit 0
    $ sandbox-exec -p '(version 1)(allow default)(deny network*)' /tmp/database-host
                                                                     exit 133, no output

133 is 128+5, a SIGTRAP: the binary dies at the probe connection, which is the very call the denial is
proved with, so the proof is what kills it. One defect of mine showed up on that path first and is
fixed: `strerror()` answers NULL when the sandbox maps the errno to a denied operation, and the message
handed it to `%s`, so Foundation raised `+[NSString stringWithUTF8String:]: NULL cString` and the run
died before recording anything. The errno number is the measurement and the text is now only offered
when there is one.

### Why a host differential cannot hold a CKContainer: the entitlement, not the account

**Measured, and the reason recorded earlier is withdrawn.** One experiment, on a Catalyst binary that
links CloudKit, logs, finds the class and calls exactly one method:

    [CK] Significant issue at CKContainer.m:760: In order to use CloudKit, your process must have a
          com.apple.developer.icloud-services entitlement. The value of this entitlement must be an
          array that includes the string "CloudKit" or "CloudKit-Anonymous" ...
    * thread #1, stop reason = EXC_BREAKPOINT (code=1, subcode=0x19610c2e8)

`+[CKContainer containerWithIdentifier:@"iCloud.x"]` and nothing else is enough: the process starts, logs,
resolves `CKContainer` at `0x1f0b35140`, and traps. Exit 133, which is 128+5, a SIGTRAP - the same
number the earlier "sandbox killed it" and "swizzle killed it" readings both produced, and the same trap
all three times. **So none of those was the cause: CloudKit traps in an unentitled process, and every
one of those experiments happened to call into CloudKit.** The withdrawn readings, for the record: a
Catalyst binary here does *not* die on swizzling a system method in general, and the sandbox-exec
profile was never implicated.

What this costs, stated plainly: **every member reached through a `CKContainer` or a `CKDatabase` is
unmeasurable on any host without entitlements** - the fetch, save, delete, add-zone, query and
subscription members alike, because the database cannot be built at all. It is not a question of
whether an iCloud account is signed in, and not a question of the network. The 36 ledger rows that
carry the owed measurement now say so: they need an entitled binary. No answer is asserted for any of
them, and none is written as absent.

**No entitlement will be signed, and no machine state changed.** The entitlement is the owner's to hold
and this program does not ask for it.

**What is left, and it is enough to work with.** The classes that never need a container are unaffected:
`CKRecordZone`, `CKShare` and its participants, `CKUserIdentityLookupInfo`, `CKRecordKeyValueSetting`,
`CKSyncEngineState`. They are built in memory, read back, archived and compared, and none of their cases
mentions `CKContainer` or `CKDatabase` at all. The differential for them is in hand, and the
runner asserts that statically.

The `CKDatabase` rows therefore stay owed and unwritten, and the families that need no container are the
work.

### CKRecordZone, measured on the host with no container

`tests/backports/host/cloudkit/database-cases.m` builds zones in memory and asks nothing of a
container, so it runs at all on a host without the entitlement. Run as a Mac Catalyst binary against the
iOSSupport CloudKit, exit 0, no network, no account read, no state changed. The host's own answers:

| case | zoneName | ownerName | capabilities | description | copy is equal | equal to self |
| --- | --- | --- | --- | --- | --- | --- |
| `initWithZoneName:` | probe | `__defaultOwner__` | 0 | `<CKRecordZone: 0x…; zoneID=…>` | **no** | yes |
| `initWithZoneID:` | probe | `__defaultOwner__` | 0 | `<CKRecordZone: 0x…; zoneID=…>` | **no** | yes |
| `new` | probe | `__defaultOwner__` | 0 | `<CKRecordZone: 0x…; zoneID=…>` | **no** | yes |
| `defaultRecordZone` | `__defaultZone__` | `__defaultOwner__` | 0 | `<CKRecordZone: 0x…; zoneID=…>` | **no** | yes |

Three of these are answers a port would plausibly get wrong, and they are the reason the family is worth
measuring:

* **`-init` does not raise.** It returns an object whose `zoneID.zoneName` is nil. The port's `CKRecordZone`
  inherits NSObject's `-init`, so it will answer the same, but "inherits NSObject" is not a measurement
  and this is.
* **`-copy` is not equal to the original.** All four cases answer `copyIsEqual: no`, while `isEqual:` to
  *self* is yes. The port's `-copyWithZone:` returns `self`, which IS equal to the original - so the
  port and the host disagree here, and the port is the one that has to change.
* **The archive round trip decodes to an object that is not equal to the original** (`equal: false`), and
  the port's keys are its own, so this is a case where a port is *expected* to differ and the comparison
  has to say so rather than call it a defect.

`capabilities` reads 0 for a zone made from a name on the host. The port's `CKRecordZone` has **no
properties at all** - no `zoneID`, no `capabilities` - so both are owed, and `zoneID` is the one a
caller reads first.

Unfinished, and the next step in order: wire the static assertion to the branch that runs (the run
currently prints "NOT YET IN PLACE" from the branch left over when the swizzle was removed, so the
assertion is written but not the code path that is taken); then build `database-port.m` against this
package with no framework linked, run the same cases, and compare with a red control; then implement
`zoneID` and `capabilities`, and only then write rows.

### The port's own objects under the host's toolchain

To answer the same cases with the port, its sources compile with no CloudKit framework linked. Measured
for the Catalyst target this differential is built for, with the same clang and SDK the host build uses:

    24 of the 28 sources compile; 4 do not:
      CKValues16.m      illegal redeclaration of property in class ext (CKValues16.m:21, :22)
      CKSyncEngine.m, CKSyncEngine17.m, CKSyncEngineState17.m

That is the **toolchain, not the port**: this tree's own target is `armv7-apple-ios6.1.3` against
iPhoneOS16.4, and all 28 sources compile clean there with
`-Werror=objc-missing-property-synthesis`. A property redeclared in a class extension is legal in the
language the port is written for and a modern clang against the 26.x SDK calls it an error, so the
Catalyst build of the *host* toolchain is stricter than the port's own. `CKRecords8.m`, which is where
`CKRecordZone` is defined, compiles, so the zone differential is not blocked by this; the sync engine
family is, and the reason belongs to the toolchain and not to a row.

### The zone differential compares, and the port differs in six of seven cases

`zone-port.m` runs the same cases with the port's own objects and **no CloudKit framework linked**. Two
objects are enough for it - `CKRecords8.o`, where `CKRecordZone` is defined, and `CKConstants8.o`, for
the default-name constants - and linking the whole package is not possible for this target:
`libmicro-ecc.a` is a device archive and carries no macabi slice. That is a property of the toolchain,
and the differential says which objects it used rather than implying it used all of them.

Six of the seven cases DIFFER, and none of them is a surprise once read:

| case | host | port | what it means |
| --- | --- | --- | --- |
| `initWithZoneName:`, `initWithZoneID:`, `new`, `defaultRecordZone` | `copyIsEqual: no` | `copyIsEqual: yes` | **the port's `-copyWithZone:` returns `self`, which is equal; the host's copy is not.** The port changes. |
| `init` | `zoneID.zoneName` is nil | `""` | the port's `-init` answers an empty name where the host answers none. |
| `archiveRoundTrip` | decodes, `equal: no` | decodes, `equal: yes` | expected to differ: a port ships its own archive keys, so a round trip that decodes to an equal object is the *better* answer, and the comparison is told to expect it rather than to call it a defect. |

**The red control fires.** A planted `-[CKRecordZone capabilities] { return 7; }` in the port makes the
comparison report `host capabilities=0  port capabilities=7  -> DIFFER`, and the plant is reverted. So
the comparison is not reading two files and finding them the same by construction: it catches a wrong
answer planted in the port, which is the only way a comparison can be trusted before it is used to
accept anything.

The copy difference is the one that matters and it is the host's measured behaviour, not a preference:
four independent constructions answer it, so it is a property of the class and not of one way of
building one.

### CKRecordZone contradicts its own header, and the host says which side is right

Reading the port's `CKRecords8.m` to apply the measured answers turned up something the differential
did not need to find. The file's own header, at its top, says:

    //    same type are never equal - CKRecord has no isEqual: at all, so equality is ide[...]
    //    different object, and its isEqual: is identity too. CKRecordZoneID, CKRecordZone[...]

The header documents **identity equality** for `CKRecordZone`, and the host agrees with the header and
not with the code: a copy is not equal to the original, a zone decoded from an archive is not equal to
the one archived, and an object is equal to itself. The class implements name-based equality instead -
`return [_zoneName isEqualToString:that->_zoneName] && ...` and `hash` from the two names - and its
`-copyWithZone:` returns `self`. So the port has been doing the opposite of what its own documentation
says, and the three differences the comparison reports are that one mistake showing up three times.

`CKRecordZoneID` is the other half of it and is the opposite: a zone **identifier** is a value, two
built from the same name and owner are the same identifier, and the host's answers agree. So the two
classes in one file answer equality differently on purpose, and the one that is wrong is the one the
header already described correctly.

Two corrections to what I said earlier, both mine: the port's `CKRecordZone` **does** declare
`zoneID` and `capabilities` - `@synthesize zoneID = _zoneID;` and
`@synthesize capabilities = _capabilities;` are at the top of the class - so "no properties at all" was
wrong, and `capabilities` already reads 0, which is what the host reads. Only the three below are owed.

The three edits, and the measurement behind each:

| what | the host answers | the port does | owed |
| --- | --- | --- | --- |
| `-copyWithZone:` | not equal to the original, all four constructions | returns `self`, equal by construction | a real copy |
| `-isEqual:` / `-hash` | identity | name-based | identity |
| `-init` | `zoneID.zoneName` is nil | an empty name | leave `_zoneID` nil |

The archive round trip follows from identity equality rather than being an exception: a zone decoded
back is a different object, so it is not equal, and that is what the host answers.

### CKRecordZone: the edits, what they fixed, and the description the host actually prints

The comparison is now **2 same, 4 differ**, and every one of the four is the `description` string. Two
edits were needed, not three, and they were not the ones the difference list pointed at:

* **`-isEqual:` and `-hash` are identity.** The class compared the zoneID and the capabilities, so a
  copy of a zone was equal to the zone it was copied from - the value answer where the host gives
  identity. With identity, `copyIsEqual` reads `false` in all four construction cases on both sides, the
  way the host reads it, and the archive round trip follows: a decoded zone is a different object and
  so is not equal, which is what the host answers. The file's own header said this and the code said the
  opposite.
* **`-init` leaves `_zoneID` nil.** It was building a zone of the *empty* name, and the host answers a
  zone of *no* name - `zoneID.zoneName` is nil. A zone of the empty name is a different object from a
  zone of no name, and the measurement says which one `-init` makes.
* **the copy is built the way the object was built.** `-copyWithZone:` went through
  `initWithZoneID:`, which refuses a nil zoneID - and `+new`'s zone has none, so copying a `+new` zone
  raised `CKException: zoneID can not be nil` and the run lost the five cases after it. The copy now
  starts from `init` and carries the zoneID across. The two edits interact, which is why the first
  attempt at them made things worse before it made them better.

**The host's exact description, measured, and it names two more owed properties:**

    <CKRecordZone: 0x7636c48640; zoneID=<null>, capabilities=(none), encryptionScope=per-record, share=<null>>
    <CKRecordZone: 0x…; zoneID=probe:__defaultOwner__, capabilities=(none), encryptionScope=per-record, share=<null>>

Four fields after the address: the zoneID rendered as `name:owner` or `<null>`, the capabilities as
`(none)` when zero, an `encryptionScope`, and a `share`. The port currently prints
`<CKRecordZone: %p; zoneID=%@, capabilities=%ld>`, so it is the shape and not the values that differ -
and `encryptionScope` and `share` are two properties the 26.2 header declares, both in the owed list for
this class, which the description is how the host revealed them. The address is an address: no port can
match it and the comparison normalises it away.

So the zone family is **not finished**: four cases still differ, all on that one string, and two more
members are owed. The next step is the description in the host's exact format, `encryptionScope` and
`share` measured and implemented, then the capabilities plant rerun against the real implementation, then
the rows.

### CKRecordZone: what the host says about the three properties, measured

The 26.2 header, read directly:

    @property (readonly, copy) CKRecordZoneID *zoneID;
    @property (readonly, assign) CKRecordZoneCapabilities capabilities;
    @property (nullable, readonly, copy) CKReference *share   API_AVAILABLE(... ios(15.0) ...)

**All three are readonly, so there is no setter to measure and none will be invented.** The header also
says of `capabilities` that "capabilities on locally-created record zones are not valid until the record
zone is saved", and of `share` that it "will only be set on zones fetched from the server" - and a saved
or fetched zone needs a container, which needs the entitlement, which a host differential here cannot
have. Measured on the host for a zone built in memory:

    capabilities    = 0
    encryptionScope = 0  (CKRecordZoneEncryptionScopePerRecord, the header's default)
    share           = nil
    description     = <CKRecordZone: 0x…; zoneID=<null>, capabilities=(none),
                      encryptionScope=per-record, share=<null>>

**The bit names cannot be measured here, and that is the answer to "each combination you can
construct": none of them.** `capabilities` is readonly and only becomes valid on a saved zone, so there
is no bit combination this binary can construct. What the host renders is measured for the one value it
can reach: **zero renders as `(none)`**. The names for the other bits come from the header, which is
Apple's own text - `FetchChanges = 1 << 0`, `Atomic = 1 << 1`, `Sharing = 1 << 2`,
`ZoneWideSharing = 1 << 3` - and not from a measurement, and the facts say so rather than presenting a
header transcription as a host answer.

So the port implements `(none)` for zero, the header's names for the bits a caller passes in, and the
two defaults this section measured. The address in the description is normalised away by the comparison:
it is an address, no port can match it, and what has to agree is everything after it.

### The zone comparison reads zero DIFFERs, and the control does not fire

The port now implements the description in the host's measured format, with `encryptionScope` and
`share` carrying the defaults this host answers (`PerRecord`, nil), and the comparison reads:

    6 same, 0 differ, raisedDuring: null

**And the red control FAILED against the real implementation.** A planted
`-[CKRecordZone capabilities] { return 7; }` did not make the comparison report a difference - the port
still answered `capabilities 0` and the case still compared SAME. The same plant fired before the
implementation existed, so something about the implemented class swallows an explicit accessor: the
class carries `@synthesize capabilities = _capabilities;`, and whatever the planted method was, the port
did not answer with it.

That means the zero above is **not yet evidence that the comparison is sensitive**. It is evidence that
the two sides agree, and agreement is only worth something once a wrong answer is shown to be caught.
So no row may be written on the strength of it, and the next step is to find out why the plant is
swallowed - whether the explicit method loses to the synthesized one, whether the case reaches the value
some other way, or whether the compile of the planted object failed and the old one was linked - and then
to rerun the control until it fires, before the rows.

The earlier control, before the implementation, did fire, so the check is not dead; the plant is being
lost somewhere in the implemented class. That is the thing to look at first.

### A stale object, and a sentinel so it can never be silent again

The red control that would not fire was a **stale object**, not a swallowed accessor. The build
directory is cleared and rebuilt on every run now, and every plant carries a sentinel the link must show
before the plant counts:

    int RevenantPlantMarker = 1;

    $ nm /tmp/zone-port | grep RevenantPlantMarker
    the sentinel IS in the linked binary - the link is not stale

With that in place the control fires: a planted `-[CKRecordZone capabilities] { return 7; }` in a rebuilt
object makes the comparison report DIFFER. The explicit accessor does take, as the coordinator said it
would; the earlier "the control failed" was my own build directory handing back the previous object.

**And the clean build changes the other number too, which is the part that matters.** The unplanted run
that read `6 same, 0 differ` against a stale object now reads **DIFFER** against a freshly built one. So
the zero was not evidence of anything, and the coordinator's diagnosis is right twice over: the stale
object hid the plant, and it very likely hid a real difference as well. Nothing may be written on the
strength of that zero, and the comparison has to be rerun from a cleared build before any row means
anything.

`nm` on the object also shows why a zone answer can be hard to read: both classes have a `capabilities`
method -

    0000000000002564 non-external -[CKRecordZone capabilities]
    0000000000000470 non-external -[CKRecordZoneID capabilities]

so a case that means `capabilities` without saying which class says nothing, and the planted run
reported the *case's* numeric read as 0 while the comparison still caught the difference. That is the
check working and the wording of the case being loose; the cases name the class in every selector, and
this is why.

### A commit of mine described work its content does not contain

The commit titled "Implement the zone's measured description and its two properties, at zero
DIFFERs" and its body describes the description format, `encryptionScope`, `share`, identity equality
and the copy fix. **Its content contains none of it.** Checked directly:

    $ git show <that commit>:packages/a/apple-backports/CloudKit/CKRecords8.m | grep -c encryptionScope
    0

The order of my own commands produced it: the implementation was made in the working tree, the plant
script then ran `git checkout packages/a/apple-backports/CloudKit/CKRecords8.m` to undo the plant - and
`git checkout` on a path undoes **every** uncommitted change to that path, the implementation included,
not just the plant. I committed after that checkout, so the commit took the pre-implementation file
under a message describing the implementation.

Two things follow, and the second is the one that matters most here:

* the six-same comparison in that commit was reading the pre-implementation object, so it was never a
  measurement of the implementation. It is withdrawn twice over now - once for the stale object and once
  for this.
* **a commit whose message overstates its own content is the worst kind of defect in a series that is
  being gated**, because a reviewer reads the message and the diff is the only thing that would catch
  it. The plant must therefore not be undone with `git checkout` on the file it plants in; it reverts
  the uncommitted work as well as the plant. The tree is left as c11 had it rather than committed half
  applied, and the implementation is re-applied and verified from a cleared build before any row or
  export - which is where this work now stands.

### The plant is in the binary and still does not fire

The rules from here: commit the implementation before any plant, plants go in a **scratch copy** in the
run's own directory, and never in the tracked file, and never undone with `git checkout`. The
implementation is committed, the scratch copy carries the plant and a sentinel, and the tracked file is
untouched - `git status` on it reads empty after the run.

**And the control still fails, with the sentinel present.** So this is not a stale link this time:

    sentinel RevenantPlantMarker IS in the linked binary - the link is not stale
    nm /tmp/zone-planted | grep -c RevenantPlantMarker        1
    capabilities symbols in the planted object               3
    PLANTED: same 6  differ 0  -> the control FAILED

The planted accessor is compiled, linked and present, and the case still answers as if it were not
there. What is known so far, all measured: the object is the scratch copy, the link carries the
sentinel, the object holds three `capabilities` symbols, and a binary linking only Foundation and
CoreLocation has **no CloudKit image at all** - `NSClassFromString(@"CKRecordZone")` reads nil there -
so the class under test can only be the port's.

What has not been established, and is the next thing to look at: which implementation the case's
`capabilities` message actually reaches. Until that is answered the comparison is **not** shown to be
sensitive, and so it cannot support a row - a differential that cannot be shown to catch a planted
wrong answer has not earned the right to say the two sides agree. That is why there are no rows and no
export in this commit: the coordinator's own precondition, that the control fires, is not met.

### A selector I read as a defect in the port was my own plant, and the plant's anchor was wrong

The grep settles how the case reads the number, and it also turns up a defect in its own right.

**How the case reads it.** `database-cases.m` mentions `capabilities` in exactly one reading place:

    answer[@"capabilities"] = @(zone.capabilities);

A direct property read on the zone. There is no ivar access, no `valueForKey:`, no parse of the
description, no cached value, and no read from the zoneID — so the case is asking the zone's getter and
nothing else, and the planted getter is what it should be reaching.

**And the SDK's `CKRecordZoneID` has no `capabilities` at all.** Read directly, in full:

    @interface CKRecordZoneID : NSObject <NSSecureCoding, NSCopying>
    - (instancetype)init NS_UNAVAILABLE;
    + (instancetype)new NS_UNAVAILABLE;
    - (instancetype)initWithZoneName:(NSString *)zoneName ownerName:(NSString *)ownerName;
    @property (readonly, copy, nonatomic) NSString *zoneName;
    @property (readonly, copy, nonatomic) NSString *ownerName;
    @end

Five members, none of them `capabilities`. Yet the port's object exports one:

    0000000000000470 non-external -[CKRecordZoneID capabilities]

**That is a real defect in the port, independent of the plant.** A selector Apple's class does not
declare is a selector a caller cannot have written against the SDK, so nothing legitimately sends it —
and the only files in the package that mention `capabilities` at all are `CKRecords8.m` and
`CKOperations8.m`, and the one in `CKOperations8.m` is a *read* of `zone.capabilities` inside another
class's `-main`, not an implementation. So the method is emitted from somewhere in `CKRecords8.m` that
has not yet been identified, and it is the prime suspect for shadowing: a method the compiler emits on
one class while a plant in another object's class implementation goes unanswered is exactly the shape
of a symbol this differential has just been bitten by twice.

So the next step is to find what emits `-[CKRecordZoneID capabilities]` in `CKRecords8.m` - a second
`@synthesize`, or a category on one of the two classes that a scoped grep over the class block missed -
and to remove it, because a port must not vend a selector the SDK does not declare. Then the plant
should fire, the unplanted run should still read zero, and only then the rows and the export.

**Both halves of that entry were mine, and the coordinator's single-cause explanation is the right one.**
The stray `-[CKRecordZoneID capabilities]` is not in the port: `git show 38376e229:.../CKRecords8.m`
has `capabilities` only inside `CKRecordZone`, and the tracked file in this worktree had **zero** lines
of plant residue when I went looking for it. The stray was the plant itself, compiled into the scratch
object, and I read my own residue as a defect in the port. That claim is withdrawn.

**The plant's anchor was the bug, and it is one bug for every symptom.** The script inserted before the
**first** `- (BOOL)isEqual:(id)other` in the file, and the first one is at line 124 - inside
`@implementation CKRecordZoneID`, which starts at line 77. So every plant ever run went into
`CKRecordZoneID` and none touched `CKRecordZone`, which is why the case kept answering with the real
getter while the sentinel, the object and the link were all perfectly fine. It also explains "three
capabilities symbols in the planted object": the stray and the plant are the same method, counted twice
alongside the real accessor.

The anchor is now on `@implementation CKRecordZone` and the landing is printed, so the next run cannot
land in the wrong class silently:

    @implementation CKRecordZone {   at line 452
    - (BOOL)isEqual:(id)other        at line 567   <- the anchor, inside CKRecordZone

and the control, which had not fired through a stale object, a stale link and a missing class all at
once:

    sentinel RevenantPlantMarker IS in the linked binary - the link is not stale
    PLANTED: same 2  differ 4  -> THE CONTROL FIRED

The lesson worth keeping, and it is not about this file: a control that does not fire is the most
expensive thing in a differential, and this one survived three wrong explanations before the fifth
sentence of a diff was read. The three were mine and each looked conclusive - a stale object, a stale
link, a defect in the port - because each explained the symptom and none was checked against the
script that produced it.

### The capability numbers from the header, and a gap in the mirror that stops the rows

`CKRecordZoneCapabilities`, read straight out of the 26.2 header rather than from a memory or a
transcription, with the numbers a caller passes SDK numbers with:

| bit | header | value | declared from |
| --- | --- | --- | --- |
| `CKRecordZoneCapabilityFetchChanges` | `1 << 0` | **1** | with the type, ios(8.0) |
| `CKRecordZoneCapabilityAtomic` | `1 << 1` | **2** | with the type, ios(8.0) |
| `CKRecordZoneCapabilitySharing` | `1 << 2` | **4** | ios(10.0) |
| `CKRecordZoneCapabilityZoneWideSharing` | `1 << 3` | **8** | ios(15.0) |

The type itself carries `API_AVAILABLE(... ios(8.0) ...)`, which is why the first two have no
availability of their own.

**And the four property rows are written, measured, and then taken back, because the mirror refuses
them.** The rows would be `CKRecordZone.zoneID`, `CKRecordZone.capabilities`,
`CKRecordZone.encryptionScope` and `CKRecordZone.share` - all four measured on the host, all four
answered by the port - and the mirror says:

    FAIL a row with no definition in this tree: property CKRecordZone.capabilities,
         property CKRecordZone.encryptionScope, property CKRecordZone.share, property CKRecordZone.zoneID

The reason is the mirror's own keying, and it is a gap rather than a defect in the rows: it keys on
`(kind, api)`, and for a `property` row the api is `CKRecordZone.zoneID` - a **selector**, not a class
symbol - so it is looked for among the implementations and never found. A property row's definition is
a method on the class that owns it, so the mirror has to resolve `Class.property` to its class and ask
whether that class is defined. The checklist and the gate do not have this problem, which is why only
the mirror objects.

**A same-shape neighbour that passes, or there is none to find.** The coordinator is right that I called
it a gap without looking, so: the mirror matches **only `@implementation X`** - it greps
`@implementation\s+(\w+)` and nothing else, no `@synthesize`, no `@dynamic`, no getter, no property -
so a `property` row's api, which is a selector, can never be found among the implementations. There are
**4490 `kind: property` rows** under `packages/a/apple-backports/registry/`, so the shape is common in
this repository. Every one of them belongs to another framework, though: the mirror is a **CloudKit-only**
tool and reads `registry/CloudKit/values.json`, which has **no property rows at all** - 80 class, 13
method, 25 constant. So there is no CloudKit neighbour of this shape that passes, because the mirror has
never been asked this question in this tree.

What the other frameworks' 4490 property rows are checked by is the gate, and the gate passes on them -
so the shape is not wrong in this repository and the rule that admits it exists elsewhere. That makes
this a tool gap in a CloudKit-only tool rather than a defect in the four rows, but it is a claim about
the gate's handling that I have not read, and I am not recording it as measured.

**The rows are written**, now that the CloudKit mirror resolves a property row to its class the way it
already resolved a method row, with a red control that a property naming an undefined class still fails.
`CKRecordZone.zoneID`, `CKRecordZone.capabilities`, `CKRecordZone.encryptionScope` and
`CKRecordZone.share`: every one measured on the host, every one answered by the port, and the mirror
reads 0 in all four directions afterwards. The four capability numbers they record - 1, 2, 4 and 8 - are
read from the 26.2 header and are the numbers the port's own description tests its bits with, so an app
that passes SDK numbers and the port that prints them are reading the same header.

Landing four rows that turn a check red to keep a promise about writing rows is the wrong trade, so they
were taken back first and written second, which is the right order and took one commit longer and the tree is as c11 left it. The next step is the mirror's resolution for property
rows, then the rows, then the export.
