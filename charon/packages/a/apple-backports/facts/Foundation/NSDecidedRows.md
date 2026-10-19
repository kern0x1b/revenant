# Fourteen rows of the N-Z Foundation slice, decided rather than carried

Each of these has a registry entry saying why, and the reason is the measurement, not the arrival
date. What they have in common is that the state the API names lives inside a structure the release
keeps to itself.

## The undo manager's stack (4 rows)

`undoCount`, `redoCount` and the two `...ActionUserInfoValueForKey:` methods are all a view of the
release's own undo and redo stacks. `NSUndoManager` on 6.1.3 can say whether it can undo and what the
next action is called, and nothing else: there is no entry point that reports a size, and none that
reaches the per-action user info. The host's own answers are group counts (measured: a fresh
`NSUndoManager` answers 0, one registration inside an open grouping still answers 0, and the group
answers 1 once it is closed) -- which is a count of the *release's* groups, not of anything the port
could reproduce without owning the class outright.

## The shared observers (1 row)

`+[NSObject setSharedObservers:]` takes an `NSKeyValueSharedObservers`, a Foundation class that no SDK
header declares and that the release's `libobjc` knows nothing of. Carrying the method would mean
inventing the type it takes.

## A correction result (2 rows)

`+correctionCheckingResultWithRange:replacementString:alternativeStrings:` needs a result whose type is
a correction, and the release has no public way to make one. Its own spellings --
`-initWithRange:`, `+replacementCheckingResultWithRange:replacementString:` -- are in the 6.1.3 binary
(measured in the cache's selector table) but in no header, and this port does not build on a private
selector. `-alternativeStrings` then has nothing to read, which is the same wall from the other side.

## The progress subscriber (1 row)

`+addSubscriberForFileURL:withPublishingHandler:` is marked `API_UNAVAILABLE(ios, watchos, tvos)` in the
SDK's own header: publishing a progress to other processes is a macOS mechanism, and no iOS
application can name the method. The compiler refuses the call on iOS, which is the truth.

## The XPC table and the coder's connection (3 rows)

`xpc_type_t` is the type the XPC framework introduced in iOS 8. The release's `NSXPCInterface` keeps its
own table of types where no 6.1.3 entry point reaches it, so neither the setter nor the getter can be
answered; and a coder's `connection` belongs to the system's own XPC machinery, which creates the
coder and keeps the connection in an ivar no public API returns.

## The user activity's store and its continuation (3 rows)

`+deleteAllSavedUserActivitiesWithCompletionHandler:` would delete the system's Handoff store, which
6.1.3 has no entry point to list or clear. The two delegate methods are what a continuation calls:
there is no `-continueUserActivity:` to be called from, and no
`-becomeCurrentWithInputStream:outputStream:` to hand out a stream, so they have no caller.

## Fourteen rows, and one that is not

`+[NSOrthography defaultOrthographyForLanguage:]` was in this file as a decision: 6.1.3's selector table
carries neither it nor `orthographyWithLanguage:`, so there seemed to be no way to name a language's
script. That was a wall that was not there -- the release's own `libicucore` exports
`uloc_addLikelySubtags`, which is the same CLDR likely-subtags data, and the row is carried in
`NSOrthographyDefault.md`. A selector table says which selectors a release has; it does not say what
the release can compute, and here it could.
