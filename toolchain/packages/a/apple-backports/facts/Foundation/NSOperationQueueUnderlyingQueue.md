# NSOperationQueue underlyingQueue, iOS 8.0

A queue with an underlying dispatch queue starts its operations on that queue, so an application can have them run
serially, on a queue of its own, or on the main queue, and can put other work on the same queue in order with them.

Source: the host's own Foundation, asked for every record of `tests/backports/device/underlying-cases.m` and held against
the port by `tests/backports/host/underlying/run.sh` (the system's `NSOperationQueue` and a queue over the port's scheduler,
in one process: twenty-one records, equal), and read again on an iPhone 4S and an iPad 2 running 6.1.3 by
`tests/backports/device/underlying.m`, whose operations go through the real `NSOperationQueue`.

## What the system does, and the port with it

- The property is nil until it is set, and can be set back to nil; `[NSOperationQueue mainQueue]` answers the main dispatch queue.
- A queue that has an operation - waiting, suspended or running - refuses a new underlying queue with
  `NSInvalidArgumentException`, "operation queue must be empty in order to change underlying dispatch queue"; one whose operations
  have all finished takes it. The default limit of a queue with an underlying queue is -1, and the limit and the suspension
  a queue had are kept.
- An operation starts on the underlying queue (`dispatch_get_specific` finds the key of the queue), and
  `[NSOperationQueue currentQueue]` inside it is the operation queue.
- The limit still counts: a serial underlying queue runs one at a time however large the limit, a concurrent one runs as many at
  a time as the limit says, or as many as it can when the limit is -1. An asynchronous operation holds its place until it is
  finished, not until `-start` returns.
- Ready operations start by priority, and one that waits for another starts when that has finished: high, then dependency, then
  normal, then low. A suspended queue starts nothing until it is resumed, and holds its operations meanwhile
  (`operationCount` and `operations` show them).
- An operation cancelled before it starts never runs its block, and is finished and cancelled all the same; the count drops.
- `-addOperations:waitUntilFinished:` waits for those operations; an operation that is finished cannot be added again
  (`NSInvalidArgumentException`, "operation is finished and cannot be enqueued").

## How the port does it

The release runs a queue on threads of its own, so the port takes the scheduling of such a queue into its own hands. A queue that is
given an underlying queue gets a scheduler (`CharonOperationScheduler`) that keeps the waiting and the running operations, watches
`isReady` and `isFinished` of each by key value observing, and starts an operation with `dispatch_async` onto the underlying
queue when it is ready, the limit lets it and the queue is not suspended. `-addOperation:`, `-addOperations:waitUntilFinished:`,
`-addOperationWithBlock:`, `-operations`, `-operationCount`, `-cancelAllOperations`, `-waitUntilAllOperationsAreFinished`, `-setSuspended:`,
`-setMaxConcurrentOperationCount:` and `+currentQueue` of the release are replaced on a release that has no underlying queue and
pass every call through to the release's own method for a queue that has none. Setting nil takes the scheduler away.

## What differs

- An operation is handed to the underlying queue as soon as it is ready and the limit allows, in priority order among the ready
  ones; a higher priority operation that becomes ready after that does not overtake operations already handed to a serial
  queue. The newest release also cannot take an operation back from a dispatch queue.
- The quality of service of the queue steers nothing on iOS 6 (see `NSQualityOfService.md`).
