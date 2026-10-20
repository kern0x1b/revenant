# The CoreData names of iOS 7.0 to 18.0: 21 carried, and two reasons of mine that were wrong

**All 21 Objective-C constant rows of CoreData that the corpus lists as missing are carried here**,
with the texts CoreData of iOS 18.0 holds, read out of the arm64e shared cache through each symbol with
`tools/corpus/cache-value.lua`. Seven are this band's own decision; **nine were another band's `absent` and five
were mine, and all fourteen are re-opened below** because two of the reasons behind them were false.

## Why the texts are read and never typed

Nine of the twenty-one are **not their own name at all**, and a spelling of the constant would be a key
nothing ever reads:

| symbol | the value CoreData of iOS 18.0 holds |
| --- | --- |
| `NSManagedObjectContextQueryGenerationKey` | `newQueryGeneration` |
| `NSPersistentStoreConnectionPoolMaxSizeKey` | `NSPersistentStoreConnectionPoolMaxSize` |
| `NSInsertedObjectIDsKey` | `inserted_objectIDs` |
| `NSUpdatedObjectIDsKey` | `updated_objectIDs` |
| `NSDeletedObjectIDsKey` | `deleted_objectIDs` |
| `NSRefreshedObjectIDsKey` | `refreshed_objectIDs` |
| `NSInvalidatedObjectIDsKey` | `invalidated_objectIDs` |
| `NSPersistentStoreModelVersionChecksumKey` | `NSStoreModelVersionChecksumKey` |
| `NSPersistentCloudKitContainerEventUserInfoKey` | `event` |

**Checked against a second source**, the host's own CoreData, which exports all twenty-one:
`tests/backports/host/coredatanames` — **21 agreed, 0 differed**.

**One file per release**, because an object carries the API of one release: `CoreDataNames{70,100,103,140,
170,180}.m`.

## The first false reason: "iOS 6 has no iCloud at all"

**Wrong, and mine.** The armv7 shared cache of iOS 6.1.3, the `CoreData` image, 125 exports of its own,
among them:

    _NSPersistentStoreDidImportUbiquitousContentChangesNotification
    _NSPersistentStoreUbiquitousContentNameKey
    _NSPersistentStoreUbiquitousContentURLKey
    _NSUbiquityPeerIDOverrideKey

iCloud shipped with iOS 5.0 and Core Data's ubiquity is iOS 5.0 API that 6.1.3 carries. So the five
names of 7.0 that extend that machinery are **carried**, and what the release does with each is
recorded per row in `registry/CoreData/names.json`:

- `…RemoveUbiquitousMetadataOption` and `…RebuildFromUbiquitousContentOption` are store description
  options. A store is opened by its 6.0 name or URL — the two names above — and a rebuild is a
  re-import of that container. The option is carried and the store that reads it answers as it answers
  every option it has no code for.
- `…UbiquitousContainerIdentifierKey` names a container by identifier, which 7.0 replaced with an
  account-wide name; the release knows the name and the URL, not the identifier.
- `…UbiquitousPeerTokenOption` and `…UbiquitousTransitionTypeKey` belong to the container API of 7.0
  and have no half here: nothing answers the option, and the metadata key stays absent from what a
  store writes.

## The second false reason: "query generations need WAL, iOS 6 keeps a rollback journal"

**A default, not a limit — and the reason was another band's, quoted:**

> "query generations pin a context to a snapshot of a SQLite store read through write-ahead logging, and
> the store of iOS 6 keeps a rollback journal and reads the latest rows only"

(`registry/CoreData.json`, `NSManagedObjectContextQueryGenerationKey`, with a `maximum` of 10.0.)

The SQLite of 6.1.3 is 3.7.x and takes `journal_mode=WAL`, and a store opens one through
`NSSQLitePragmasOption` — which is iOS 5 API the release carries. **What is not yet measured is the one
thing the reason turns on: whether a second connection's read stays on its snapshot after a write on the
release.** That is the emulated 6.1.3 probe
`tests/backports/device/coredata-wal-snapshot.m` (run by `tests/backports/host/coredatanames/emulate.sh`),
and this file does not claim the answer. So the row is **carried as a constant, and the port does not
pin a generation**: the name resolves, a caller that writes under it gets the key it wrote, and the
behaviour is named as unmeasured rather than refused. Apple's own `swift-corelibs-foundation` carries no
Core Data, and the `sqlite3_snapshot_*` family needs 3.10 or later, so if the release's 3.7 turns out
not to hold the read transaction, a vendorable snapshot layer is the next step and not a rewrite.

## The five the object-ID notifications rest on, and why they are carried

The other four of the nine were `absent` for a reason that is **true** — *"the Core Data of iOS 6 posts
NSManagedObjectContextDidSaveNotification with the objects themselves, and the notification the object
IDs belong to is not posted"* — and a true reason about a *behaviour* is not a reason to withhold a
*name*. The release fills the objects and never an object-ID set, so the keys are carried and stay
**empty**: an empty set is what the release means by "no IDs", and an invented set would be a lie about
what changed. The two notifications of the same family are carried the same way: the release's
`NSManagedObjectContextDidSaveNotification` is still what a caller hears.

Everything else — the pool key, the three migration options, the Spotlight index notification, the
CloudKit container event and its userInfo key, the version checksum key — is in
`registry/CoreData/names.json` with its own effect.

## The seven that are not symbols at all

`NSManagedObjectContext.NotificationKey.{queryGeneration,deletedObjectIDs,insertedObjectIDs,
invalidatedObjectIDs,refreshedObjectIDs,updatedObjectIDs}` (10.0, 10.3) and
`NSManagedObjectContext.ScheduledTaskType.{enqueued,immediate}` (15.0) are **Swift enum cases**: the
compiler writes the value into a Swift caller and there is no symbol for an Objective-C library to
export. They are the Swift overlay's work and a different deliverable.
