# Asynchronous fetch, iOS 8.0

`-[NSManagedObjectContext executeRequest:error:]` takes an `NSAsynchronousFetchRequest`: it answers an
`NSAsynchronousFetchResult` at once and the fetch is delivered to the request's block later.

Source: CoreData of the arm64 shared cache of iOS 12.0 (`-[NSAsynchronousFetchRequest initWithFetchRequest:completionBlock:]`,
`-requestType`, `-description`, `-[NSManagedObjectContext _executeAsynchronousFetchRequest:]` and its blocks, the classes
of the two results); the host's Core Data, run next to the port for every case below (`tests/backports/host/asyncfetch`,
172 checks, repeated to see that the timing does not matter); an iPad 2 running 6.1.3 (`tests/backports/device/coredata8.m`).

## The request

- Made with a fetch request, which may be `nil`, and a block, which may be `nil` and is copied. The request type is 1,
  the type of a fetch request. It takes the affected stores of the fetch request. The estimated number of results starts at 0.
- The description is the object's own followed by ` with fetch request ` and the fetch request's.

## Executing it

- The entity is found by the fetch request's entity name. A fetch request without one raises `NSInvalidArgumentException`,
  "_executeAsynchronousFetchRequest: A fetch request must have an entity."; a context of the confinement type raises
  "NSConfinementConcurrencyType context %@ cannot support asynchronous fetch request %@." (checked in that order).
- A **count** fetch is not asynchronous: it answers an array of one number at once, calls no block, and answers `nil`
  when the count fails.
- Otherwise the result is answered at once, before the fetch is delivered, even when the caller is on the context's queue.
  The block is called once with the same result, on the context's queue (the main thread for a main queue context), after
  the final result and the error are set. A fetch the store raises on is not delivered and the block is not called; iOS 12
  logs it. A fetch that fails with an error and not an exception is delivered by the port with the error and no final result; the release's own handling of that case was not read to the end and the store gives no way to make it happen on the host, so it is the port's choice.
- The final result is an array in the order of the fetch, of faults for objects (objects the context already holds come as
  they are), of object IDs or of dictionaries. A pending insert, change or delete of the context is seen when the fetch
  asks for pending changes, which is its default, and not when it does not.
- With a **current progress** the result has a progress that is its child: kind "managed objects", cancellable, its total
  the estimate when that is above 0 and −1 (indeterminate) otherwise, and at delivery its total and completed the size of the
  result. Without one the result has no progress.
- `-cancel` of the result, or cancelling its progress, before the fetch is delivered gives an empty final result, no error,
  and the block is still called once; the progress of a cancelled fetch ends at 0 of 0. Cancelling after the delivery does
  nothing.

## Where iOS 6 answers differently

- The fetch does not run in the store's own queue as iOS 12's does: it runs in a private context of its own on a background
  queue, and the objects are made in the calling context on its queue when it is delivered. A fetch that has to see pending
  changes of the context runs on the context's queue.
- `fractionCompleted` of the parent counts the finished child; `completedUnitCount` of the parent does not on iOS 6
  (see the note on `NSProgress`).
