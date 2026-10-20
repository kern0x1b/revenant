# NSPersistentContainer, NSPersistentStoreDescription, and what iOS 10 added to Core Data around them

Introduced in iOS 10.0. A container that sets up a Core Data stack from a name,
the description of a store it loads, and the members iOS 10 gave the classes
iOS 6 already has.

Source: CoreData of the armv7s cache of iOS 10.3.4, the host's own Core Data run
beside the port, and CoreData of iOS 6.0 for what the release lacks. The newest
implementation is carried where the two differ; each place is named below.

It lives in its own library, `libCoreDataBackports.dylib`, built with the
`coredata` config, so that a process which never uses Core Data does not load
it. `NSFetchedResultsController` is iOS 3's own and is not touched.

## The description of a store

A thin wrapper over the options dictionary the coordinator takes:

| property | option |
|---|---|
| `readOnly` | `NSReadOnlyPersistentStoreOption` |
| `timeout` | `NSPersistentStoreTimeoutOption`; with none set, 240 - the newest release's answer, where 10.3.4 read an absent option as 0 |
| `sqlitePragmas`, `-setValue:forPragmaNamed:` | `NSSQLitePragmasOption`; a pragma set to nil is taken out and leaves the dictionary, empty or not |
| `shouldAddStoreAsynchronously` | `NSAddStoreAsynchronouslyOption`, a key of Core Data's own that the store of iOS 6 ignores |
| `shouldMigrateStoreAutomatically` | `NSMigratePersistentStoresAutomaticallyOption` |
| `shouldInferMappingModelAutomatically` | `NSInferMappingModelAutomaticallyOption` |

`-setOption:forKey:` with nil takes the key out. A fresh description is SQLite,
migrating and inferring; `-init` points it at `/dev/null`. Two descriptions are
equal when their URL, type, configuration and options are; a copy is equal and
not the same. Described as `[super description]` followed by
`(type: %@, url: %@)`. Held to the host's own on 156 answers.

## The container

- `-init` raises `NSGenericException`:
  `Failed to call designated initializer on 'NSPersistentContainer' ` and a newline.
- `-initWithName:` looks for `name.momd`, then `name.mom`, in the main bundle
  and then the bundle of the class. With neither, it says
  `Failed to load model named %@` in the log and goes on with an empty model,
  as the newest release does, rather than none.
- The coordinator is made on the model, the view context on the main queue,
  and the one description is SQLite at `name.sqlite` in `+defaultDirectoryURL`:
  Application Support of the user's domain, made the first time it is asked
  for if it is not there.
- `-loadPersistentStoresWithCompletionHandler:` hands every description to the
  coordinator. A store not asked to load asynchronously loads at once and the
  handler runs on the calling thread; one that is, on a global queue.
- `-newBackgroundContext` is a private queue context on the same coordinator;
  `-performBackgroundTask:` runs the block in a new one.

## The members iOS 10 added

- `-[NSPersistentStoreCoordinator addPersistentStoreWithDescription:completionHandler:]`
  adds the store with the description's type, configuration, URL and options.
- `+[NSManagedObject entity]` finds the one entity whose class is the receiver
  among the models a coordinator was made on. With none, or with more than
  one, it says so in the log in the newest release's words and answers nil.
  Knowing those models needs `-[NSPersistentStoreCoordinator initWithManagedObjectModel:]`
  to remember them, which the port arranges.
- `+[NSManagedObject fetchRequest]` asks for that entity **by name**, as the
  newest release does, so the entity is found when a context runs the request;
  10.3.4 set the entity itself.
- `-[NSManagedObject initWithContext:]` takes the entity of its class from the
  context's model and inserts the object; with none, the release's own
  `-initWithEntity:insertIntoManagedObjectContext:` raises as it always has.
- `-[NSFetchRequest execute:]` runs in the context whose block is running on
  the thread. Outside one it answers nil and `NSCocoaErrorDomain` 134060 with
  the user info `message: Cannot fetch without an NSManagedObjectContext in scope`.
  iOS 10 keeps that context in a slot of the thread set by its own
  `-performBlock:` and `-performBlockAndWait:`; iOS 6's set nothing, so the port
  wraps the two to set its own. As on the host's Core Data, a block inside
  another context's block fetches in its own and the outer context is back
  after it, another thread has no context, and a block that raises leaves none
  behind.
- `automaticallyMergesChangesFromParent`: off by default. On, the context merges
  every save of its parent, or, with no parent, of any other context on its
  coordinator that has no parent either, inside its own block. A context of
  `NSConfinementConcurrencyType` refuses: `NSInvalidArgumentException`,
  `Automatic merging is not supported by contexts using NSConfinementConcurrencyType`.
- `+[NSMergePolicy errorMergePolicy]` and the other four answer the release's
  own `NSErrorMergePolicy`, `NSRollbackMergePolicy`, `NSOverwriteMergePolicy`,
  `NSMergeByPropertyObjectTrumpMergePolicy` and `NSMergeByPropertyStoreTrumpMergePolicy`.

The wrapping of `-performBlock:`, `-performBlockAndWait:` and
`-initWithManagedObjectModel:` is set up only where the process's
`NSPersistentContainer` is the port's own, so a release that has Core Data's
own container is left as it is.

## Not carried

- `NSManagedObjectContextQueryGenerationKey`, the option of a store that pins its
  contexts to a snapshot, which the store of iOS 6 does not have. The query generation
  token and the pinning of a context are carried, and read the latest rows:
  `facts/CoreData/QueryGeneration.md`.
- `NSPersistentStoreConnectionPoolMaxSizeKey`: the store of iOS 6 reads through
  one connection.
- The notifications of object IDs - `NSManagedObjectContextDidSaveObjectIDsNotification`,
  `NSManagedObjectContextDidMergeChangesObjectIDsNotification` and their keys:
  the release posts `NSManagedObjectContextDidSaveNotification` with the
  objects themselves, and nothing posts these.

## How it is held

The description on the host, 156 answers against Core Data's own. On an
iPhone4,1 and on an iPad2,2, both running 6.1.3, a process loads a SQLite store
and an in-memory one asynchronously, inserts through `-initWithContext:`,
fetches through `+fetchRequest` and `-execute:` in and out of a context's block,
saves in a background task and watches the view context merge it, refuses a
class no entity claims, and holds every text and default above: 30 checks, no
failures on each.
