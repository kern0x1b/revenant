# Batch delete, iOS 9.0 and 10.0

iOS 9 let an application remove every object a fetch request finds without loading
them, in one statement of the SQLite store, and iOS 10 added the form that takes the
object IDs to remove. The request is executed with `-[NSManagedObjectContext
executeRequest:error:]`, which iOS 8 introduced with the asynchronous fetch and the
batch update.

Source: CoreData of the arm64 shared cache of iOS 12.0 - `-[NSBatchDeleteRequest
initWithFetchRequest:]`, `-initWithObjectIDs:`, `-requestType` and `-description`,
`-[NSBatchDeleteResult initWithResultType:andObject:]`, and `-[NSManagedObjectContext
executeRequest:error:]`, read case by case, with the strings of the messages. The host's
Core Data, on a store of its own next to the port's on a twin store, for what a batch
delete removes and answers (`tests/backports/host/batchdelete`), and an iPad 2 running
6.1.3 (`tests/backports/device/batchdelete9.m`).

## The request

- `-initWithFetchRequest:` refuses `nil` (`NSInvalidArgumentException`, "Must supply a
  fetch request during initialization") and a fetch request whose entity name is `nil`
  ("Fetch must have an entity"). It keeps a **copy** of the fetch request, made to fetch
  object IDs alone: result type object IDs, no property values, no properties to fetch,
  no relationship key paths, refreshing no fetched objects, a batch size of 0 and
  **no pending changes**, and marks it in use, so that changing the copy the getter
  hands out raises. The limit, the offset, the sort and the predicate are kept. The
  getter answers the same copy each time.
- `-initWithObjectIDs:` refuses an empty array ("Must supply a non-zero number of
  objectIDs to request during initialization"), and object IDs of more than one root
  entity ("mismatched objectIDs in batch delete initializer", with the object IDs in the
  user info under `objectIDs`). It builds a fetch request of the root entity with the
  predicate `SELF IN <the object IDs>`, no pending changes and object IDs as a result,
  and goes on as the fetch request initialiser.
- The request type is 7. The result type starts as status only, and keeps whatever it is
  given. `-copy` is the superclass's, which makes a request that has no fetch request and
  no result type of its own, as it does in iOS 12.
- The description is `<NSBatchDeleteRequest : resultType : <n>, fetch :<the fetch request> >`.

## The result

`NSBatchDeleteResult` holds a result and a result type, and answers nothing and status
only when it is made with `init`. `NSPersistentStoreResult` is its empty base class.
What a request answers: status only, `YES`; object IDs, the array of the object IDs of
what was removed; count, the number.

## Executing it

In iOS 12 the context asks the request type and, for a batch delete, hands the request
to its coordinator, whose SQL store removes the rows with a statement of its own,
without loading the objects and without asking the objects of any context. The objects
of the calling context are left as they are, neither marked deleted nor refreshed, and
the application brings them up to date by merging the object IDs it was given.

iOS 6's store cannot be asked for a statement, so the port does the removal in the
one way the release allows: it runs the fetch request, with managed objects as its
result, in a private context of its own on the same coordinator, deletes every object it
finds and saves. The store is changed and the calling context is left alone, exactly as
in iOS 12, and the answer is the same. The host's answers are the port's, for a
predicate, a whole entity, no match, a limit with an order, another entity, a range of a
number, and the object IDs form, for each of the three result types; the pending insert
of the calling context stays pending.

A fetch request given to `-executeRequest:error:` is run as `-executeFetchRequest:error:`
and answers its array, because the release's coordinator raises for a fetch request that
was made with an entity name and has not been used by a context yet. Any other request
goes to the release's own `-[NSPersistentStoreCoordinator executeRequest:withContext:error:]`,
which is what iOS 12 does for the types it does not treat itself.

## Where iOS 6 differs

- The removal goes through a context, so the objects' **delete rules and validation
  run**, which iOS 12's statement does not do. A relationship with the deny rule can
  make the request fail, and it answers `nil` and the error the save gave.
- The private context's save posts `NSManagedObjectContextDidSaveNotification`, which
  iOS 12's batch delete does not. An observer of every context that merges what it
  is told will see the removal.
- iOS 12 answers a fetch request given to `-executeRequest:error:` with an
  `NSAsynchronousFetchResult`. That class is not carried, and the array of the fetch is
  what comes back.
