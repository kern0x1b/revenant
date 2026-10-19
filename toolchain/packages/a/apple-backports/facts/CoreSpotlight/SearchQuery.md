# CSSearchQuery: the query the port answers from its own index

`CSSearchQuery` searches the default index. The port's search reads the store its `CSSearchableIndex` writes
(`RevenantSpotlightDefaultItems`, the store named `__defaultIndex`), in `CoreSpotlight/CSSearchQuery.m`.

The answers are the host's, measured with `tests/backports/host/corespotlight-query`: one program, built once against the
host's framework and once against the port's sources, whose output must be the same line for line. The run has 25 lines and
they are identical. The port side is built from a copy in which only the store root is changed (the root under
`/var/mobile` is not writable on the host). The planted control (`!=` answers like `==`) differs on 2 lines, so the
comparison does tell a wrong answer apart.

## The grammar, as measured

- `attribute == "value"` and `attribute != "value"` compare the whole string, case-sensitively: `title == "revenant alpha q"`
  does not match `Revenant Alpha Q`.
- `*` in the quoted value matches any run of characters: prefix (`Revenant*Q`), substring (`*Alpha*`), suffix (`*Q`), and `*`
  alone. `?` is an ordinary character: `Gamm? Q` matches nothing.
- `&&` binds tighter than `||`: `a || b && c` answers `a` together with `b && c`. Parentheses group: `(a || b) && c`.
- An attribute the item does not have, or one the attribute set does not declare, matches nothing and is not an error
  (`nosuchattr == "x"`).
- Free text (`Alpha`), the word operator `contains`, and an unfinished comparison (`title ==`) are invalid: the completion
  handler gets `CSSearchQueryErrorDomain` code -2002 (`CSSearchQueryErrorCodeInvalidQuery`).
- A quoted value that is never closed (`title == "Alpha`) is not an error: the value runs to the end of the query.
- The empty query `""` is the one query whose answer is every item in the index. It is in the probe, not in the 25-line
  differential, which has no index of its own to compare against.

Not measured, and so not claimed: `!=` on an item that lacks the attribute; whitespace-only queries; escapes inside a
quoted value; unquoted values; a single `=`; attribute names other than the ones the differential uses.

## Where the class is carried

The query reads the port's default store, `RevenantSpotlightDefaultItems`, which `CSSearchableIndex.o` defines. Measured with
`tools/symbol-first-release.lua` on the armv7 ladder: the release's own `CSSearchableIndex` is first exported at 9.0, so from
9.0 the port's index is left out and its store is not there; the release's own `CSSearchQuery` is first exported at 10.0.1,
the first held rung that exports it. The release has no query over the index it keeps from 9.0 on, so in the 9.0 band and
below 10.0.1 the query is owed, and the registry carries the class below 9.0 only (minimum 6.0, maximum 9.0). From 10.0.1
the release has the class itself.

## What a result carries

- A result holds the attributes its `attributes` list names and nothing else: with `@[@"title"]` the title is there and the
  display name is nil; with `nil` or `@[]` no attribute is there. The identifier and domain are always there.
- The found handler is called once with all the matches, when there is at least one (one batch). With no match it is not
  called at all (no batch). `foundItemCount`, read in the completion handler, is the number of matches.
- The order results arrive in is not measured. The differential prints the result with the lowest identifier, and the port
  returns results in identifier order.
- `contentType` is not fetched unless the attribute list names it.

## The attributes the port backs

The port's attribute set declares the General properties: `displayName`, `title`, `contentType`, `keywords`, `path`,
`version`, the container properties, and the rest listed in `CoreSpotlight/CSSearchableItemAttributeSet.m`. The Documents
category (`contentDescription` among it) is not implemented. A query on `contentDescription` therefore matches nothing on
the port, and the host's answer for it is not compared: the differential uses `displayName` in its place.

## Owed

- `cancel`: `isCancelled` becomes true, and a query that has not delivered reports `CSSearchQueryErrorCodeCancelled`
  (-2003). The host's timing of a cancel is not measured.
- `filterQueries` and `keyboardLanguage` of the query context are ignored. The host's behaviour is not measured.
- `protectionClasses` is stored and not used. Starting a query twice is not measured.
- Items of other applications: the host's default index holds them, and the port answers from the store of its own process.
- The error's user info is nil on the port. The host's is not measured.
- The other `CSSearchQueryErrorCode` values (-2000 unknown, -2001 index unreachable) are never produced by the port; the host's
  conditions for them are not measured.
