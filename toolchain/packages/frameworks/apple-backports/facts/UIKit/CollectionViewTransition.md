# The collection view layout transition

What iOS 7 gave a collection view that iOS 6.1.3 does not have: a way to move from one layout to
another under a progress the caller drives, instead of only swapping the layout outright.

## Why the port carries it

The release's `UICollectionView` lays out through `invalidateLayoutWithContext:`, which
`UICollectionViewLayout+Invalidation7.m` already supplies, but it has no transition at all: it
never builds a `UICollectionViewTransitionLayout`, never moves a progress, and never asks a layout
the transition questions. So on the release all of the following is unreachable however an
application writes it, which is the whole of this group:

- `-[UICollectionViewLayout targetContentOffsetForProposedContentOffset:]`
- `-[UICollectionViewLayout prepareForTransitionToLayout:]`, `prepareForTransitionFromLayout:`, `finalizeLayoutTransition`
- `-[UICollectionViewLayout indexPathsTo{Delete,Insert}For{SupplementaryView,DecorationView}OfKind:]`
- `-[UICollectionView startInteractiveTransitionToCollectionViewLayout:completion:]`, `finishInteractiveTransition`,
  `cancelInteractiveTransition`, `setCollectionViewLayout:animated:completion:`
- `UICollectionViewTransitionLayout` and its two animated-key messages

## What each answer is, and where it was measured

`tests/backports/host/collectiontransition` records what the host's own UIKit answers for every
case of `tests/backports/device/collectiontransition-cases.m` under Mac Catalyst (macOS 27.0) and
writes them where the device test reads them, so the port is held to the same answers. The cases
run with no collection view and no window, which is what makes them runnable on both sides.

Measured, and matched:

- `targetContentOffsetForProposedContentOffset:` gives back the offset it was given, `{11, 22}` and
  `{0, 0}`. A layout that wants to come to rest elsewhere overrides it.
- The two prepare messages and the finalize message are asked of the base layout and change
  nothing: they are the subclass's to answer, and on the host the base layout's answers leave the
  content size as it was.
- The four element questions name no element on the base layout: each answers an **empty array**,
  not nil, for a section header, a section footer and a decoration kind.
- `UICollectionViewTransitionLayout` keeps the two layouts it was given, and its progress starts at 0.
- **The progress is not bounded.** The host holds 2 when 2 is set and -1 when -1 is set, and
  `finalizeLayoutTransition` leaves the progress where the caller left it. The port was written to
  clamp to 0...1 and to reset the progress on finalize; the host answers told it otherwise and it
  was changed to hold the number as given and to leave it alone. This is the one place where the
  differential changed the implementation.

## The driven transition, and what is not verified

`tests/backports/device/collectiontransition.m` drives the real thing: a live collection view in a
window, a transition to a second flow layout with a different item size, the cell's frame at the
start, half way and the end, `finishInteractiveTransition` settling on the layout it went to,
`cancelInteractiveTransition` settling back on the one it came from, and what each completion block
is handed.

**This part has not been run.** It needs hardware, not the host and not the emulator: the cases
that need a window cannot run in a plain Catalyst binary, and a UIKit app started by `xmake
emulate` never reaches `application:didFinishLaunchingWithOptions:` (the `emulate-port` skill), so
the frames the emulator draws are SpringBoard's. Until that test is green on a device the driven
half of this group is **device-unverified**: the hooks above are measured against the host, and the
progress, the settling and the completions are written to the 26.2 header but not yet seen running
on 6.1.3.

The progress is moved from a 60 Hz timer rather than from inside a `UIView` animation block,
because it is the layout that reads it: the release animates no layout property, so a block that
only set the number would leave every cell where it was. `UICollectionView+InteractiveMovement.m`
drives its movement the same way.

**The pacing is the port's own and is not a claim about Apple's.** No API here returns a duration
and none of these methods takes one, so the 0.35 s a transition runs for and the 1/60 s the
progress is moved at are this port's choices, written down so nobody reads them as measured. What
*is* measured is every answer an application can see: the hooks' return values and the progress
semantics, in the table above. If a device run later shows Apple's own pacing differing, the two
constants are where it goes.

A layout asked for while a transition is still running is neither dropped nor put in place under
the running one. Each such change joins the ones already waiting, **in the order it was asked for**,
and each is installed as the transition settles, with its own caller's block handed a `finished` only
once its own layout is the one the view is holding. One field would have been enough to be wrong
here: a second caller overwrites the first, the first layout is never installed, and the first
block is still handed `finished = YES` while the view holds the second layout. That was a real
defect in the first version of this, caught in review; the queue is the fix.

**Not measured, and not claimed:** whether a flow layout in a *live* collection view answers the four
element questions with an empty array too. An earlier note here said so on the strength of an ad-hoc
probe that nothing in the tree can re-run and that ended in a crash, so the sentence is gone rather
than kept on a weak oracle. The base layout's answer is the one measured and held above.

## The reordering a layout does while an item is moved (iOS 9)

The release's collection view reorders an item only through `UICollectionView+InteractiveMovement.m`,
which the tree has carried for a while, and that path asked the data source and the delegate and
nothing else. Everything a *layout* is asked during a reorder was missing, so a layout that
arranges its own items had no say in a reorder at all:

- `-[UICollectionViewLayout targetIndexPathForInteractivelyMovingItem:withPosition:]`
- `-[UICollectionViewLayout layoutAttributesForInteractivelyMovingItemAtIndexPath:withTargetPosition:]`
- `-[UICollectionViewLayout invalidationContextForInteractivelyMovingItems:...]`
- `-[UICollectionViewLayout invalidationContextForEndingInteractiveMovementOfItemsToFinalIndexPaths:...]`
- the three reordering answers on the invalidation context: `previousIndexPathsForInteractively-
  MovingItems`, `targetIndexPathsForInteractivelyMovingItems`, `interactiveMovementTarget`

`tests/backports/host/collectionmovement` records the host's answers for all of it, for the base
layout and a flow layout both, windowless, and the device test holds the port to them. Measured:

- **The base layout gives the index path back unchanged** and has **no attributes at all** for a
  moving item: `layoutAttributesForInteractivelyMovingItemAtIndexPath:withTargetPosition:` answers
  **nil** on `UICollectionViewLayout`. This was written first as a cell placed at the point on the
  base class too, and the host said nil; the placement now lives on `UICollectionViewFlowLayout`,
  which is the class that has attributes to place. That is the whole difference between the two
  rows in the table above and it is why they are not one answer.
- A flow layout places the item as a cell with **no size** whose centre is the point it is being
  dragged to and whose `zIndex` is `NSIntegerMax`, so the item follows the finger and is never
  behind another element. The size is the point's own, not the cell's laid out size: the cell is
  being carried, not placed in the grid.
- Both contexts are of the layout's own `invalidationContextClass` — a flow layout's is
  `UICollectionViewFlowLayoutInvalidationContext`, so the flow-only answers come with it and answer
  what the host answers (`invalidateFlowLayoutDelegateMetrics` 1) — and both carry the index paths
  verbatim. A movement in progress carries the target position as its point; a movement that has
  ended carries **the origin**, because it is at no point in particular. Neither invalidates an
  item index path of its own and neither says invalidate everything.
- A context built for a bounds change, which is not a movement, carries none of the three.

These are wired into the movement the tree already had, not left as an API nothing calls: a reorder
now invalidates the layout through the context the layout itself makes for a movement in progress,
the movement's end invalidates through the one that ends it, and the proposal a finger makes goes
through the layout's own question first, with the delegate asked after it so it keeps the last word.
The base layout's answer to that question is the index path it was asked about, which is no opinion
at all, so the item stays where the finger is over it unless a layout says otherwise.

**The reordering inside a live collection view is device-unverified**, for the reason above.

## The two completion blocks are not the same block

`UICollectionViewLayoutInteractiveTransitionCompletion` is `void (^)(BOOL completed, BOOL finished)`
in the header of SDK 26.2, so the interactive transition is handed two flags: a cancelled
transition hands a completion that did **not** complete, and both a completed and a cancelled one
hand a finished, because the animation did run to its end either way.
`setCollectionViewLayout:animated:completion:` takes a plain `void (^)(BOOL finished)` instead, and
is wrapped into the two-argument form when it is run as a transition. Getting this backwards
would hand the caller's block a garbage flag, which is why it is written down here.
