# CLLocationManager allowsBackgroundLocationUpdates, iOS 9, and showsBackgroundLocationIndicator, iOS 11

Source: CoreLocation of iOS 12.0 arm64 (CoreLocation-2245.4.104), read instruction by instruction:
`-[CLLocationManager allowsBackgroundLocationUpdates]` at `0x187d58308`, `-setAllowsBackgroundLocationUpdates:` at
`0x187d5809c`, `-showsBackgroundLocationIndicator` at `0x187d5868c`, `-setShowsBackgroundLocationIndicator:` at `0x187d584b4`;
the SDK headers of iOS 16.4 for `CLLocationManager.h`; and iOS 6.0 on the emulator and iOS 6.1.3 on an iPad 2, through
`tests/backports/device/corelocation.m`.

## What is read of the newest release

Each getter reads a byte of the manager's own internal object and each setter writes one and tells the client daemon, which
decides whether the application may go on locating in the background and whether the blue bar is drawn. What the daemon
does with them is not readable in CoreLocation.

## What the port does

iOS 6 lets an application locate in the background by the location entry of its `UIBackgroundModes` alone, and draws a
location arrow in the status bar whenever location is in use; it has no per-manager switch and no bar of its own. Both
properties are kept and answered back, start NO, and say once in the log the first time they are set to YES that nothing
changes: an application that relied on the switch being NO to stay out of the background gets what its property list says.

## What was measured

The emulated iOS 6.0, an iPad 2 and an iPhone 4S on iOS 6.1.3, the same answers on all three: both switches start NO, answer
what was set, are independent of each other, and the log line of each appears once, the first time it is set to YES. Whether
an application with a location entry in its `UIBackgroundModes` goes on locating when it goes to the background was not
tried.
