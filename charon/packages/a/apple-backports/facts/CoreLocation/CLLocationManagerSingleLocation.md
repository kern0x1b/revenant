# CLLocationManager requestLocation, iOS 9, and requestStateForRegion:, iOS 7

Source: CoreLocation of iOS 12.0 arm64 (CoreLocation-2245.4.104), read instruction by instruction:
`-[CLLocationManager requestLocation]` at `0x187d5acd8`, `-requestStateForRegion:` at `0x187d5d7e0`; and iOS 6.0 on the
emulator and iOS 6.1.3 on an iPad 2, through `tests/backports/device/corelocation.m`.

## What is read of the newest release

`-requestLocation`:

- asserts that the delegate answers `locationManager:didUpdateLocations:` and, separately, `locationManager:didFailWithError:`;
  a delegate that does not gets `-[NSAssertionHandler handleFailureInMethod:object:file:lineNumber:description:]` with the
  texts `Delegate must respond to locationManager:didUpdateLocations:` and `Delegate must respond to
  locationManager:didFailWithError:`, which raises `NSInternalInconsistencyException`;
- returns at once, writing "Ignoring requestLocation due to ongoing location." to the log, when the manager is already
  requesting a location, updating it or batching it;
- otherwise marks the manager as requesting and starts location updates through the client with the manager's own
  `desiredAccuracy` and no distance filter.

`-requestStateForRegion:` asserts the region is not nil (`Invalid parameter not satisfying: %@`), performs the courtesy
prompt if one is due, and hands the region to the client; the answer comes back from the location daemon, which holds the
state it cached for the region.

What the library does not hold is when the answer to either request comes, which accuracy ends a location request, and how
long the daemon waits before it gives up: those are the daemon's, not readable in CoreLocation. The header of the SDK says
what a caller may rely on - one location, delivered when its accuracy is that of `desiredAccuracy`, or after a timeout with
the best one there is, or `kCLErrorLocationUnknown` when there is none - and that is all the port holds itself to.

## What the port does

`-requestLocation` checks the delegate the same way and raises the same exception with the same texts. A second request made
while one is outstanding is dropped. The port then makes a manager of its own with a delegate of its own, at the same
`desiredAccuracy` and no distance filter, starts it, and waits for a location whose horizontal accuracy is within
`desiredAccuracy` when that is a number of metres; the best location it has is delivered when ten seconds have passed (the
ten seconds are the port's choice, not read from anything). An error other than `kCLErrorLocationUnknown` from that manager
- the release's answer when location services are denied - ends the request at once and is delivered as it came;
`kCLErrorLocationUnknown` is waited out, and is what is delivered when the time is up and there was never a location. The
location, or the error, reaches the delegate of the manager the application made, as `-locationManager:didUpdateLocations:`
with an array of one, or `-locationManager:didFailWithError:`, on the thread that made the request.

`-requestStateForRegion:` is answered from a location, not from a cache: the port asks for one as above and delivers
`-locationManager:didDetermineState:forRegion:` with inside or outside according to `-containsCoordinate:` of the region, and
with unknown when no location came. A beacon region is answered unknown at once, since nothing here can range or monitor one.
The state the newest release reports for a region that is not monitored is not read, so an application that asks about a
region it never monitored may get a definite answer here where the newest release has none.

What the port cannot do: a request cannot be cancelled by `-stopUpdatingLocation` or replaced by `-startUpdatingLocation` on
the manager, because those are the release's and nothing of the port's is in front of them; a request made and then stopped
still delivers what it found.

## What was measured

The emulated iOS 6.0 has location services off and no location daemon, and the iPad 2 on iOS 6.1.3 has them on with the
status not determined; a process that is no application has no prompt to show, and on neither did a location arrive. The
same answers on both:

- a delegate that does not answer `locationManager:didUpdateLocations:` gets `NSInternalInconsistencyException` from
  `-requestLocation`, and so does a nil region from `-requestStateForRegion:`;
- two `-requestLocation` calls made together end in exactly one `-locationManager:didFailWithError:` in
  `kCLErrorDomain`, with the code 0, `kCLErrorLocationUnknown`, after the ten seconds, and never in a second one;
- `-requestStateForRegion:` for a region of iOS 6 ends in exactly one `-locationManager:didDetermineState:forRegion:` with
  `CLRegionStateUnknown`, after the same wait.

That a location, once one arrives, is delivered as an array of one, and that the state is inside or outside according to
the region, was not observed on a device: neither had a location to give. The 28 checks of `corelocation.m` hold the
answers above and the shape of the rest.
