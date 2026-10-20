# +[UIFont monospacedDigitSystemFontOfSize:weight:], iOS 9

Introduced in iOS 9.0: the system font with digits of one width, so that a number that changes does not move.

Source: the host's own UIKit under Mac Catalyst (`host/tail1/run.sh`): the size is the one asked for, the ten digits measure the same and a bold weight gives a bold face. The device repeats it in `device/tail1.m`.

## How the port does it

The digits of the system font of iOS 6 (Helvetica Neue) are already all of one width, so the method is `+systemFontOfSize:weight:`, which maps the weight to the regular, light or bold face.
