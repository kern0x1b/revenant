# CSIndexErrorCode and CSIndexError

`CSIndexErrorCode` is the enum of the error domain `CSIndexErrorDomain`. `CSIndexError` is the Swift struct the compiler
derives from it (`swift-struct` in `spec/CoreSpotlight/swift.tsv`, available from iOS 9.0), wrapping an `NSError`.

The values are the host framework's, read from its `CoreSpotlight.bridgesupport` (the same values in the arm64e file):

| name | value |
|---|---|
| `CSIndexErrorCodeUnknownError` | -1 |
| `CSIndexErrorCodeIndexUnavailableError` | -1000 |
| `CSIndexErrorCodeInvalidItemError` | -1001 |
| `CSIndexErrorCodeInvalidClientStateError` | -1002 |
| `CSIndexErrorCodeRemoteConnectionError` | -1003 |
| `CSIndexErrorCodeQuotaExceeded` | -1004 |
| `CSIndexErrorCodeIndexingUnsupported` | -1005 |
| `CSIndexErrorCodeMismatchedClientState` | -1006 |

`CSSearchQueryErrorCode` is the enum of `CSSearchQueryErrorDomain`, with the same source: `CSSearchQueryErrorCodeUnknown`
-2000, `CSSearchQueryErrorCodeIndexUnreachable` -2001, `CSSearchQueryErrorCodeInvalidQuery` -2002, and
`CSSearchQueryErrorCodeCancelled` -2003. The port produces -2002 and -2003 (see `SearchQuery.md`).

The domain's string is `CSSearchQueryErrorDomain`: the host answers that domain for an invalid query, measured in
`corespotlight-query` (`CSSearchQueryErrorDomain/-2002`, identical on the port's side). The generator renders the constant
(`CoreSpotlightConstants100.m`, introduced 10.0), so the port does not define it by hand, and it has no registry row of its
own: the generator's row names it.

The values the port produces in `CSIndexErrorDomain`: -1003 for a fetch of an unknown bundle (measured on the host in
`IndexDelegate.md`). The write-failure code -1000 is reasoned, not measured, and is recorded there as such.

The meanings of -1001 to -1006 are not measured, and the port does not produce them: they are listed so the enum is complete.

`CSIndexError` has no runtime of its own: a Swift value that wraps an `NSError` in `CSIndexErrorDomain`, so it is correct
exactly where the enum is.
