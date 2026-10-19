# The interactions of a view, iOS 11.0

Introduced in iOS 11.0: a view holds a list of objects conforming to
`UIInteraction`, each of which is told when it moves between views. Apple's own
interactions of that release - dragging, dropping, spring loading - rest on
system services this release does not run and are `absent`; the list itself is
bookkeeping a view can do, and an application that writes its own interaction
gets it.

Source: UIKit of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372),
`-[UIView addInteraction:]` at `0x18a294394`, `-removeInteraction:` at
`0x18a29459c`, `-interactions` at `0x18a2946e4`, `-setInteractions:` at
`0x18a294748`, `-_canAddInteraction:` at `0x18a2949fc`, and the pair of
callbacks sent from the helper at `0x18a29452c`; the current behaviour from the
differential test against the host's UIKit
(`tests/backports/host/interactions`).

## What the list is

The interactions live in one mutable array, made the first time one is added.
`-interactions` hands out `[NSArray arrayWithArray:]` of it - a copy, so a
caller cannot reach into the view's own list - and a view that has never held
one answers an empty array, never `nil`.

Adding sends the interaction `-willMoveToView:` and then `-didMoveToView:`,
both with the view it is moving to, back to back, and the interaction is the one
that stores the view: the protocol's `view` is read-only and the release never
writes it. Removing sends the same pair with `nil`. The order inside the array
is the order things were added, and removal finds the interaction by identity
(`-indexOfObjectIdenticalTo:`), not by `-isEqual:`, so two interactions that
consider themselves equal are still two entries.

Adding an interaction that already belongs to another view takes it off that
view first, with the `nil` pair the removal sends, and then adds it here with
the pair for this view. Removing an interaction the view does not hold does
nothing and says nothing. `-setInteractions:` copies the array it is given,
removes every interaction the view holds now, then adds each of the new ones in
order, so every callback fires along the way.

## Where the releases differ, and which one the port follows

Three of the four entry points changed after iOS 11, and the port carries the
newer behaviour, as this package always does.

| case | iOS 11.0 | the current implementation |
|---|---|---|
| `-addInteraction:nil` | returns, quietly | raises `NSInternalInconsistencyException`, `Invalid parameter not satisfying: interaction != nil` |
| `-removeInteraction:nil` | returns, quietly | raises the same |
| `-setInteractions:nil` | returns, quietly | raises `NSInternalInconsistencyException`, `Invalid parameter not satisfying: interactions` |
| adding what this view already holds | takes it off itself and adds it again, so the callbacks fire twice | returns and says nothing |

The port raises the same three exceptions, with those reasons, and returns
without a word when the interaction is already on this view. Both were measured
on the host rather than guessed: the test records the name and the reason of
whatever is raised and compares them.

## What is left out

`-_canAddInteraction:` refuses one case: a spring-loaded interaction on a view
that does not support spring loading. Both the interaction and the protocol it
tests for belong to API this release does not have, so there is nothing for the
check to refuse and the port does not carry it. Every interaction an
application can build here is one the view can hold.
