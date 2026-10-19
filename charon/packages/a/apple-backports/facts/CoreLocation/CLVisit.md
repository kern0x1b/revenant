# CLFloor, CLLocation.floor, CLVisit and visit monitoring, iOS 8

Source: CoreLocation of iOS 12.0 arm64 (CoreLocation-2245.4.104), read instruction by instruction: `-[CLLocation floor]` at
`0x187db8330`, `-[CLFloor level]` at `0x187db7150`, `-[CLLocationManager startMonitoringVisits]` at `0x187d6acd8` and
`-stopMonitoringVisits` at `0x187d6aeb0`, and the methods of `CLVisit` from `0x187d9a954` to `0x187d9b16c`; the SDK headers of
iOS 16.4 for `CLLocation.h`, `CLVisit.h`, `CLLocationManager+CLVisitExtensions.h` and `CLLocationManagerDelegate.h`; and iOS
6.0 on the emulator and iOS 6.1.3 on an iPad 2, through `tests/backports/device/corelocation.m`.

## What is read of the newest release

- `-[CLLocation floor]` answers nil when the location's own floor level is `INT_MAX`, which is what a location has when no
  floor is known, and otherwise a `CLFloor` made with that level. `-[CLFloor level]` is the getter of it.
- `-startMonitoringVisits` and `-stopMonitoringVisits` open an activity, perform the courtesy prompt if one is due, and hand
  the request to the daemon. What makes a visit, and when the delegate is told of one in `-locationManager:didVisit:`, is the
  daemon's, and not readable in CoreLocation.
- A `CLVisit` is made by the library from a coordinate, an accuracy and the dates of arrival, departure and detection; its
  getters answer them, and the SDK says the arrival date is `[NSDate distantPast]` when the true one is not known and the
  departure date is `[NSDate distantFuture]` while the device has not left.

## What the port does

Outdoors, and with no floor information, is what the newest release answers with nil, and it is the only place iOS 6 has to
offer: `-[CLLocation floor]` is nil for every location, and `CLFloor` is a value class with a level, copying and secure coding
that nothing in the release ever makes.

iOS 6 has no detection of visits. `-startMonitoringVisits` and `-stopMonitoringVisits` are inert: the first says so once in
the log and returns, the second returns; the delegate is never sent `-locationManager:didVisit:`. `CLVisit` is a value class
whose instances start with the arrival date `[NSDate distantPast]`, the departure date `[NSDate distantFuture]`, the
coordinate (-180, -180) and the accuracy -1, which are the port's choice for an empty visit, since nothing here ever makes
one with values; it copies and codes with secure coding.

## What was measured

The emulated iOS 6.0, an iPad 2 and an iPhone 4S on iOS 6.1.3, the same answers on all three: `CLFloor` and `CLVisit` come
from `libCoreLocationBackports.dylib`; a location made from a latitude and a longitude has no floor; a visit made with `-init`
has `[NSDate distantPast]` and `[NSDate distantFuture]` for its dates and an accuracy of -1, copies, and survives archiving
and unarchiving as a `CLVisit` with the same departure date; `-startMonitoringVisits` and `-stopMonitoringVisits` raise
nothing, the first writes its line to the log once, and the delegate is sent nothing in the second that follows.

## A visit on the host, measured

The host's `CLVisit` has five ivars (`_arrivalDate`, `_departureDate`, `_horizontalAccuracy`, `_detectionDate`,
`__placeInference`, `_coordinate`); `-init` makes one whose dates are nil and whose accuracy is 0, which is not the
port's empty visit (distant past, distant future, -1). A visit with values was made on the host by setting the arrival
and departure dates and the accuracy on that object through key-value coding: its getters answer them, `-copy` keeps
the class and the arrival date, and a secure-coding archive round trip keeps the arrival date. The coordinate of such a
visit is (0, 0), because nothing set it.

`-startMonitoringVisits` with a delegate, and three seconds of run loop, delivered no visit to the delegate on the host
in the sandbox; that is not evidence that the host never sends one, since the host's detection is the daemon's and the
window is short. What makes a visit is not readable on either side, so `-locationManager:didVisit:` stays owed: the port
has no detection, and a visit it could send would be made up.
