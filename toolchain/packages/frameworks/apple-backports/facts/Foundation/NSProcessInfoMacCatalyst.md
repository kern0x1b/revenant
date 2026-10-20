# NSProcessInfo macCatalystApp and iOSAppOnMac, iOS 13 and 14

Two properties answering whether the process is a Catalyst or an iOS-on-Mac app.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

Both answer NO: an iOS 6 process is neither.
