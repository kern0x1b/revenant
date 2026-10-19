# +appearanceWhenContainedInInstancesOfClasses:, iOS 9

Introduced in iOS 9.0: the appearance proxy of a class that applies to its instances inside instances of the given container classes, taking the classes as an array where
`+appearanceWhenContainedIn:` (iOS 5) takes them as a list ended by nil, which a Swift application cannot call.

Source: the semantics of `+appearanceWhenContainedIn:` that the release already has, held on the device (`device/smallapis2.m`): a view of a class of the test with an appearance property, its proxy for a container class set to a colour,
for two nested container classes to another, and the colours of a leaf inside one container, outside and inside both. The host's Mac Catalyst answers the proxies (`host/smallapis2/run.sh` records that none is the plain appearance and that a bar
item has one) but applies no appearance in the headless scene the recorder runs in, so the colours are checked against the semantics and not against it.

The port answers the release's own `+appearanceWhenContainedIn:` for the array: one call with the classes of the array followed by nil, up to eight of them (UIKit takes no more than that), and `+appearance` for none.
The container classes must conform to `UIAppearanceContainer`, as for the release's method. It is added to `UIView` and to `UIBarItem`, the two roots of the classes that answer an appearance.
