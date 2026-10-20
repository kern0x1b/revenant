# NotificationCenter, on a release that has none

iOS 8 brought the Today widget and with it `NotificationCenter.framework`, whose whole purpose is to
be the panel the widget is drawn in. iOS 6.1.3 has no Notification Center, no Today widgets and no
widget host: there is nothing in its armv7 6.1.3 cache that could hold one, and the release's SpringBoard
has no such surface. What is left is the *application's* half of the API, and that is what this
delivery carries.

## `NCWidgetController`: a real record, no consumer

`-[NCWidgetController setHasContent:forWidgetWithBundleIdentifier:]` tells the system that a widget
has content worth reloading, so the system can decide whether to ask the widget to refresh. The flag
is the application's own statement, so the port keeps it - under a namespaced `NSUserDefaults` key,
the same convention `UIApplication+UserNotificationSettings.m` already uses for its registered-types
record and `NCWidgetController` uses for nothing else - and the application reads back exactly what
it wrote. What cannot happen on this release is the reaction: nothing polls the record, because there
is no panel to poll it for. That is said once in the log, at construction, so a process holding the
controller knows why its flags change nothing.

This is the shape the registry's README already allows for MediaPlayer's
`MPRemoteCommandCenter` (`registry/MediaPlayer`, "real, addressable command objects that never fire,
honestly, not fabricated ones").

**Why `setHasContent:forWidgetWithBundleIdentifier:` is `implemented` and the nine members of this
delivery that became `absent` were not.** The difference is who can read the value back. This one
writes a flag into `NSUserDefaults` under a namespaced key, which is public API the *application* can
read, so the round trip is real to someone outside the port: an app that sets a flag and reads it gets
it. The nine that went `absent` each kept their value in an object whose every reader was the port
itself and got nothing - a subject with no field to show it, a media state with no system to take it, a
display mode with no panel to honour it - so the value was stored and ignored, which is the silent
fake `COORDINATION.md` §2 forbids. What is missing here is the *consumer* (a panel that would poll the
record), which is the same seam as the MediaPlayer commands above; what was missing there was a reader
of any kind, which is a different thing.

## The three display-mode members: the documented compact contract

`NCWidgetDisplayMode` has two cases, compact and expanded. The contract NotificationCenter documents (NCWidgetTypes.h
and NCWidgetProviding.h of the iOS SDK) is that a widget no Today host presents is in compact mode, that compact is the
fixed height, and that an expanded size is granted only by a host. Three members speak of the mode, and the port carries
all three as a category of `NSExtensionContext` in `NotificationCenter/RevenantNSExtensionContext+NotificationCenter.m`:

* `-widgetActiveDisplayMode` and `NSExtensionContext.widgetLargestAvailableDisplayMode` answer compact (0). A context no
  host presents is compact, and no host grants a larger mode, so the largest a context may use is compact.
* `-widgetMaximumSizeForDisplayMode:` answers the width of the screen by the compact height of 110 points, for compact and
  expanded alike, because no host grants the expanded size.

**What was measured, and what was not.** The constants are not in any header this package can read: the macOS SDK's
NotificationCenter headers (NCWidgetController.h, NCWidgetListViewController.h, NCWidgetProviding.h, NotificationCenter.h)
declare none of the three members or the mode, and the device SDK is not installed here. On Catalyst a fresh
`NSExtensionContext` answers none of the three selectors (`tests/backports/host/nsextension-context`, golden: absent),
so the host cannot be the oracle for them. The values are the documented ones, named under Revenant's own names so they
collide with nothing Apple declares. The screen width is measured: Catalyst's main screen is 960 points wide in the probe,
and the port's answer is that same `UIScreen` value, which the harness checks line for line.

**The seam.** No Today host presents a context on this release, so nothing reads the mode back and nothing grants the
expanded size. The members answer the documented value for a context in that state, which is the state every context on
this release is in. That is the same seam as `setHasContent:forWidgetWithBundleIdentifier:` above: the answer is real to
an application that asks it, and what would change it (a host that grants more) is absent on the release.

## The four vibrancy factories, and what is *not* measured

The port's `UIVibrancyEffect` is a real effect: `UIKit/UIVisualEffect.m` keeps the blur style it was
made with, implements `isEqual:`, `hash`, `-description` and `NSCoding` over it, and
`UIKit/UIVibrancyEffect+Style13.m` adds `+effectForBlurEffect:style:` for the vibrancy style itself.
So each factory builds a real effect and the answer compares, archives and describes as the system's
does. The blur style values are read from `UIBlurEffect.h` of SDK 26.2: ExtraLight 0, Light 1,
Dark 2.

**The mapping of a widget style to a material is reasoned from the header's own wording, not
measured.** `widgetPrimaryVibrancyEffect` is documented "for use with select supporting text and
glyphs" and is given `UIBlurEffectStyleLight`; `widgetSecondaryVibrancyEffect` is documented "where
further diminution is required" and is given `UIBlurEffectStyleExtraLight`, the next lighter
material; `notificationCenterVibrancyEffect` is given Light, which is what iOS 10 replaced it with.
There is no host to hold this to, and the reason was measured rather than assumed: compiling a call
to any of the four for `arm64-apple-ios15.0-macabi` against the Command Line Tools' `iOSSupport` fails
with "no known class method for selector 'notificationCenterVibrancyEffect'", because the
deprecation is `ios(13.0, 14.0)` and the host's UIKit no longer declares them. The port's own
`UIVisualEffect` differential (`tests/backports/host/uikit2`, the visualeffect group) is what covers
the effect these factories return.

## `NCWidgetProviding`, and why the protocol is `absent`

All three of its members are messages the *system* sends to the widget's own view controller, and all
three depend on the panel: ask it to refresh, tell it the mode changed, ask it for the insets it
would use. Nothing in the port sends them and nothing in the port reads them, so no class of ours
could conform and the protocol is not carried. An application that writes
`@interface MyWidget : UIViewController <NCWidgetProviding>` gets the protocol emitted in its own
translation unit, with its own implementations on it, which is the whole of what a protocol is for.

`widgetMarginInsetsForProposedMarginInsets:` also carries `maximum: "10.0"`, because the header
itself stops calling it on widgets linked against iOS 10 and later - the port is not going to carry
an API a current release has withdrawn, and the registry's own README gives `removed`/`maximum` as
the way to say so.
