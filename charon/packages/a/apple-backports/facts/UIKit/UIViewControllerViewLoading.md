# UIViewController viewIfLoaded, loadViewIfNeeded and preferredContentSize, iOS 9 and iOS 7

Source: the host's own UIKit, under Mac Catalyst, held against the backport by `tests/backports/host/uikit2/run.sh` (the
`viewmisc` group); and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad 2, through
`tests/backports/device/uikit2.m`.

`viewIfLoaded` is the view when the controller has loaded it and nil otherwise, and asking does not load it.
`loadViewIfNeeded` loads the view when it is not loaded - `-loadView` and `-viewDidLoad` run - and does nothing when it is.

`preferredContentSize` is zero by size, `{0, 0}`, until it is set, and answers what was set. It is the value the
newest release lets a container ask a child for; iOS 6 has `contentSizeForViewInPopover`, a different property with
its own default, and the port keeps the two apart.
