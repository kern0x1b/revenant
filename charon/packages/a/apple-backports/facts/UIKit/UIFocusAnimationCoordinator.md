# UIFocusAnimationCoordinator, iOS 9

Introduced in iOS 9.0 for tvOS-style focus, and reachable on iOS through
`-[UICollectionViewDelegate collectionView:didUpdateFocusInContext:withAnimationCoordinator:]` and its siblings. An
application is handed a coordinator during a focus update and adds animations that run in the same context as the
system's own, with a completion after the system's animation ends.

Source: the SDK 16.4 header for the contract, and the release: iOS 6 has no focus engine at all - `UIFocusSystem`,
`UIFocusEnvironment`, the focus notifications and `UIFocusUpdateContext` are all recorded `absent` in the registry,
and nothing in the release or in this package ever begins a focus update.

## What is carried and why it is not inert

The class is carried and `-addCoordinatedAnimations:completion:` runs the animations it is given and then the
completion, both at once, on the calling thread. That is deliberate and it is the opposite of inert: the whole
point of the method is to run the application's blocks, and an implementation that did nothing would **swallow
them** - the application's own view changes and its completion would never happen, which is a silent difference of
the worst kind. Running them plainly is the truthful reading of "run in the same animation context as the main
animation" where there is no main animation: if the caller is inside a `UIView` animation block the changes
animate with it, and otherwise they take effect at once.

`nil` for either block is allowed, as the header says ("it is perfectly legitimate to only specify a completion
block"), and passing `nil` for both does nothing and does not raise.

## What no application will see unless it asks for it

Nothing in the release hands a coordinator out, because there is no focus engine to begin an update with. The
callbacks that would deliver one - the focus delegate methods of a collection view, a table view and a view
controller - are never sent. So the class is reachable only when an application makes one itself, which is what an
application doing its own animation bookkeeping around a focus API does. The two methods iOS 11 added,
`-addCoordinatedFocusingAnimations:completion:` and `-addCoordinatedUnfocusingAnimations:completion:`, are
recorded `absent` and stay that way: they take a context describing the system's own animation, and there is no
system animation here to describe.

## What the device run shows

`device/focuscontentsize.m` on an emulated iOS 6.0 (iPhone3,1, 10A403): the class is there and comes from
`libUIKitBackports.dylib`, the animations run and then the completion, in that order and before the call returns,
a completion given alone is run, and both blocks nil is quiet.
