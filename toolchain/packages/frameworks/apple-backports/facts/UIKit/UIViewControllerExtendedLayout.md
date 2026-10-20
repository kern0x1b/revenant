# The extended layout of a view controller, iOS 7

Source: the host's own UIKit, under Mac Catalyst, asked for each property and through
`tests/backports/host/uikit2/run.sh`; and iOS 6.0 on an iPhone 4S in the emulator, asked in a navigation
controller with a translucent bar and then with an opaque one.

## What each property holds

`edgesForExtendedLayout` answers `UIRectEdgeAll` (15), `extendedLayoutIncludesOpaqueBars` NO and
`automaticallyAdjustsScrollViewInsets` YES, on a controller that has been told nothing - the same three
answers in a navigation controller. Each takes what it is given and answers it back untouched, whatever the
bits: 0, 1, 2, 4, 8, 15, 16, 255 and `NSUIntegerMax` all read back as set, so nothing is masked to the four
edges. A controller keeps its own values; setting one on another changes nothing here.

## What it does not do on iOS 6

The three properties steer where iOS 7 lays a controller's view: under the bars or below them, and whether
the scroll view inside it is inset to match. iOS 6 has one layout for that and none of these properties
reaches it. In a navigation controller with a translucent bar the root controller's view is 320 by 460
points at the origin whether `edgesForExtendedLayout` is all edges, none, or all edges again with opaque
bars included and the scroll view insets left alone; with an opaque bar it is 320 by 416 in every case,
the 44 points of the bar taken off by the release itself. The device test lays the same controller out in
those three states and holds the frames equal, and that is what makes the properties `inert`: they are
kept, answered and applied to nothing.

An application written for iOS 7 that leaves a controller under the bars and insets its content by the
height of the bar by hand gets that inset twice on iOS 6; one that reads the properties back finds what it
set.

## What archiving keeps

The newest system keeps `edgesForExtendedLayout` and `extendedLayoutIncludesOpaqueBars` when a controller is
archived and read back, and forgets `automaticallyAdjustsScrollViewInsets`: a controller set to no edges,
opaque bars included and no scroll view adjustment reads back as no edges, opaque bars and adjustment YES.
On iOS 6 none of the three survives - the controller comes back with all edges, no opaque bars and
adjustment YES. The backport keeps its values in the controller itself and cannot add them to the
release's own `-encodeWithCoder:` and `-initWithCoder:`, which it never replaces, so a controller decoded
from a nib or an archive on iOS 6 has the defaults of these properties, not the ones written into it.
