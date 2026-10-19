# A view that ignores inverted colours, iOS 11

`-[UIView accessibilityIgnoresInvertColors]` (iOS 11) is a flag of a view that says the render server leaves its colours as they are when the
user inverts the colours of the screen - a photograph, a video, a map.

Source: UIKit of the arm64 shared cache of iOS 12.0 - the getter and the setter of the flag at `0x1aca7fc40` and `0x1aca7fc20`, a bit of the view's flags, so that any value is kept as
yes or no - and the host's UIKit under Mac Catalyst, recorded by `tests/backports/host/traits11/run.sh` and held to the same records on an iPad 2 on iOS 6.1.3 by `tests/backports/device/uikit12.m`, which passed all 100 of its checks there.

## What the port does

iOS 6 inverts the whole screen in the render server, and offers no way to leave a view out of it, so the port keeps the flag and reads it back - NO until it is set, and each view its own - and
says once in the log that the view is inverted with the rest when an application sets it. It is inert.
