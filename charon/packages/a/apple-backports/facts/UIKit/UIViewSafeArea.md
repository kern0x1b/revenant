# The safe area of a view, iOS 11.0

Introduced in iOS 11.0: the part of a view that nothing of the system covers.

Source: UIKit of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372), read in
full for the path below. There is no differential test against a host for this
one: `UIWindow` cannot be created through Mac Catalyst without a full
application, so the expectations of `tests/backports/device/safearea-tweak.m`
are derived from the algorithm here by hand and checked on the device.

| member | address in 11.0 |
|---|---|
| `-[UIView safeAreaInsets]` | `0x18a285b78` |
| `-[UIView setSafeAreaInsets:]` | `0x18a27d1cc` |
| `-[UIView _updateSafeAreaInsets]` | `0x18a27c9d4` |
| `-[UIView _safeAreaInsetsInSuperview:]` | `0x18a27c720` |
| `-[UIView _safeAreaInsetsForFrame:inSuperview:]` | `0x18a27c7d0` |
| `-[UIView _edgesPropagatingSafeAreaInsetsToDescendants]` | `0x18a27c6d4` |
| `-[UIView _safeAreaInsetsDidChangeFromOldInsets:]` | `0x18a27d178` |
| `-[UIViewController additionalSafeAreaInsets]` | `0x18a329618` |
| `-[UIViewController setAdditionalSafeAreaInsets:]` | `0x18a30d224` |

## How UIKit computes it

The value is **stored**, in the field at offset `0x1b8`; `-safeAreaInsets` only
reads four doubles out of it. UIKit refreshes it at its own moments — during
layout, when a frame changes, when a view changes superview — through
`-_updateSafeAreaInsets`, which is exactly

    [self setSafeAreaInsets:[self _safeAreaInsetsInSuperview:[self superview]]]

and `-_safeAreaInsetsInSuperview:` takes the view's `frame` (or
`_frameIgnoringLayerTransform` when a layer transform is in play) into
`-_safeAreaInsetsForFrame:inSuperview:`, which does three things:

1. If the superview belongs to a view controller, its overlay insets are
   refreshed (`_updateContentOverlayInsetsFromParentIfNecessary`) and read
   (`_contentOverlayInsets`), then joined with the superview's own safe area by
   `_UIEdgeInsetsMax` — the larger of the two on every edge.
2. `_edgesPropagatingSafeAreaInsetsToDescendants` decides which edges travel
   down at all. A plain `UIView` answers `0xf`, all four; subclasses narrow it.
3. `_UIViewInsetsNormalizedToInnerRect` moves the result from the superview's
   bounds to the view's frame: for each edge, `max(0, outer edge − inner edge)`
   — in the code a subtraction followed by `fmaxnm` against zero.

`-setSafeAreaInsets:` compares the four numbers with what is stored and, only
when they differ, calls `_safeAreaInsetsDidChangeFromOldInsets:`, which notifies
**the view first** (`-safeAreaInsetsDidChange`) and the controller second
(`-viewSafeAreaInsetsDidChange`, reached as `_safeAreaInsetsDidChangeForView`).
The whole store is gated on `__UIApplicationLinkedOnOrAfter`, so an application
built against an older SDK sees zeroes.

`-setAdditionalSafeAreaInsets:` compares with what it holds and, on a change,
asks the controller and its children to recompute their overlay insets: the
additional insets are part of the overlay, not something applied to the view
afterwards.

## What the port does, and what it refuses

The geometry carries over unchanged: the port computes the same joins and the
same `max(0, outer − inner)`. Two things differ, both on purpose.

**The value is computed on every read, not stored.** Storing it would need a
refresh at UIKit's moments, and reaching those means replacing `-layoutSubviews`,
`-setFrame:` or `-didMoveToSuperview`, which the port does not do. Computed on
read, the answer is always current, and the recursion up the superview chain is
what UIKit does anyway, once per level.

**The callbacks are not declared.** `-safeAreaInsetsDidChange` and `-viewSafeAreaInsetsDidChange` would each be a promise the port
cannot keep: they are called from the moment of change, which the port never sees. They are in the registry as `absent` with that
reason.

**`insetsLayoutMarginsFromSafeArea` is carried, and wired into `-layoutMargins`.** It is a stored `BOOL`
(`UIView+LayoutMargins.m`, an associated object, default `YES` as on every release that has it) read by `-layoutMargins` itself: when
it is `YES`, the margins `-layoutMargins` would otherwise answer are maxed, edge by edge, against `-safeAreaInsets` — the same
`max()` iOS 11 does at `0x18a27bca4`. This is not a promise the port cannot keep the way the two callbacks above are: `-layoutMargins`
is computed on every read already, so folding `-safeAreaInsets` in costs nothing the getter was not already paying, and the flag
genuinely changes what the next read of `-layoutMargins` answers instead of being read and believed for nothing.

**`-safeAreaLayoutGuide` is carried.** An application that constrains to the guide (`view.safeAreaLayoutGuide.topAnchor`) failed on iOS 6 with an
unrecognized selector, and the guide can be kept live now that the port has layout guides. The property answers one `UILayoutGuide` per view, owned
by the view, whose left, right, top and bottom edges are constrained to the view's edges by the four insets of `-safeAreaInsets`
(the same constraints as the layout margins guide has on this release). The constants are read again just before the view lays out, when
the view is put into a window and when the status bar changes its frame, so a guide follows a navigation bar that is hidden or shown, a
change of the status bar and a view that moves; a change of the insets that none of these sees (a bar that another controller
changes) is picked up at the next layout of the view. Nothing is sent when the insets change, so `-safeAreaInsetsDidChange` is not called.
Held against the host's UIKit by `tests/backports/host/safeguide/run.sh` (7 records: the guide's identity and owner, its frame
against the view's bounds inset by `safeAreaInsets`, a view pinned to it, a navigation bar hidden and shown, an inner view, a view
outside a window) which `tests/backports/device/safeguide.m` compares on the iPad 2 and the iPhone 4S. The insets themselves are the
port's and differ from the host's numbers (the host's window has none of the bars of iOS 6), which is why the records are the relations, not the numbers.

## Where the insets come from on iOS 6

iOS 11 gets them from the controller's overlay insets, which are built from the
scene, the bars and the presentation chain — machinery iOS 6 does not have. On
iOS 6 the layout does not extend under the bars: the view of a controller is
already laid out below the navigation bar and above the tab bar, and it reaches
under the status bar only when the controller asks for a full screen layout.
So the port measures what is really covered:

- a window is inset by the part of `-[UIApplication statusBarFrame]` that falls
  inside it, when the status bar is not hidden;
- a controller's view is inset by the parts of the status bar, the navigation
  bar, the toolbar and the tab bar that actually overlap it — each converted
  into the view's own coordinates and intersected with its bounds, and only when
  that bar is visible and in the same window;
- `additionalSafeAreaInsets` are **added** to that, edge by edge, as iOS 11 adds
  them into the overlay;
- everything below inherits by the geometry above.

The controller of a view is found through the responder chain: the view of a
controller answers it as its `-nextResponder`.

**A toolbar nobody asked for is not made to be measured.** `-[UINavigationController toolbar]` makes the bar the first time it
is asked, on iOS 6.1.3 and on the host's UIKit alike, and neither release asks for it while laying out. The first version of
the port read it on every call, so a navigation controller that never used a toolbar grew a hidden one,
`UIToolbar(0,480,320,44)` below the screen, at its first layout: an application's view tree showed a bar the phone's own UIKit
never makes. A toolbar the controller keeps hidden covers nothing, so the port asks for the bar only when `-isToolbarHidden`
is `NO`. Measured on the iPhone 4S emulator (6.1.3): `-isToolbarHidden` answers `YES` for a controller that was never asked
for a toolbar, and answering it makes none; a controller that shows a translucent toolbar under a full screen layout still
gets 44 as its bottom inset, the height the toolbar covers. Not measured: a toolbar hidden with an animation, where
`-isToolbarHidden` may already answer `YES` while the bar is still sliding down, and the inset would then drop at once
instead of following the bar. The host cannot see a shown toolbar (its windows keep a toolbar out of the view tree);
`tests/backports/host/toolbar/run.sh` holds the port to the host's own UIKit on the making of the bar, and
`tests/backports/device/toolbar.m` holds the shown toolbar's cover on a device.

## Where the insets stop

Two rules the first version of the port did not have, both found by putting it
in front of the current implementation a second time.

A view that is in no window has **no** safe area, whatever its controller says:
the current implementation answers zero for a controller's view that was never
put in a window, even when `additionalSafeAreaInsets` were set on it and read
back unchanged. The port answers zero there too, and asks the question the way
this release can - a view is in a window when it is one or when `-window`
answers - since iOS 6's `-[UIWindow window]` is nil rather than itself.

The safe area never goes below zero. `additionalSafeAreaInsets` are added edge
by edge, negative values included, and the sum is floored at nothing: on the
device, a status bar of twenty with an additional inset of minus ten leaves
ten, and minus a hundred leaves zero, not minus eighty. The port added the
controller's insets with a maximum before, which quietly ignored every negative
one; it adds them now and floors the result.

## How far this is checked

The tweak runs inside Preferences on an iPhone 4S (iPhone4,1, 6.1.3, armv7)
and holds every number above: a window inset by the status bar alone, a view
below it and a view under it, the additional insets adding edge by edge, a
subview away from every edge, one at the top and one at the bottom carrying
three insets each, a nested subview keeping what its own frame still covers, a
view with neither superview nor controller, and clearing the additional insets
again. Forty-seven checks in one run, the whole tweak, no failures; the same run
carries the scroll view, the directional margins, the font metrics, the two
rules above and what this release's own visual format parser does with an
option of iOS 11.
