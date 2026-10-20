# NSHTTPURLResponse valueForHTTPHeaderField:, iOS 13

Case-insensitive header lookup.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The lookup goes through allHeaderFields with a case-insensitive comparison and answers the first value found, as the host does.
