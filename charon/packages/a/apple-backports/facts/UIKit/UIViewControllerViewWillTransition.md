# viewWillTransitionToSize:withTransitionCoordinator:, iOS 8

Introduced in iOS 8.0 with `UIContentContainer`: a view controller is told the size its view is about to have, with a transition coordinator, before the interface rotates or the container
resizes it. iOS 6 and 7 tell it about rotation only through `willRotateToInterfaceOrientation:duration:` and its two companions.

Source: the header of the iOS 16.4 SDK for the three methods and the protocol. There is no host oracle for a rotation, so `device/viewtransition.m` holds the expectations itself, on iOS 6 with
the status bar orientation really changed: the root is told once, with the size the window will have; a child view controller is told the same size; the coordinator carries the quarter turn as its
`targetTransform`; a block given to `animateAlongsideTransition:completion:` runs once and the completion runs once; setting the orientation already in effect tells nobody; turning back tells the old size.

## How the port does it

An observer of `UIApplicationWillChangeStatusBarOrientationNotification` walks each window's root controller. The size is the window's bounds, turned so that it is wide when the new orientation is landscape and tall when it is portrait. The default `viewWillTransitionToSize:withTransitionCoordinator:` forwards to the child controllers, asking `sizeForChildContentContainer:withParentContainerSize:` (the
parent's size unless overridden) and skipping a child that already has that size, and to a full screen presented controller. The coordinator is finished after the status bar animation duration.
`willTransitionToTraitCollection:withTransitionCoordinator:` forwards to children and is not called by the rotation: the trait collection of iOS 6 does not change with it.
