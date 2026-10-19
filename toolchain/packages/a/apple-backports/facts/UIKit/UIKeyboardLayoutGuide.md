# UIKeyboardLayoutGuide, UITrackingLayoutGuide, UIView.keyboardLayoutGuide and UIWindow.safeAreaAspectFitLayoutGuide, iOS 15.0 and 16.0

Introduced in iOS 15.0: `UITrackingLayoutGuide`, a layout guide that holds two sets of constraints, one active while it is near an edge of its
owning view and one while it is away from that edge; `UIKeyboardLayoutGuide`, the tracking guide that follows the keyboard; and
`UIView.keyboardLayoutGuide`. Introduced in iOS 16.0: `UIWindow.safeAreaAspectFitLayoutGuide`, a guide for the largest rectangle of a given
ratio inside the safe area.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/layout-guides`: the same checks in a bundled
application with a window, run on the host's guides and on the port's, compared line for line (31 checks; five planted controls fail).

## As UIKit does

- A keyboard guide's class is `UIKeyboardLayoutGuide`, a subclass of `UITrackingLayoutGuide`, whose owning view is the view it was read from.
  The same object comes back on each read. `followsUndockedKeyboard` is NO by default and keeps the value set.
- With no keyboard shown, the keyboard guide's frame is the full width of its view, at the bottom of the view's safe area, with zero height:
  `0,768,1024,0` in a 1024 by 768 window with no insets.
- A tracking guide holds its constraints per edge. A set on one edge leaves the other edge's set alone, and a read of an edge with nothing set
  answers an empty array. `removeAllTrackedConstraints` clears both sets for every edge. A nil set raises `NSInvalidArgumentException`.
- The window's aspect-fit guide is a `UILayoutGuide` whose owning view is the window, and the same object comes back on each read. Its
  `aspectRatio` defaults to 1 and keeps the value set. The frame is the largest rectangle of that ratio inside the safe area, centred in it: at
  ratio 1 in a 1024 by 768 window it is `128,0,768,768`, and at ratio 2 it is `0,128,1024,512`.

## What the port does

- `UIKit/UITrackingLayoutGuide.m` stores each edge's constraints as set, answers the empty array for an edge with nothing set, clears both
  sets with `removeAllTrackedConstraints`, and raises on a nil set because the dictionary it keeps does.
- `UIKit/UIKeyboardLayoutGuide.m` is the subclass, with `followsUndockedKeyboard` stored as set. `UIView.keyboardLayoutGuide` makes the guide
  once and adds it to the view, with its top at the safe area's bottom, its leading and trailing equal to the view's, and a zero height: the
  no-keyboard frame above.
- `UIKit/UIWindow+AspectFit16.m` makes the guide once and adds it to the window. Its size is held by two required bounds (no larger than the
  safe area) and two equalities to the safe area's size at priority 750, which the ratio, a required relation, overrides. Setting `aspectRatio`
  replaces the ratio constraint.

## Named differences

- **The keyboard is not followed.** The guide answers the no-keyboard position in every state. The host's guide moves with a shown keyboard,
  and the keyboard's frame can be read on a device only. This is **device-unverified**: the port has no keyboard tracking, so an application
  that moves its content with the guide on a device gets the position with no keyboard.
- **The activation of the tracking constraints is owed.** The host's sets are readable and stored, but a measurement of which set is active
  did not reduce to a position rule. With the near set alone it is never active, from the top edge to the bottom edge, with no keyboard; with
  the away set alone it is active everywhere; with both set, both read active. The port stores the sets and does not apply them, so
  `UITrackingLayoutGuide` stays owed (registry), and `UIKeyboardLayoutGuide` carries that gap with it.
- **The aspect-fit class.** The host's guide is a private class, `_UIWindowSafeAreaAspectFitLayoutGuide`. The port's is
  `CharonAspectFitLayoutGuide`, named here rather than matched.
- **The protocol.** `UILayoutGuideAspectFitting` is declared in the SDK's `UIWindow.h`, and it has no registry row in this band. The guide
  answers `aspectRatio` without declaring the protocol. Whether the host's guide conforms to it at run time is not measured in this differential.
- **Keyboard tracking on the release.** The keyboard guide's `usesBottomSafeArea` and `keyboardDismissPadding` are iOS 17 members, outside
  this band, and are not built.

## Corrected note

The earlier note in the band's report said the host throws on tracking-constraint queries after both sets are set. The probe does not
reproduce that: the queries return the stored constraints. The throw that was measured is the nil set, above.
