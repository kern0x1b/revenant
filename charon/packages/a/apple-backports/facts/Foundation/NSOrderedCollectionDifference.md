# NSOrderedCollectionChange and NSOrderedCollectionDifference, iOS 13.0

Introduced in iOS 13.0: the value a comparison of two ordered collections makes - one change per inserted or removed element - the
difference that holds them, and the members of `NSArray`, `NSMutableArray`, `NSOrderedSet` and `NSMutableOrderedSet` that make a difference
and apply one. iOS 6 has none of it.

Source: the host's own Foundation (macOS 27.0), asked for every answer below and held against the port by the `orderedcollections` group of
`tests/backports/host/uikit2`, which puts the port beside the system's classes and compares 320000 differences of random arrays and ordered sets
(with every option, with an equivalence test, and the calls the test received), 60000 differences built from random changes and index sets, and
the exceptions of 190 fixed cases, none differing. The header of SDK 16.4 gives the signatures.

## The difference of two arrays

`-differenceFromArray:` and its two longer forms answer what turns the argument into the receiver: removals at indexes of the argument,
insertions at indexes of the receiver. The changes are the shortest edit script of the Myers greedy algorithm, walked forward, taking an
insertion in preference to a removal when the paths tie, with no trimming of a common prefix or suffix - written from the answers, since
which of several shortest scripts is the answer decides every index. Trimming a common prefix and suffix disagrees with the system on about one random array in seven, and preferring a removal on one in six. Two elements are equal by `isEqual:`, or by the block, which is called as `block(element of the argument, element of the receiver)`
and in the same order and number as the system calls it.

- `NSOrderedCollectionDifferenceCalculationOmitInsertedObjects` and `...OmitRemovedObjects` leave the object out of the changes of that
  kind; unknown bits are ignored.
- `NSOrderedCollectionDifferenceCalculationInferMoves` gives an insertion and a removal each other's index as `associatedIndex` when the same
  object is removed once and inserted once, by `isEqual:` and `hash`, and only then: an object removed twice, or inserted twice, is never
  paired. The forms that take a block refuse the option with `NSInvalidArgumentException`, "Inferring moves is not supported when using a
  custom equivalence test"; the form with no block accepts it.
- A nil argument raises `NSInvalidArgumentException`, "Cannot diff nil parameter".

## The difference of two ordered sets

`-differenceFromOrderedSet:` and its form with options are not the array algorithm, and are not the shortest script: elements are unique, so the
system walks both sets with a cursor each. At equal elements both cursors move. At different ones it looks up where each cursor's element is in
the other set, at or after the other cursor: an element that is not there is removed (or inserted); when both are, the one whose match is
nearer the other cursor is skipped, and a tie removes the argument's element. What is left of either set at the end is removed or inserted. This
keeps fewer elements than the array algorithm does on a reordered set, and the port does the same, since an application that animates the
difference sees the indexes. The form with a block is the array algorithm on the arrays of the two sets.

## Applying a difference

`-arrayByApplyingDifference:` copies the receiver, removes the removal indexes, then inserts the insertions in ascending order, which is the order
in which a difference is enumerated (removals from the highest index down, then insertions from the lowest up). It answers nil, and nothing is
raised, when a removal index is past the end, an insertion index is past the end of what is left, or an insertion has no object. The removed
object is not compared with the element it removes. A nil difference answers a copy. `-orderedSetByApplyingDifference:` is the same on a set; an
insertion of an element the set already holds changes nothing. `-applyDifference:` on `NSMutableArray` and `NSMutableOrderedSet` is the same run
on the receiver itself and raises what the collection raises for a bad index or a nil object: `NSRangeException` or `NSInvalidArgumentException`,
with the text of the release's own collection.

## NSOrderedCollectionChange

`+changeWithObject:type:index:` is the same with an associated index of `NSNotFound`. A type other than insert or remove raises
`NSInvalidArgumentException`, "Invalid type for change", with `type` in the user info. `-init` raises `NSInternalInconsistencyException` whose reason
reads "Unavailable method init called on class NSException", as the system's does. Two changes are equal when their object (both nil, or
`isEqual:`), type, index and associated index are. `-debugDescription` reads `<NSOrderedCollectionChange: 0x...>(insertion of object <NSString: 0x...>
at index 1 associated with index 3)`, with the object and the association left out when there are none, and the object shown by class and address,
never by value. `-description` is the plain one, and the change neither copies nor archives.

## NSOrderedCollectionDifference

- `-insertions` and `-removals` are the changes in ascending order of index. Fast enumeration and `-differenceByTransformingChangesWithBlock:`
  (which builds a difference from what the block returns, in that order) walk the removals from the highest index down and then the insertions
  from the lowest up. `-hasChanges` is whether there are any. `-inverseDifference` turns every insertion into a removal and back, with the
  same indexes, objects and associated indexes, and so undoes the difference.
- `-initWithChanges:` takes a nil array as none. `-initWithInsertIndexes:insertedObjects:removeIndexes:removedObjects:additionalChanges:` is the
  designated one, and the object arrays may be nil, when the changes carry no object. Its exceptions, all `NSInvalidArgumentException`, in the
  order in which they are checked: "Count of inserted objects does not match count of inserted indexes" (and the same for removed); for each
  additional change, an index already there raises "Remove index duplicated between index set and additional changes parameters" for an
  **insertion** and "Insert index duplicated between ..." for a **removal** (the wording is crossed over in the system, and so here), with `index`
  in the user info; then, when an objects array was given, "Inserted objects array provided, but additional change omitted object", or when none
  was, "No inserted objects array provided, but additional changes included objects" (for removals, "Removed objects array provided, but additional
  change omitted object" and, in the singular, "No removed objects array provided, but additional change included object"). `-initWithChanges:`
  passes an empty objects array when any change of the kind has an object, so a mix of changes with and without objects raises the first of these.
- Associations must pair up: a removal's associated index must be an insertion whose associated index is that removal, and the other way
  round; otherwise "Inconsistent associations for moves". One case raises `NSInternalInconsistencyException`, "Unbalanced number of remove and
  insert changes with associations.", with `NSAssertFile` and `NSAssertLine` in the user info as an assertion leaves them: an insertion, met
  in the order the changes were given, that names a removal whose partner has not been met yet.
- Two differences are equal when their insertions and removals are, associated indexes included; the hash of an empty difference is 0.
- `-description` is `<NSOrderedCollectionDifference: 0x...>(3 insertions, 1 removal)`, singular for exactly one.
- `-debugDescription`, when every change has an object and every object is a string, is the changes as the lines of a normal `diff`: a header
  `2,4c2` or `5c4,5` (the old lines, `c`, the new lines), then `< removed` and `> inserted` lines, with `---` where a run of removals is followed by
  insertions. A run of removals whose next removal is at most one line past it, or of insertions whose next is at most one past it, is one
  hunk, and a removal one line past an insertion joins it, so that a hunk may hold a kept line; the header numbers the removals by old line and
  the insertions by new line, and a pure removal or insertion is given the line the other side is at. Anything else - no changes, an object that is
  not a string, a change without an object - reads as the description, a space, and the changes in enumeration order, one per line behind a tab
  inside parentheses, `()` when there are none.

## Where the port departs

- `-hash` values differ from the system's; they agree with `-isEqual:`, which is all a hash is asked for.
- The exceptions `applyDifference:` raises from the collection carry the text of the collection of the release, not of the host.
- `NSNotFound` is 0x7fffffff on the 32-bit release, and shows so where an index of it is printed.
- The system crashes on a nil equivalence test; the port raises `NSInvalidArgumentException`, "Equivalence test is nil".
- The Myers trace is kept for the whole run, so memory grows with the square of the number of changes; a difference of two unrelated arrays of
  several thousand elements takes tens of megabytes.
