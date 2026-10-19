# CSSearchableIndex's delegate and external-provider fetch

Three surfaces of `CSSearchableIndex` are carried here, in `CoreSpotlight/CSSearchableIndex.m`: the `indexDelegate`
property, the `CSSearchableIndexDelegate` protocol it is typed by, and `fetchDataForBundleIdentifier:itemIdentifier:
contentType:completionHandler:`. The answers are the host's, measured with `tests/backports/host/corespotlight-index`: one
program, built once against the macOS CoreSpotlight framework and once against the port's sources, whose output must be the
same line for line after object addresses are replaced. The run has 6 lines, and a planted control (the fetch answers
CSIndexErrorCodeUnknownError instead of CSIndexErrorCodeRemoteConnectionError) differs from the host on 2 lines.

The surface is the rendered header of CSSearchableIndex.h from the 26.2 SDK. The release's own declarations are
`indexDelegate` (iOS 9.0, weak), the protocol (iOS 9.0), and the external-provider category, which the SDK declares for macOS
13 only: the iOS SDK says nothing about it, so the iOS introduction of the method is not shown by any header here.

## indexDelegate

- A new index, from `defaultSearchableIndex` or `initWithName:`, has no delegate (nil), measured.
- What is set reads back as the same object, measured.
- The reference is weak: once the delegate is freed, the property reads nil, measured. The port declares the same
  ownership (`@synthesize` of a weak property), so a delegate is never kept alive by its index.

## CSSearchableIndexDelegate

The protocol's two required methods are the release's reindex requests, and its optional methods are the data callbacks
(`dataForSearchableIndex:...`, `fileURLForSearchableIndex:...`) and the throttle notices. The port declares the protocol as
the header does, and never messages its delegate: nothing in this port's runtime loses the journal the way the release's
remote process can, so there is no reindex to request. The measured program sets a delegate that implements the reindex and
data methods and then asks for data of a bundle the index does not hold: the release never calls `dataForSearchableIndex:`
for that request (the count is 0), so the port's answer does not need that callback either.

## fetchDataForBundleIdentifier:itemIdentifier:contentType:completionHandler:

- The answer is asynchronous: the call returns before the completion handler runs, and the handler runs on a background
  queue, not the main thread, measured. The port dispatches its handler on the default-priority global queue.
- For a bundle the index holds nothing for (measured with the identifier `com.example.nothere` and an item that is not in the
  index), the release answers no data and an error in `CSIndexErrorDomain` with code -1003, which the SDK names
  CSIndexErrorCodeRemoteConnectionError. The error carries no user info, measured. The port gives the same domain, code and
  absence of user info.
- The answer is the same with an index delegate set, measured.

The port has no external provider, so it never has data for another application's item, and it takes that same answer for
every request. This is the measured answer for a request the release cannot satisfy, which is the only kind the port can
meet. The release's answer for a bundle that does hold an item of the caller's has not been run, so a request for one is
not claimed to match.

The -1003 that `CoreSpotlight.md` gives as the code of a failed remote connection is the same code: the fetch answer
is measured here, where the write-failure code (-1000) is still reasoned, not measured.

## What is not here

`fileURLForSearchableIndex:...`, `searchableItemsForIdentifiers:...` and `searchableItemsDidUpdate:` (iOS 18.4) are declared
in the protocol, and the port does not implement them; the protocol row says so. Other iOS 17 and 18 batching variants of
`CSSearchableIndex` are outside this family.
