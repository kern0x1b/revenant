# The layout margins of a view, iOS 8

Source: the host's own UIKit, measured against a superview whose margins overlap the subview, and the
differential run of `tests/backports/host/layout/run.sh`.

`layoutMargins` is eight points on each side to begin with, and it stores whatever it is given, negative
values and fractions included.

`preservesSuperviewLayoutMargins` is NO to begin with. Where it is YES the view's margins become the
larger of its own and the part of the superview's margin area that reaches into it, edge by edge. On a
300 by 300 superview with margins of 40, 50, 60 and 70, a subview at (20, 20) sized 100 by 100 answers a
top margin of 20 and a left margin of 30 - the superview's margin minus the distance to it - while its
bottom and right stay at eight, because the superview's margins on those sides do not reach it. Moved to
the corner the same subview answers 40 and 50. Setting the margins explicitly does not undo it: with
1, 2, 3, 4 set on that subview the answer is 40, 50, 3, 4, since each edge takes the larger of the two.

`-layoutMarginsDidChange` is sent to the view when the margins it answers change: once when they are set
to a new value, not at all when they are set to the value they already have, and once when
`preservesSuperviewLayoutMargins` changes what they come to.

## The same moment seen from the controller (iOS 11)

`-[UIViewController viewLayoutMarginsDidChange]` is delivered from the same place the view's own message
is, in `UIView+LayoutMargins.m`'s `charon_margins_changed`, right after the view is told and before its
subviews are walked. The order is the release's own: `facts/UIKit/UIViewSafeArea.md` records that iOS 11
tells the view first and the controller second, from `-_safeAreaInsetsDidChangeFromOldInsets:` at
`0x18a27d178`. The controller is found by walking `nextResponder`, which is the walk
`UIView+SafeArea.m`'s `charon_view_controller` already makes for the safe area, so there is one way to ask
the question rather than two.

The member is declared by its own file, `UIKit/UIViewController+LayoutMarginsDidChange11.m`, and not by
the one that delivers it. `UIView+LayoutMargins.m` carries the 8.0 property and is kept in every band from
6.0, so the member it delivers has to belong to the release that introduced it — which is what
`tools/release-split.lua` reads, and why the delivery asks `respondsToSelector:` first rather than
assuming: in a band below 11.0 the controller answers NO, the message is not sent, and a send that assumed
would raise instead of doing nothing.

The method's body is empty, and that is the whole of the release's behaviour for a message it has no work
of its own to do. An application overrides it and is called.

**What this does not claim.** It is delivered at the moment the port's own margins change, which is the
moment it produces them. The value `-layoutMargins` answers is also computed from `-safeAreaInsets` when
`insetsLayoutMarginsFromSafeArea` is on, so a change of the insets that margins fold in reaches the next
read without a message; that is the same limit `-[UIView layoutMarginsDidChange]`, which this sits beside,
already carries and which the tree shipped first. A row that claimed more than that would be a partial
callback dressed as a whole one.
