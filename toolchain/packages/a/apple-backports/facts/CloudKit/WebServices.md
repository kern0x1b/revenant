# The CloudKit Web Services transport

## The four pieces

`CharonCloudKitErrors.m`, `CharonCloudKitPaths.m` and `CharonCloudKitTransport.m`, over
`CharonCloudKit.h`. They are helpers and not API: no class or symbol in them is in the registry.

1. **The errors.** Every code `CKErrorCode` names, built from the payload's own `serverErrorCode`
   (the strings the service sends, mapped to the codes the header lists), `reason` or `errorMessage`,
   with the per-item failures under `CKPartialErrorsByItemIDKey`, the retry delay under
   `CKErrorRetryAfterKey`, the three records a save conflict carries under their keys, and the reset
   flag under `CKErrorUserDidResetEncryptedDataKey`. Two codes are the header's for a client that
   never got there: `CKErrorNetworkUnavailable` and `CKErrorNetworkFailure`, the first for a request
   that never left and the second for one the network refused.
2. **The paths.** The database root is `database/1/<container>/<environment>/<scope>`, with 1 the
   development environment and 2 production, and the scope `private`, `public`, `shared` or
   `zones/<name>`. A zone or a record name is percent-encoded.
3. **The field mapping.** A field is a string, a number, a date, data, a reference, an asset, a
   location, or an array or a dictionary of those; each has its own wire form and the mapping is
   written once and used both ways.
4. **The connection.** `NSURLConnection`, the release's own, in `CharonCloudKitTransport.m`.

## Why NSURLConnection and not NSURLSession

A CloudKit client is very often a daemon - an extension, a background agent, a sync process - and a
library that can only answer over `NSURLSession` drags libFoundationBackports' whole session stack,
its operation queue and its delegate dispatch, into a process that wanted a container. One
CloudKit request is one connection, and the release has the thing that is one.

## The contract, and the two refusals

A 2xx answer with a JSON body is handed back decoded; a 2xx one without is handed back nil; a 4xx or
5xx is a `CKError` from the payload; a connection that never completed is one of the two network
codes. The completion is called exactly once and never on the caller's thread, which is what the
`finished` flag on the delegate is for: a connection that fails after its delegate was told and a
delegate that is told after a failure both reach it, and only the first gets through.

Refused before a connection is made:

- **No container identifier answers `CKErrorBadContainer` (5).** A process with no
  `com.apple.developer.icloud-container-identifiers` entitlement is in this state, and the host's own
  CloudKit answers it by raising `containerIdentifier can not be nil` - measured. Raising takes the
  process down and leaves a caller nothing; the code the header names for an un-provisioned container
  does leave it something.
- **No token to send with answers `CKErrorNotAuthenticated` (9)**, the code the header documents for
  "writing without being logged in, no user record". This is the brief's case: without an account,
  the error Apple documents.

## The token

`CharonCKCredentials` takes either a developer token the application minted, which needs no
cryptography, or the container's web services authentication key from its bundle - the `.p8`, or the
PEM under the Info.plist key CloudKit's own tooling writes. The key is used to sign the JWT of
CloudKit's own format: the header, the three-member payload (`iss`, `iat`, `exp`, `sub`, all the
team), and the ES256 signature, which is charon@micro-ecc's through `CharonCKSignES256`. A token is
cached until shortly before the hour it is good for.

A key with no team answers `CKErrorBadContainer` rather than a token: the token's own claims name the
team and there is nowhere else to read it from.

## The query document

CloudKit's query grammar is not `NSPredicate`, and this is the one translation with no mechanical
answer. A comparison is an `operator` of `equals`, `notEquals`, `lessThan`, `lessThanOrEquals`,
`greaterThan`, `greaterThanOrEquals`, `like`, `beginsWith` or `contains` over a `field`, a `comparator`
and a `value`; a compound is a `type` of `and` or `or` over `subs`.

What the grammar has no form for, and what is therefore **refused with `CKErrorInvalidArguments`
(12)** - the code the header names for a malformed predicate - rather than approximated:

| the predicate | why it is refused |
| --- | --- |
| a NOT | the complement of a query is not a query, and dropping the negation would send a different one |
| `IN` and `BETWEEN` | no operator for either; CloudKit's own `CKQuery` does not accept them either |
| a compound comparison, `x < 1 < y` | the right-hand side is a predicate and the grammar takes a literal |
| a quantified one, `ANY x.y = 1` | a subquery, and the web services interface has none |
| a function on either side | only a field and a literal have a form |
| a bare `TRUEPREDICATE` and friends | no field, so nothing to filter on - the service's own answer for a query with no filter is a filter that matches everything, and the port sends the whole zone's records rather than inventing a field |

A key path is taken apart on its dots, because a compound key such as `location.latitude` is written
as a chain in the grammar, and a key with an empty component is refused rather than sent.

## What is not here

`CKContainer` and `CKDatabase`, the twenty operation classes, `CKShare` and `CKSyncEngine` are the
next pieces, on top of these four. Nothing in this file is reached by an application yet, which is why
the library carries no class that calls into it.
