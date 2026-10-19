# Persistent history, iOS 11.0 and 12.0

iOS 11 let a store keep a record of every transaction that changed it, so that one
process, or one extension, could ask what another had changed. An application turns
it on with `NSPersistentHistoryTrackingKey`, reads it with an
`NSPersistentHistoryChangeRequest`, and in iOS 12 is told through
`NSPersistentStoreRemoteChangeNotification` when another process has written.

The history is written and read by the SQL store of the newest Core Data. The store of
iOS 6 keeps none, and does not take the option, so this package carries what an
application names and asks with, and answers that nothing has been kept.

Source: CoreData of the arm64 shared cache of iOS 12.0 - `-[NSPersistentHistoryChangeRequest
initWithDate:delete:]` at `0x183aba7ac`, `-initWithToken:delete:`, `-setResultType:` at
`0x183abafc0`, `-requestType` at `0x183aa69c8` and `-description` at `0x183abb45c`;
`-[NSPersistentHistoryToken copyWithZone:]`, `-encodeWithCoder:` and `-initWithCoder:`;
`-[NSPersistentHistoryTransaction copyWithZone:]` and its accessors and
`-[NSPersistentHistoryChange copyWithZone:]` and its accessors; the method of the
coordinator at `0x183a6d8f4`; the strings of the constants. The host's Core Data
through `tests/backports/host/history11`, and an iPad 2 running 6.1.3.

## The request

A request is a value the application hands to a coordinator or a context.
- `+fetchHistoryAfterDate:`, `+fetchHistoryAfterToken:` and
  `+fetchHistoryAfterTransaction:` make a fetch, and the `delete...Before...` ones a
  delete. The transaction is asked for its token, and it is the token that is kept.
- A fetch's result type is `NSPersistentHistoryResultTypeTransactionsAndChanges`; a
  delete's is `NSPersistentHistoryResultTypeStatusOnly`, and `-setResultType:` on a
  delete keeps it whatever it is given. On a fetch it takes what it is given. A
  request made with `init` fetches transactions and changes.
- Its request type is 8, a copy is a new request of the same class with the same
  date or token, kind and result type, and the description is
  `NSPersistentHistoryChangeRequest : Fetch < <date> - <token>-<transaction number>> <result type as a number>`
  with `Delete` for a delete. The newest Core Data writes the result type as its name.

Nothing here answers a request: the coordinator of this release refuses a request
type it does not know, and that is what the application meets.

## The objects a fetch answers with

`NSPersistentHistoryToken`, `NSPersistentHistoryTransaction` and
`NSPersistentHistoryChange` are abstract in iOS 12 and are made, in their concrete
kinds, by the store. They copy to themselves, and everything else asks for a concrete
implementation and raises `NSInvalidArgumentException` with `*** -<selector> cannot be
sent to an abstract object of class <class>: Create a concrete instance!`. The package
does the same, with the same text; the host's Core Data answers the same words for the
same calls. `NSPersistentHistoryResult` is a plain holder of a result and a type.

## Constants

`NSPersistentHistoryTrackingKey` is `NSPersistentHistoryTrackingKey`,
`NSPersistentHistoryTokenKey` is `historyToken`, `NSPersistentStoreURLKey` is `storeURL`,
`NSPersistentStoreRemoteChangeNotification` is its own name,
`NSBinaryStoreSecureDecodingClasses` is its own name,
`NSBinaryStoreInsecureDecodingCompatibilityOption` is
`_NSBinaryStoreInsecureDecodingCompatibilityOption` and `NSCoreDataCoreSpotlightExporter`
is its own name. The remote change notification is never posted.

## Two more members

`-[NSManagedObjectContext transactionAuthor]` and its setter keep a copy of a string
that nothing reads, since no history is written to carry it.
`-[NSPersistentStoreCoordinator currentPersistentHistoryTokenFromStores:]` builds a
token from the change tokens the stores give, and the stores of this release give
none, so it answers `nil`.

## Where the newest Core Data differs

The host's Core Data lets a delete request take the result types 2 and 6, and writes
the result type of the description as its name. iOS 12 does neither, and the package
follows iOS 12; the differential test leaves those two out of the comparison and
checks the words of the iOS 12 description instead.
