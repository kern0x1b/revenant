# Query generations, iOS 10.0

iOS 10 let a context read from one snapshot of a SQLite store, so that a fetch made
after another context saved still saw the data it saw before. A context is pinned with
`-setQueryGenerationFromToken:error:` and a token, and the token most applications use
is `+[NSQueryGenerationToken currentQueryGenerationToken]`, which stands for the
generation the context reads first.

Source: CoreData of the arm64 shared cache of iOS 12.0 -
`-[NSManagedObjectContext queryGenerationToken]` and
`-setQueryGenerationFromToken:error:`, `+[NSQueryGenerationToken currentQueryGenerationToken]`
and the coding of the private subclass; the host's Core Data, with a SQLite store and an
in-memory one, and an iPad 2 running 6.1.3.

## What is carried

- `+currentQueryGenerationToken` answers one object, whose description is
  `<NSQueryGenerationToken : (null)/current>`. It is its own copy, equals itself, codes
  securely - `NSQueryTokenIsSingleton` YES and `NSQueryTokenWhichSingleton` 2 - and decodes
  to itself. A token made with `alloc` and `init` is the abstract class's, which has no
  coordinator to answer, and pinning to it raises the unrecognised selector that iOS 12
  raises. iOS 12 makes the current token an instance of a private subclass,
  `_NSQueryGenerationToken`; here it is an instance of `NSQueryGenerationToken` itself, which
  is only visible to a caller that asks for the name of its class.
- `-[NSManagedObjectContext queryGenerationToken]` answers `nil` until a token was set, and the
  token after, and `nil` again once `nil` is set.
- `-setQueryGenerationFromToken:error:` keeps the token and answers YES, for the current
  token and for `nil`, which unpins. A context that has no coordinator answers NO and an
  `NSCocoaErrorDomain` error 134060 whose user info says "Cannot set a query generation on an
  NSManagedObjectContext that does not have a coordinator". A token of another coordinator is
  taken, as it is in iOS 12.

## Where iOS 6 differs, and what is not known

**The store's default journal is not the reason, and an earlier version of this file said it was.** The
SQLite of 6.1.3 is 3.7.x and takes `journal_mode=WAL`, and a store opens one through
`NSSQLitePragmasOption` — iOS 5 API the release carries. So "the store keeps a rollback journal and
reads the latest rows only" is a statement about a *default*, not about what the release can do.

**What is not known:** whether a second connection's read stays on its snapshot after a write on the
release, with a store opened that way. That is the one thing the answer turns on, and it is asked of the
release by `tests/backports/device/coredata-wal-snapshot.m` (run by
`tests/backports/host/coredatanames/emulate.sh`, a `daemon` target on the 6.1.3 emulator).

**What the port does meanwhile:** a context pinned to the current generation is answered YES and reads
the latest rows, which is what the newest Core Data does for a store that keeps no generations — the
in-memory store answers YES to the pinning and reads the latest rows. A call that failed would stop
every application that pins its contexts at start-up, and the token itself resolves so that such an
application loads. **An application that needs the isolation does not get it, and this file does not
claim that the release cannot provide it.** Apple's own `swift-corelibs-foundation` carries no Core
Data, and the `sqlite3_snapshot_*` family needs 3.10 or later, so if the release's 3.7 does not hold the
read transaction, a vendored snapshot layer is the next step rather than a rewrite of the reason.
