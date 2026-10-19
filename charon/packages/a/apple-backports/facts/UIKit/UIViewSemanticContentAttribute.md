# UIView semanticContentAttribute, iOS 9 and iOS 10

Source: the host's own UIKit, under Mac Catalyst, asked every attribute with each layout direction and held against the
backport by `tests/backports/host/uikit2/run.sh` (the `viewmisc` group); and iOS 6.0 and 6.1.3 on the emulator, an
iPhone 4S and an iPad 2, through `tests/backports/device/uikit2.m`.

`semanticContentAttribute` is unspecified (0) until set and answers what it was set to: playback is 1, spatial 2,
force left to right 3, force right to left 4. It changes nothing on iOS 6 by itself: the port does not mirror a view.
What it answers is the direction the attribute stands for, and the rule is one table, read from the host for the two
layout directions of an application:

| attribute | in a left-to-right application | in a right-to-left one |
|---|---|---|
| unspecified | left to right | right to left |
| playback | left to right | left to right |
| spatial | left to right | left to right |
| force left to right | left to right | left to right |
| force right to left | right to left | right to left |

`+userInterfaceLayoutDirectionForSemanticContentAttribute:` is that table for the application's own direction,
and the form with `relativeToLayoutDirection:` takes the direction. `-effectiveUserInterfaceLayoutDirection` of a view is
the table for the view's own attribute: a view does not take its superview's attribute, so an unspecified view under a
view forced to right to left is left to right.
