# Whether a screen is being captured, iOS 11

`-[UIScreen isCaptured]` (iOS 11) is YES while the screen is recorded, mirrored or sent to AirPlay, and `UIScreenCapturedDidChangeNotification` is posted with the screen as its object when that changes. An application
that shows content it must not let out - a password, a paid video - hides it while the screen is captured.

Source: UIKit of the arm64 shared cache of iOS 12.0 - the getter at `0x1ace87628` and the setter `-_setCaptured:` at `0x1ace87638`, which the release's own screen services call - and the name of the
notification as a constant of that cache.

## What the port does

The release does not record its screen for an application to see, but it mirrors it: `-[UIScreen mirroredScreen]` of the main screen is the external screen while an
HDMI or AirPlay display shows a copy. The port answers YES for the main screen while it has a mirrored screen, and for the screen that mirrors it, and NO otherwise. The notification is posted, with the
screen as its object, when a screen connects or disconnects, or changes its mode, and the answer of that screen is not what it was.

## What is checked, and what is not

On an iPad 2 on 6.1.3, which has no external display, the answer is NO, the notification's name is its own name, and a connect notification that changes nothing posts nothing (`tests/backports/device/traits11-cases.m`, run there). A display that
mirrors was not at hand, so a YES answer and the post that comes with it follow from the code above and were not watched. The host's own UIScreen asks `-isCaptured` while it is made, which is why the port's file is held to the
device alone.

Not carried: a recording of the screen, which iOS 6 cannot tell.
