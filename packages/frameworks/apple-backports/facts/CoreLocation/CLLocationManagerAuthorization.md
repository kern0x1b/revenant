# CLLocationManager requestWhenInUseAuthorization and requestAlwaysAuthorization, iOS 8

Source: CoreLocation of iOS 12.0 arm64 (`-[CLLocationManager requestWhenInUseAuthorization]` at `0x187d680b4`,
`-requestAlwaysAuthorization` at `0x187d6841c`), read instruction by instruction; and iOS 6.0 on the emulator, and iOS
6.1.3 on an iPhone 4S and an iPad 2, through `tests/backports/device/uikit2.m`.

## What is read of the newest release

Both methods are thin. Each opens an activity for the manager and hands the request to the manager's internal object
inside a block, and nothing else is decided in this library: whether a prompt appears, what the prompt offers, and
what a usage description missing from the application's property list does are decided by the location daemon, not by
CoreLocation. The library carries no rule for them that could be read, and none is written here from the documentation
in its place.

## What the port does

The two methods are the same request on iOS 6, which has one authorization and one prompt for an application, with no
choice between while in use and always:

- nothing happens when location services are off or the application's status is already anything but not determined;
- otherwise a manager of the port's own is made once, given a delegate of the port's, set to an accuracy of 3000 metres,
  and told to start updating the location, which is what makes iOS 6 ask the user; a request made while that manager
  is still waiting is ignored;
- the manager stops and is dropped when the status leaves not determined, or after the first location.

So the answer the user gives reaches the application through the manager the application itself made, as its
`-locationManager:didChangeAuthorizationStatus:`, and `+authorizationStatus` afterwards is the release's: the granted
status of iOS 6 is 3, the same number the newest release names always-authorized, so an application that asked for
while-in-use sees the always status.

## What was measured

The device run checks that both methods are installed, that they come from `libCoreLocationBackports.dylib`, and that
a request does not raise. On the emulator location services are on and the status is not determined (0), and there is
no user to answer, so it is 0 again after the request. On the iPhone 4S and the iPad 2 location services are off and
the status is denied (2); the request does nothing there. Whether the prompt appears on a device with services on was
not observed.
