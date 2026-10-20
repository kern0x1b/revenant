# NSURLCache directoryURL initializer, iOS 13

initWithMemoryCapacity:diskCapacity:directoryURL:.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

iOS 6 knows only diskPath:. A directory under the caches directory is passed as the path relative to it; any other directory is passed as given. The host resolves diskPath: differently (a name under a per-process caches folder), so the host run checks the round trip, the capacities and the presence of Cache.db at the host's place; where the store lands for an absolute path on iOS 6 is left for the device test.
