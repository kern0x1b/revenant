# The home indicator and the edge gestures of a view controller

`-prefersHomeIndicatorAutoHidden`, `-preferredScreenEdgesDeferringSystemGestures`, `-childViewControllerForHomeIndicatorAutoHidden`,
`-childViewControllerForScreenEdgesDeferringSystemGestures` and the two `-setNeedsUpdateOf…` requests are what a controller of the release
overrides or sends to say that the indicator is to hide, or which screen edges are to leave the system gestures alone. This device has a home button and
no indicator, so nothing reads the indicator's answers. Its top edge carries a system gesture (measured, see the edge half below), so the edge
rows are `owed`: a controller's request to defer that gesture has nothing to defer it with yet.

Source: UIKit of iOS 12.0 arm64 (each method read at its address in the cache), and the host's own UIKit under Mac Catalyst, recorded by
`tests/backports/host/homeindicator/run.sh` and held against the port on the iPad 2 by `tests/backports/device/homeindicator.m`.

## What the port does

- The four getters of `UIViewController` answer what the release's default answers: NO, no edge, and no child.
- `UINavigationController` answers its top view controller and `UITabBarController` its selected view controller for the two child properties, as the
  release's overrides do.
- `-setNeedsUpdateOfHomeIndicatorAutoHidden` and `-setNeedsUpdateOfScreenEdgesDeferringSystemGestures` go to the parent view controller, or to the
  presenting one when there is no parent, and stop at the root, where the release hands the request to the application. A controller in the chain that
  overrides the method sees it once, as on the release.

Not carried: the update itself, which asks the application to redraw an indicator or to defer a system gesture. The indicator half is a part
this device does not have, so the answers above are the release's own for a device without one.

The edge half is measured and not implemented. On the iPhone4,1 6.1.3 emulator (`tests/backports/emulate/edgegesture/`, one run each, run through
`coordination/heavy.sh`), a drag from y 0 to y 200 at x 160 pulls Notification Center down, and a drag from y 100 to y 300 at x 160 leaves the application's white
window in place. The emulator is not a device, and the bottom edge is not measured. So the top edge carries a system gesture the application does
not own, and a deferral would have to reach it; the port has no arbiter that does. `-preferredScreenEdgesDeferringSystemGestures`, the two edge
children and `-setNeedsUpdateOfScreenEdgesDeferringSystemGestures` are `owed`, and their reasons say what to build.
