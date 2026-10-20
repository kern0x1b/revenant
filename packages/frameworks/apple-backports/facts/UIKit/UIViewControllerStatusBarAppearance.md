# UIViewController status bar appearance, iOS 7

Source: the host's own UIKit, under Mac Catalyst, held against the backport by `tests/backports/host/uikit2/run.sh` (the
`viewmisc` group), for the defaults; and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad 2, through
`tests/backports/device/uikit2.m`.

A controller prefers the default status bar style (0) and a visible status bar, and asks for a fade (1) when either
changes. `childViewControllerForStatusBarStyle` and `childViewControllerForStatusBarHidden` are nil, and
`modalPresentationCapturesStatusBarAppearance` is NO until set. A subclass that overrides the preferences is asked
in the newest release whenever the appearance is to be decided.

## What iOS 6 does with them

iOS 6 keeps the status bar in the application, not in the controllers. The port makes `setNeedsStatusBarAppearanceUpdate` do
what the newest release does after it: it finds the controller in charge from the key window's root controller, going
into a presented controller that covers the screen or captures the appearance, and then into the child a controller
names for the style and for the hiding, and sets the application's status bar style and visibility from that
controller's preferences, animated the way it asks when animations are on. The style values are the same numbers:
iOS 6 calls the translucent black style what iOS 7 calls light content. An iPad of iOS 6 has no translucent
status bar and answers the opaque black one for it, as measured on an iPad 2.

What iOS 6 cannot do is ask on its own. The newest release asks when a controller appears or a presentation changes;
the port is asked only when the application calls `-setNeedsStatusBarAppearanceUpdate`, so an application that only
overrides the preferences has them ignored until it does.
