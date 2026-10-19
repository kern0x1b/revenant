# UIFocusEffect, UIFocusHaloEffect, and the focus-group properties of UIView and UIViewController, iOS 14.0 and 15.0

Introduced in iOS 15.0: `UIFocusEffect`, the base of a focus effect; `UIFocusHaloEffect`, the halo a view shows when it has focus; and
`UIView.focusEffect` and `UIView.focusGroupPriority`. The focus-group identifiers of `UIView` (iOS 14.0) and `UIViewController` (iOS 15.0) are
kept as set.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/focus-effects`: the same checks in a bundled
application with a window and the iPad idiom, once on the host's classes and once on the port's, compared line for line (34 checks; five
planted controls fail).

## As UIKit does

- `+[UIFocusEffect effect]` makes a plain `UIFocusEffect`. The class's `-init` is unavailable to the compiler; the instance is made at run time.
  `-copy` returns the effect itself.
- `+effectWithRect:`, `+effectWithRoundedRect:cornerRadius:curve:` and `+effectWithPath:` make a `UIFocusHaloEffect`, a subclass of
  `UIFocusEffect`. The container and the reference view start nil. `position` starts at Automatic (0); the values are Automatic 0, Outside 1
  and Inside 2, as measured.
- `UIView.focusEffect` reads a fresh `UIFocusEffect` on each read until it is set. A set reads back the same object (a copy of an effect is the
  effect). Setting nil is kept: the view then reads nil, which differs from a view that was never set.
- `UIView.focusGroupPriority` starts at 0 (`UIFocusGroupPriorityIgnored`) and keeps the value set, including the named values 1000 and 2000 and
  any other integer.
- `UIView.focusGroupIdentifier` and `UIViewController.focusGroupIdentifier` start nil and keep the string set.

## What the port does

- `UIKit/UIFocusEffect.m`: `+effect` makes the instance through the NSObject initializer; `-copyWithZone:` returns the effect.
- `UIKit/UIFocusHaloEffect.m`: the three factories make an instance; the container and the reference view are weak and start nil; `position`
  is stored as set.
- `UIKit/UIView+Focus15.m`: `focusEffect` reads a fresh plain effect when never set, stores a copy of a set effect, and stores a nil set as
  `NSNull` so that it reads back nil. `focusGroupPriority` starts at 0 and stores the value set.
- `UIKit/UIViewController+FocusGroup15.m`: the view controller's identifier is stored, copied and nil to start.
- `UIKit/UIView+FocusGroup14.m` already carries the view's identifier; the differential checks it.

## Named differences and gaps

- **Nothing is drawn.** A halo's shape (the rect, the rounded rect, the path) is accepted and not kept, because the port draws no focus. No
  halo appears on screen. The focus engine that draws it is not built, so the effect is recorded and never shown.
- **No focus moves.** The focus engine's movement, its update context, the parent focus environment and the focus item container are not built.
  `UIFocusItem.isTransparentFocusItem` is not built: the host answered YES for a plain view and for a view with an effect, which is all that was
  measured, and the rule for other focus items is not known.
- **device-unverified.** The port has not run on a device; on iOS 6 there is no focus engine to read these values, so an application that sets
  them gets them back with no visible effect.
- **The priority's effect on focus order** is not built with the engine.
