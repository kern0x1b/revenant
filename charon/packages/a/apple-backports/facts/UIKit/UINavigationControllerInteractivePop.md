# UINavigationController.interactivePopGestureRecognizer, iOS 7

Introduced in iOS 7.0: the recognizer that pops the top page when a finger is dragged from the left edge of the screen; an
application turns it off (`enabled`) or asks it to begin under its own conditions (`delegate`).

Source: the release's behaviour is the one an application depends on, and `device/interactivepop.m` holds iOS 6 to it with real
touches (IOHID): the recognizer exists and is enabled, has a delegate of its own and lives on the navigation controller's view; a
drag from the edge past the middle of the screen pops one page, a short one lets go and leaves the page, a disabled recognizer and a
delegate that says no keep the page, one that says yes pops, and the root page stays.

The port makes the recognizer when the navigation controller's view loads (before that the property is nil, as the release's): a
`UIScreenEdgePanGestureRecognizer` on the left edge whose delegate refuses a stack of one page, a page that hides its back button
and a page with a left bar button item of its own, as the release does. A drag pops the page with the port's transition engine, a
percent-driven interaction that follows the finger: the top page slides right over the page below, which moves in from a third of
its width to the left under a light dimming, and a shadow lies on the left edge of the top page. Let go past the middle of the
screen or with a speed to the right, it finishes; otherwise it is cancelled and the page comes back. An application that answers a
pop animation of its own in the navigation delegate keeps it, without interaction.

## What differs

The release's recognizer is a private subclass of a pan recognizer, not a `UIScreenEdgePanGestureRecognizer`; the navigation bar
of the port's transition does not cross-fade its items as the release's does while the finger moves.
